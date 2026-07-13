-- Modas Sophie v1 - Sprint 4
-- Activar/desactivar vendedores sin borrar historial.

create or replace function public.set_seller_active(
  p_user_id uuid,
  p_active boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target public.user_profiles;
begin
  if public.current_role() <> 'OWNER' then
    raise exception 'No autorizado';
  end if;

  select * into target
  from public.user_profiles
  where id = p_user_id
    and business_id = public.current_business_id();

  if target.id is null then
    raise exception 'Usuario no encontrado';
  end if;

  if target.role <> 'SELLER' then
    raise exception 'La cuenta del dueño no puede desactivarse aquí';
  end if;

  update public.user_profiles
  set active = p_active
  where id = p_user_id;

  insert into public.audit_logs (
    user_id, action, module, record_id, new_data
  ) values (
    auth.uid(),
    case when p_active then 'ACTIVAR_VENDEDOR' else 'DESACTIVAR_VENDEDOR' end,
    'USUARIOS',
    p_user_id,
    jsonb_build_object('active', p_active)
  );
end;
$$;

grant execute on function public.set_seller_active(uuid, boolean)
to authenticated;
