# Evidencia de modelo operacional ? 2026-09-06

## Alcance

Se aplicaron y validaron en Supabase las migraciones del modelo operacional de Garage99 para el proyecto `bxhavpyvoijawzqiaspk`:

- `20260906000100_create_garage99_schema.sql`
- `20260906000200_seed_garage99_demo.sql`

La ejecuci?n se realiz? con `scripts/apply_garage99_migrations.py`, mediante Session Pooler TLS. La contrase?a se ley? por entrada oculta y no se guard? en archivos, reportes ni c?digo.

## Resultados

| Verificaci?n | Resultado |
|---|---|
| Aplicaci?n inicial de las dos migraciones | PASS |
| Reejecuci?n idempotente | PASS; ambas versiones quedaron omitidas |
| Tablas esperadas en `app` | PASS; 38 tablas de negocio con RLS |
| Tabla de control `app.schema_migrations` | PASS; 2 versiones registradas |
| Vistas API | PASS; cat?logo, compatibilidad, pedidos e inventario |
| Datos demo | PASS; 2 variantes y 2 filas de inventario |
| Reserva de checkout | PASS; saldo y reserva actualizados at?micamente |
| Reserva repetida con la misma idempotency key | PASS; no duplic? la reserva |
| Confirmaci?n de venta | PASS; descont? `on_hand` y consumi? la reserva |
| Falta de stock | PASS; la operaci?n fall? y la transacci?n se revirti? |
| Privilegios | PASS; `anon` no tiene escritura directa a inventario y s? lectura del cat?logo API |

La validaci?n se ejecut? desde `scripts/validacion-modelo-db.sql` dentro de una transacci?n de prueba que termin? con `ROLLBACK`; los pedidos ficticios utilizados para verificar reserva y venta no quedaron persistidos.

## Correcciones realizadas durante la aplicaci?n

- El ?ndice de productos publicados referenciaba una columna inexistente (`products.active`). Se ajust? para usar el estado `products.status`.
- La restricci?n expl?cita de inventario colisionaba con el nombre generado por el `CHECK` de columna. Se renombr? a `inventory_reserved_capacity_check` sin cambiar la regla de negocio.

## L?mites de esta evidencia

Esta evidencia valida el esquema, permisos y flujos transaccionales b?sicos en la base de desarrollo. No valida todav?a credenciales de Mercado Libre, pagos reales, despacho, conciliaci?n productiva, rendimiento bajo carga ni los escenarios de integraci?n enumerados como pendientes en el plan.
