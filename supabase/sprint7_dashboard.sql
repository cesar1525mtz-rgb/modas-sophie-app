create or replace function public.owner_dashboard_today()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with sale_data as (
    select
      coalesce(sum(total), 0) sales_total,
      coalesce(sum(gross_profit), 0) gross_profit,
      count(*) sales_count
    from public.sales
    where business_id = public.current_business_id()
      and status = 'COMPLETADA'
      and created_at >= date_trunc('day', now())
  ),
  expense_data as (
    select coalesce(sum(amount), 0) expenses
    from public.expenses
    where business_id = public.current_business_id()
      and expense_date = current_date
  ),
  cash_data as (
    select exists (
      select 1 from public.cash_sessions
      where business_id = public.current_business_id()
        and status = 'ABIERTA'
    ) cash_open
  )
  select jsonb_build_object(
    'sales_total', s.sales_total,
    'gross_profit', s.gross_profit,
    'expenses', e.expenses,
    'net_profit', s.gross_profit - e.expenses,
    'sales_count', s.sales_count,
    'cash_open', c.cash_open
  )
  from sale_data s cross join expense_data e cross join cash_data c
$$;

grant execute on function public.owner_dashboard_today() to authenticated;
