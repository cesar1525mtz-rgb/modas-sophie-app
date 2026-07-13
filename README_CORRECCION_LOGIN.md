# Modas Sophie - corrección de acceso

Cambios:
- El login ya no oculta el error real de Supabase.
- Distingue credenciales incorrectas, correo sin confirmar, falta de perfil OWNER y errores de red.
- Comprueba que Supabase devolvió una sesión válida antes de leer el perfil.
- Conserva y restaura una sesión válida al abrir la app.
- Incluye `09_fix_owner_profile_rls.sql` para permitir al usuario autenticado leer su propio perfil.

No contiene `service_role` ni `sb_secret_`.
