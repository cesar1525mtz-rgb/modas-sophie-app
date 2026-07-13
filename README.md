# Modas Sophie v1 — Starter

Base inicial para la app Android de control de tienda.

## Incluye
- Estructura Flutter
- Tema visual rosa/crema/negro
- Roles OWNER y SELLER
- Pantalla inicial de acceso
- Dashboard base
- Esquema SQL inicial para Supabase

## Próximo sprint
- Autenticación real con Supabase
- Gestión de vendedores activos/inactivos
- Categorías
- Productos
- Variantes
- SKU automático
- Movimientos de inventario

## Configuración
1. Crear un proyecto en Supabase.
2. Ejecutar `supabase/schema.sql` en SQL Editor.
3. Crear el proyecto Flutter y copiar `lib/` y `pubspec.yaml`.
4. Añadir las credenciales de Supabase de forma segura.


## Sprint 2 completado
- Navegación funcional hacia Inventario
- Buscador por nombre o SKU
- Alta de producto
- Categorías iniciales de Modas Sophie
- Generador de SKU base y variante
- Primera variante por talla/color
- Stock inicial y alerta visual de stock bajo

Nota: en este prototipo los datos de inventario viven en memoria.
La siguiente integración conectará estas pantallas a Supabase y añadirá RLS.


## Sprint 3 — Supabase
- Inicialización segura con SUPABASE_URL y SUPABASE_ANON_KEY.
- Repositorio de inventario.
- RLS base por negocio.
- Permisos OWNER para altas.
- Alta transaccional de producto, variante e inventario inicial.
- SKU generado en PostgreSQL.
- Bitácora automática.

Ejecutar schema.sql y después sprint3_security_and_functions.sql.

Arranque:
flutter run --dart-define=SUPABASE_URL=TU_URL --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY

Nunca incluir la clave service_role dentro de la app Android.


## Sprint 4 — Login y usuarios
- Login real con Supabase Auth.
- Perfil OWNER / SELLER.
- Bloqueo de usuarios inactivos.
- Pantalla de usuarios para el dueño.
- Activar/desactivar vendedores.
- El dueño no puede desactivarse desde esa pantalla.
- Bitácora al activar o desactivar vendedores.

Nota: el alta segura de nuevos vendedores se implementará mediante una función backend/Edge Function,
para no incluir credenciales administrativas dentro de Android.


## Sprint 5 — Punto de Venta
- Búsqueda de producto o SKU.
- Selección de variante con talla/color.
- Validación visual de stock.
- Carrito.
- Cobro en efectivo o transferencia.
- Cálculo de cambio.
- Folio automático.
- Venta transaccional en PostgreSQL.
- Bloqueo de stock para evitar doble venta simultánea.
- Costo histórico y ganancia bruta.
- Descuento automático de inventario.
- Movimiento de inventario y bitácora.

Ejecutar sprint5_pos.sql después de los scripts anteriores.


## Sprint 6 — Caja y Finanzas
- Apertura de caja y fondo inicial.
- Una sola caja abierta por negocio.
- Registro de gastos.
- Gastos pagados desde caja.
- Retiros separados de gastos.
- Cierre con efectivo esperado, contado y diferencia.
- Resumen semanal.
- Ventas, costo vendido, ganancia bruta, gastos y utilidad neta.

Pendiente técnico detectado:
La función complete_sale del Sprint 5 debe asociar cada venta a cash_session_id.
Se consolidará antes del APK de prueba para garantizar cortes exactos.


## Sprint 7 — Consolidación para prueba Android
- Corregida la integración POS/caja.
- Una venta exige caja abierta.
- La venta queda asociada al corte correcto.
- El efectivo de ventas entra al cálculo del cierre.
- Dashboard real de hoy.
- Ventas, gastos, utilidad neta y número de ventas.
- Indicador de caja abierta/cerrada.
- Actualización por gesto de deslizar.
- Orden de scripts SQL documentado.

Estado: base consolidada para configurar un proyecto real de Supabase y compilar la primera prueba Android.

## Estado de conexión real
Este paquete ya contiene la Project URL y la Publishable Key del proyecto Supabase de Modas Sophie.
No contiene secret key ni service_role.
