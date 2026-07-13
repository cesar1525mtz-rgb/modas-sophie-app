-- MODAS SOPHIE v1 - Sprint 6 Finanzas y Caja

create type public.cash_session_status as enum ('ABIERTA','CERRADA','REVISADA');
create type public.cash_movement_type as enum ('ENTRADA','SALIDA','RETIRO','AJUSTE');

create table if not exists public.cash_sessions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  opened_by uuid not null references public.user_profiles(id),
  closed_by uuid references public.user_profiles(id),
  initial_fund numeric(12,2) not null default 0 check (initial_fund >= 0),
  expected_cash numeric(12,2),
  counted_cash numeric(12,2),
  difference numeric(12,2),
  status public.cash_session_status not null default 'ABIERTA',
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  notes text
);

create unique index if not exists one_open_cash_per_business
on public.cash_sessions (business_id)
where status = 'ABIERTA';

create table if not exists public.cash_movements (
  id uuid primary key default gen_random_uuid(),
  cash_session_id uuid not null references public.cash_sessions(id),
  movement_type public.cash_movement_type not null,
  amount numeric(12,2) not null check (amount > 0),
  reason text not null,
  user_id uuid not null references public.user_profiles(id),
  created_at timestamptz not null default now()
);

alter table public.sales
add column if not exists cash_session_id uuid references public.cash_sessions(id);

alter table public.cash_sessions enable row level security;
alter table public.cash_movements enable row level security;

create policy "cash_sessions_business_read"
on public.cash_sessions for select
using (business_id = public.current_business_id());

create policy "cash_movements_business_read"
on public.cash_movements for select
using (exists (
  select 1 from public.cash_sessions c
  where c.id = cash_session_id
  and c.business_id = public.current_business_id()
));

create or replace function public.get_open_cash_session()
returns jsonb
language sql stable security definer set search_path = public
as $$
  select to_jsonb(c)
  from public.cash_sessions c
  where c.business_id = public.current_business_id()
    and c.status = 'ABIERTA'
  limit 1
$$;

create or replace function public.open_cash_session(p_initial_fund numeric)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare v_id uuid;
begin
  if public.current_business_id() is null then raise exception 'No autorizado'; end if;
  if p_initial_fund < 0 then raise exception 'Fondo invalido'; end if;

  insert into public.cash_sessions (business_id, opened_by, initial_fund)
  values (public.current_business_id(), auth.uid(), p_initial_fund)
  returning id into v_id;

  insert into public.audit_logs (user_id, action, module, record_id, new_data)
  values (auth.uid(), 'ABRIR_CAJA', 'CAJA', v_id,
    jsonb_build_object('fondo_inicial', p_initial_fund));

  return v_id;
end;
$$;

create or replace function public.register_expense(
  p_concept text,
  p_amount numeric,
  p_payment_method text,
  p_paid_from_cash boolean,
  p_notes text default null
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare v_expense uuid; v_cash uuid;
begin
  if p_amount <= 0 then raise exception 'Importe invalido'; end if;

  insert into public.expenses (
    business_id, concept, amount, payment_method,
    paid_from_cash, registered_by, notes
  ) values (
    public.current_business_id(), trim(p_concept), p_amount,
    upper(p_payment_method), p_paid_from_cash, auth.uid(), p_notes
  ) returning id into v_expense;

  if p_paid_from_cash then
    select id into v_cash from public.cash_sessions
    where business_id = public.current_business_id() and status = 'ABIERTA';

    if v_cash is null then raise exception 'No hay caja abierta'; end if;

    insert into public.cash_movements
      (cash_session_id, movement_type, amount, reason, user_id)
    values (v_cash, 'SALIDA', p_amount, 'GASTO: ' || trim(p_concept), auth.uid());
  end if;

  return v_expense;
end;
$$;

create or replace function public.register_cash_withdrawal(
  p_amount numeric, p_reason text
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare v_cash uuid; v_move uuid;
begin
  if p_amount <= 0 then raise exception 'Importe invalido'; end if;

  select id into v_cash from public.cash_sessions
  where business_id = public.current_business_id() and status = 'ABIERTA';

  if v_cash is null then raise exception 'No hay caja abierta'; end if;

  insert into public.cash_movements
    (cash_session_id, movement_type, amount, reason, user_id)
  values (v_cash, 'RETIRO', p_amount, trim(p_reason), auth.uid())
  returning id into v_move;

  return v_move;
end;
$$;

create or replace function public.close_cash_session(
  p_counted_cash numeric, p_notes text default null
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  c public.cash_sessions;
  v_cash_sales numeric := 0;
  v_out numeric := 0;
  v_expected numeric;
begin
  select * into c from public.cash_sessions
  where business_id = public.current_business_id() and status = 'ABIERTA'
  for update;

  if c.id is null then raise exception 'No hay caja abierta'; end if;

  select coalesce(sum(sp.amount),0) into v_cash_sales
  from public.sale_payments sp
  join public.sales s on s.id = sp.sale_id
  where s.cash_session_id = c.id
    and s.status = 'COMPLETADA'
    and sp.method = 'EFECTIVO';

  select coalesce(sum(amount),0) into v_out
  from public.cash_movements
  where cash_session_id = c.id
    and movement_type in ('SALIDA','RETIRO');

  v_expected := c.initial_fund + v_cash_sales - v_out;

  update public.cash_sessions set
    expected_cash = v_expected,
    counted_cash = p_counted_cash,
    difference = p_counted_cash - v_expected,
    status = 'CERRADA',
    closed_by = auth.uid(),
    closed_at = now(),
    notes = p_notes
  where id = c.id;

  return jsonb_build_object(
    'expected_cash', v_expected,
    'counted_cash', p_counted_cash,
    'difference', p_counted_cash - v_expected
  );
end;
$$;

create or replace function public.weekly_financial_summary()
returns jsonb
language sql stable security definer set search_path = public
as $$
  with sale_data as (
    select
      coalesce(sum(total),0) sales_total,
      coalesce(sum(sold_cost),0) sold_cost,
      coalesce(sum(gross_profit),0) gross_profit
    from public.sales
    where business_id = public.current_business_id()
      and status = 'COMPLETADA'
      and created_at >= date_trunc('week', now())
  ),
  expense_data as (
    select coalesce(sum(amount),0) expenses
    from public.expenses
    where business_id = public.current_business_id()
      and expense_date >= date_trunc('week', now())::date
  )
  select jsonb_build_object(
    'sales_total', s.sales_total,
    'sold_cost', s.sold_cost,
    'gross_profit', s.gross_profit,
    'expenses', e.expenses,
    'net_profit', s.gross_profit - e.expenses
  )
  from sale_data s cross join expense_data e
$$;

grant execute on function public.get_open_cash_session() to authenticated;
grant execute on function public.open_cash_session(numeric) to authenticated;
grant execute on function public.register_expense(text,numeric,text,boolean,text) to authenticated;
grant execute on function public.register_cash_withdrawal(numeric,text) to authenticated;
grant execute on function public.close_cash_session(numeric,text) to authenticated;
grant execute on function public.weekly_financial_summary() to authenticated;

-- IMPORTANTE:
-- En complete_sale del Sprint 5, asociar la venta a la caja abierta.
-- La siguiente versión consolidada integra esta regla directamente.
