# Garage99 — Estándares de datos

Última actualización: 2026-09-06
Estado: estándar adoptado para el modelo operacional y sus migraciones

## 1. Principios

1. Supabase/PostgreSQL es la fuente de verdad del catálogo, pedidos e inventario.
2. El historial operacional es append-only; una corrección se registra como un
   nuevo evento compensatorio.
3. Las reglas que protegen dinero, stock y pertenencia de datos viven en la base
   o en funciones transaccionales llamadas por el servidor.
4. La aplicación nunca confía en precios, totales, roles o disponibilidad
   enviados por el navegador.
5. Los datos públicos se seleccionan mediante una superficie `api`; las tablas
   internas están en `app` y no se exponen directamente.
6. Todo cambio estructural se versiona en una migración reproducible.

## 2. Nomenclatura

| Elemento | Norma | Ejemplo |
|---|---|---|
| Esquemas | `app` interno y `api` expuesto | `app.product_variants` |
| Tablas | Inglés, plural, `snake_case` | `purchase_orders` |
| Columnas | Inglés, `snake_case` | `supplier_product_id` |
| PK | `id uuid` generado en DB | `id` |
| FK | Nombre singular de la entidad más `_id` | `variant_id` |
| Código comercial | `sku` estable y único | `FRENO-DEL-001` |
| Fechas | `created_at`, `updated_at`, `occurred_at` en `timestamptz` | `occurred_at` |
| Fecha sin hora | Sufijo `_date` | `ordered_date` |
| Dinero | Sufijo `_amount`, `numeric`, moneda explícita | `unit_price_amount`, `currency_code` |
| Cantidades | Enteros y nombre `_quantity` cuando aplique | `quantity_received` |
| JSON | Sufijo o nombre descriptivo | `attributes`, `payload`, `shipping_snapshot` |
| Vistas | Prefijo `v_` | `api.v_catalog` |
| Funciones | Verbo + entidad | `api.reserve_order` |
| Índices | `<tabla>_<columnas>_idx` | `orders_customer_id_idx` |
| Restricciones | Sufijos `_pkey`, `_fkey`, `_key`, `_check` | `inventory_reserved_check` |
| Migraciones | Timestamp + descripción | `20260906000100_create_catalog.sql` |

No usar prefijos `tbl_`, abreviaturas ambiguas ni nombres que mezclen español e
inglés. No incluir precio, año o compatibilidad dentro del SKU. Los nombres de
estado se guardan en minúscula y se validan con `CHECK` o tablas maestras.

## 3. Tipos y restricciones

- UUID para claves internas; códigos externos se mantienen como `text` y nunca
  sustituyen la PK local.
- `text` para nombres y códigos; limitar longitud en la aplicación y validar
  formatos comerciales donde sea útil.
- `numeric(12,2)` o una precisión equivalente para importes; CLP se almacena
  sin fracciones. Nunca usar `float` para dinero.
- `integer` para unidades. Rechazar negativos, salvo deltas de movimientos.
- `timestamptz` en UTC. La interfaz convierte a la zona horaria de Chile.
- `jsonb` solo para atributos variables, snapshots, payloads y respuestas
  externas; relaciones consultadas y reglas críticas requieren columnas/FK.
- FKs `NOT NULL` cuando la relación sea obligatoria. Usar `ON DELETE RESTRICT`
  para históricos y desactivar maestros; reservar `CASCADE` para tablas puente
  sin valor histórico.
- Añadir índices a FKs usadas en joins y búsquedas. PostgreSQL no crea
  automáticamente todos los índices de columnas referenciantes.

## 4. Estados y transiciones

Los estados representan un proceso, no una etiqueta libre. Cada transición debe
validar el estado anterior, actor, motivo y efectos asociados.

- Producto: `draft → published → archived`.
- Pedido: `pending → reserved → paid → fulfilled`; cancelación y excepción son
  salidas explícitas.
- Reserva: `active → consumed | released | expired`.
- Recepción: `draft → posted`; una recepción publicada no se edita, se corrige
  con documento compensatorio.
- Integración: `pending → running → succeeded | failed`, con reintentos y
  `next_attempt_at`.

No borrar pedidos, pagos, movimientos, recepciones ni auditoría. Para dejar de
usar un producto, proveedor, canal o compatibilidad se utiliza `active=false` o
un estado de archivo.

## 5. Inventario transaccional

El saldo de `app.inventory` es una proyección rápida; `app.inventory_movements`
es el registro auditable. Toda operación de stock debe:

1. Validar sesión, rol, cantidad, estado y clave idempotente.
2. Bloquear las variantes en orden ascendente de UUID o SKU.
3. Comprobar que no se viola `reserved <= on_hand` ni el stock disponible para
   el canal.
4. Actualizar saldo, documento, movimiento y operación en la misma transacción.
5. Devolver el resultado de la operación para reintentos seguros.

