-- Modas Sophie: permitir a cada usuario autenticado leer su propio perfil.
drop policy if exists "user_read_own_profile" on public.user_profiles;

create policy "user_read_own_profile"
on public.user_profiles
for select
to authenticated
using (id = auth.uid());

grant select on public.user_profiles to authenticated;
