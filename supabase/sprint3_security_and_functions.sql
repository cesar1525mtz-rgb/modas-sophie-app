alter table public.user_profiles enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.audit_logs enable row level security;

create or replace function public.current_business_id()
returns uuid language sql stable security definer set search_path = public
as $$
  select business_id from public.user_profiles
  where id = auth.uid() and active = true
$$;

create or replace function public.current_role()
returns public.user_role language sql stable security definer set search_path = public
as $$
  select role from public.user_profiles
  where id = auth.uid() and active = true
$$;

create policy "products_read_same_business"
on public.products for select
using (business_id = public.current_business_id());

create policy "categories_read_same_business"
on public.categories for select
using (business_id = public.current_business_id());

create policy "variants_read_same_business"
on public.product_variants for select
using (exists (
  select 1 from public.products p
  where p.id = product_id
  and p.business_id = public.current_business_id()
));

create policy "owner_products"
on public.products for all
using (business_id = public.current_business_id() and public.current_role() = 'OWNER')
with check (business_id = public.current_business_id() and public.current_role() = 'OWNER');

create sequence if not exists public.modas_sophie_sku_seq start 1;

create or replace function public.create_product_with_variant(
  p_category_name text,
  p_name text,
  p_cost numeric,
  p_sale_price numeric,
  p_minimum_stock integer,
  p_size text,
  p_color text,
  p_initial_stock integer
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business uuid := public.current_business_id();
  v_category public.categories;
  v_product uuid;
  v_variant uuid;
  v_base text;
  v_sku text;
begin
  if v_business is null or public.current_role() <> 'OWNER' then
    raise exception 'No autorizado';
  end if;

  if p_cost < 0 or p_sale_price < 0 or p_initial_stock < 0 then
    raise exception 'Valores invalidos';
  end if;

  select * into v_category from public.categories
  where business_id = v_business and name = p_category_name and active = true;

  if v_category.id is null then raise exception 'Categoria no encontrada'; end if;

  v_base := upper(v_category.sku_prefix) || '-' ||
    lpad(nextval('public.modas_sophie_sku_seq')::text, 4, '0');
  v_sku := v_base;

  if nullif(trim(p_size), '') is not null then
    v_sku := v_sku || '-' || upper(regexp_replace(trim(p_size), '\s+', '', 'g'));
  end if;
  if nullif(trim(p_color), '') is not null then
    v_sku := v_sku || '-' || left(upper(regexp_replace(trim(p_color), '\s+', '', 'g')), 3);
  end if;

  insert into public.products
    (business_id, category_id, sku_base, name, current_cost, sale_price, minimum_stock)
  values
    (v_business, v_category.id, v_base, trim(p_name), p_cost, p_sale_price, p_minimum_stock)
  returning id into v_product;

  insert into public.product_variants
    (product_id, sku, size, color, current_stock)
  values
    (v_product, v_sku, nullif(trim(p_size), ''), nullif(trim(p_color), ''), p_initial_stock)
  returning id into v_variant;

  if p_initial_stock > 0 then
    insert into public.inventory_movements
      (variant_id, movement_type, quantity, previous_stock, new_stock, unit_cost, reason, user_id)
    values
      (v_variant, 'ENTRADA', p_initial_stock, 0, p_initial_stock, p_cost, 'Inventario inicial', auth.uid());
  end if;

  insert into public.audit_logs (user_id, action, module, record_id, new_data)
  values (auth.uid(), 'CREAR_PRODUCTO', 'INVENTARIO', v_product,
    jsonb_build_object('sku', v_base, 'nombre', trim(p_name)));

  return v_product;
end;
$$;

grant execute on function public.create_product_with_variant(
  text,text,numeric,numeric,integer,text,text,integer
) to authenticated;
