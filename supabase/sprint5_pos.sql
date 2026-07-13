-- MODAS SOPHIE v1 - Sprint 5 POS

create sequence if not exists public.modas_sophie_sale_seq start 1;

create or replace function public.search_pos_products(p_query text default '')
returns table (
  variant_id uuid,
  name text,
  sku text,
  size text,
  color text,
  stock integer,
  sale_price numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select v.id, p.name, v.sku, v.size, v.color, v.current_stock, p.sale_price
  from public.product_variants v
  join public.products p on p.id = v.product_id
  where p.business_id = public.current_business_id()
    and p.active = true and v.active = true
    and (
      coalesce(trim(p_query), '') = ''
      or p.name ilike '%' || p_query || '%'
      or v.sku ilike '%' || p_query || '%'
    )
  order by p.name, v.sku
  limit 100
$$;

grant execute on function public.search_pos_products(text) to authenticated;

create or replace function public.complete_sale(
  p_items jsonb,
  p_payment_method text,
  p_payment_amount numeric,
  p_reference text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business uuid := public.current_business_id();
  v_seller uuid := auth.uid();
  v_sale uuid;
  v_folio text;
  v_subtotal numeric := 0;
  v_cost numeric := 0;
  item jsonb;
  variant_row record;
  qty integer;
  line_total numeric;
begin
  if v_business is null then raise exception 'Usuario no autorizado'; end if;
  if jsonb_array_length(p_items) = 0 then raise exception 'Carrito vacio'; end if;

  -- Primera pasada: bloquear stock y calcular totales.
  for item in select * from jsonb_array_elements(p_items)
  loop
    qty := (item->>'quantity')::integer;
    if qty <= 0 then raise exception 'Cantidad invalida'; end if;

    select v.id, v.sku, v.size, v.color, v.current_stock,
           p.name, p.current_cost, p.sale_price
    into variant_row
    from public.product_variants v
    join public.products p on p.id = v.product_id
    where v.id = (item->>'variant_id')::uuid
      and p.business_id = v_business
      and p.active = true and v.active = true
    for update of v;

    if variant_row.id is null then raise exception 'Producto no encontrado'; end if;
    if variant_row.current_stock < qty then
      raise exception 'Stock insuficiente para %', variant_row.sku;
    end if;

    v_subtotal := v_subtotal + (variant_row.sale_price * qty);
    v_cost := v_cost + (variant_row.current_cost * qty);
  end loop;

  if p_payment_amount <> v_subtotal then
    raise exception 'El pago debe coincidir con el total';
  end if;

  v_folio := 'MS-' || extract(year from now())::int || '-' ||
             lpad(nextval('public.modas_sophie_sale_seq')::text, 6, '0');

  insert into public.sales (
    business_id, folio, seller_id, subtotal, discount,
    total, sold_cost, gross_profit, status
  ) values (
    v_business, v_folio, v_seller, v_subtotal, 0,
    v_subtotal, v_cost, v_subtotal - v_cost, 'COMPLETADA'
  ) returning id into v_sale;

  for item in select * from jsonb_array_elements(p_items)
  loop
    qty := (item->>'quantity')::integer;

    select v.id, v.sku, v.size, v.color, v.current_stock,
           p.name, p.current_cost, p.sale_price
    into variant_row
    from public.product_variants v
    join public.products p on p.id = v.product_id
    where v.id = (item->>'variant_id')::uuid
    for update of v;

    line_total := variant_row.sale_price * qty;

    insert into public.sale_items (
      sale_id, variant_id, historical_name, historical_sku,
      historical_size, historical_color, quantity,
      historical_unit_cost, unit_price, discount, total
    ) values (
      v_sale, variant_row.id, variant_row.name, variant_row.sku,
      variant_row.size, variant_row.color, qty,
      variant_row.current_cost, variant_row.sale_price, 0, line_total
    );

    update public.product_variants
    set current_stock = current_stock - qty
    where id = variant_row.id;

    insert into public.inventory_movements (
      variant_id, movement_type, quantity, previous_stock,
      new_stock, unit_cost, reason, user_id
    ) values (
      variant_row.id, 'VENTA', qty, variant_row.current_stock,
      variant_row.current_stock - qty, variant_row.current_cost,
      v_folio, v_seller
    );
  end loop;

  insert into public.sale_payments (sale_id, method, amount, reference)
  values (v_sale, upper(p_payment_method), p_payment_amount, nullif(trim(p_reference), ''));

  insert into public.audit_logs (user_id, action, module, record_id, new_data)
  values (
    v_seller, 'COMPLETAR_VENTA', 'VENTAS', v_sale,
    jsonb_build_object('folio', v_folio, 'total', v_subtotal)
  );

  return v_folio;
end;
$$;

grant execute on function public.complete_sale(jsonb,text,numeric,text)
to authenticated;