Una reserva web dura 15 minutos. Un job de expiración puede liberar reservas
vencidas, pero debe competir atómicamente con pago y cancelación. El despacho no
descuenta inventario de nuevo.

La sincronización con Mercado Libre es eventualmente consistente. El margen de
seguridad configurado limita la cantidad publicada, pero no elimina el riesgo
de una última unidad vendida simultáneamente. Las diferencias se reconcilian y
se atienden como excepción; no se inventa stock para cerrar una discrepancia.

## 6. Idempotencia y referencias externas

Las solicitudes que producen efectos reciben `idempotency_key`. La clave,
actor/servicio y parámetros relevantes deben ser únicos y persistirse junto con
el resultado. Repetir la misma solicitud devuelve el resultado original;
reutilizar la clave con parámetros distintos se rechaza.

Para Mercado Libre, las unicidades se definen por proveedor, cuenta e
identificador externo. Guardar el evento antes de procesarlo permite reintentar
sin perder notificaciones. Los jobs de salida deben tener una clave de
deduplicación y una versión del saldo deseado para descartar trabajos obsoletos.

## 7. Seguridad y RLS

Configurar la Data API para exponer `api` y no `app`. En cada tabla expuesta:

- habilitar RLS;
- revocar privilegios por defecto de `anon` y `authenticated`;
- conceder solo `SELECT` o ejecución de la función necesaria;
- crear políticas separadas para `SELECT`, `INSERT`, `UPDATE` y `DELETE`;
- probar permisos con visitante, cliente A, cliente B, staff y servicio.

El cliente solo puede consultar sus propios pedidos, reservas, pagos resumidos,
devoluciones y garantías. El catálogo publicado es lectura pública. Inventario
completo, costos, proveedores, tokens, eventos y auditoría son internos.

Las funciones `SECURITY DEFINER` deben fijar `search_path`, validar el actor y
tener `EXECUTE` mínimo. Las vistas públicas deben usar políticas de sus tablas o
`security_invoker` cuando el motor y la versión lo permitan. No usar la clave
`service_role` en navegador.

## 8. Auditoría y calidad

Registrar actor, servicio, motivo, referencia, request ID y hora en operaciones
de stock, precios, permisos, pedidos externos y posventa. No registrar secretos,
tokens completos ni datos de tarjeta.

Controles periódicos:

- `sum(inventory_movements.on_hand_delta) = inventory.on_hand` desde el punto
  inicial documentado;
- suma de reservas activas por SKU = `inventory.reserved`;
- pedidos pagados tienen líneas y una transición de inventario correspondiente;
- recepciones publicadas no superan unidades ordenadas;
- reembolsos no superan pagos confirmados;
- listings y jobs fallidos tienen responsable y próxima acción.

## 9. Migraciones y operación

1. Crear una migración nueva; nunca editar una aplicada.
2. Incluir tablas, restricciones, índices, grants, RLS, funciones y comentarios
   relacionados en cambios revisables.
3. Probar en entorno descartable con datos ficticios y luego en desarrollo.
4. Registrar checksum, fecha, entorno, resultado y reversión operativa posible.
5. Separar migraciones estructurales de seeds y de datos reales.
6. Hacer copia y verificar restauración antes de cambios de alto riesgo.
7. Aplicar cambios mediante CLI o procedimiento documentado, no solo desde una
   sesión manual del SQL Editor.

La migración inicial de negocio deberá dividirse en incrementos pequeños:

1. `app`/`api`, catálogo y compatibilidad.
2. Inventario, movimientos, operaciones y reservas.
3. Clientes, canales, precios, pedidos y líneas.
4. Compras, recepciones, mostrador y posventa.
5. Pagos, entregas y Mercado Libre.

## 10. Ejemplos de consultas de operación

Disponibilidad publicable, concepto:

```sql
greatest(0, inventory.on_hand - inventory.reserved - inventory.safety_stock)
```

Movimiento compensatorio para corregir un faltante: nunca editar el movimiento
original; crear una operación con motivo, referencia y deltas que expliquen la
diferencia.

Consulta de conciliación conceptual:

```sql
select variant_id,
       sum(on_hand_delta) as movement_on_hand,
       sum(reserved_delta) as movement_reserved
from app.inventory_movements
group by variant_id;
```

La consulta final debe considerar el saldo inicial documentado y ejecutarse con
un rol de auditoría. No se debe exponer directamente mediante el catálogo.

## 11. Criterio de listo para producción

El modelo se considera listo para el siguiente hito cuando las migraciones
reconstruyen el esquema en una base descartable, las pruebas de concurrencia y
RLS pasan, se verifican reservas/pagos/devoluciones idempotentes y existe un
procedimiento para detener sincronización, desactivar checkout y recuperar una
versión anterior sin revertir movimientos históricos.
