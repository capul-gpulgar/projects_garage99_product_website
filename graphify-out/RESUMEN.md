# Garage99 — entrada breve al grafo

Consultar este índice antes del historial completo. Verificar vigencia con `scripts/Update-ProjectGraph.ps1 -Check`.

El grafo registra evidencia histórica; no consulta el estado remoto en tiempo real.

## Verificado

- Supabase PostgreSQL
- Hito de arranque DB completo
- public.connection_check
- Session pooler us-east-1
- TLS con certificado y hostname verificados
- SQL CRUD y ROLLBACK: PASS
- REST público: lectura y permisos PASS
- 16 pruebas locales aprobadas
- RLS y permisos de connection_check

## Decisiones pendientes

- Pasarela de pago por elegir: Mercado Pago, Transbank/Webpay o Stripe sujetos a habilitación; checkout y conciliación pendientes.
- Despacho por definir: Retiro, courier propio o Mercado Envíos; decidir método inicial y costo antes de fase 8.
- Boleta y facturación: Definir proceso tributario antes de vender; automatización en v1 o posterior por decidir.

## Próximo trabajo y alcance

Convertir el modelo documentado en migraciones incrementales de catálogo, compatibilidad e inventario; luego movimientos transaccionales. No implementado.

El catálogo, inventario comercial, web, pagos y Mercado Libre siguen planificados. No confundir la prueba de conectividad con inventario listo para vender.

Fuentes: `CONTEXT.md`, `PLAN-IMPLEMENTACION.md`, `docs/VALIDACION-DB-2026-09-05.md`. Protocolo y actualización: `AGENTS.md` y `docs/GRAFO-PROYECTO.md`.

## Consulta acotada

`graphify query "productos variantes inventario" --budget 1200`

Leer solo las fuentes relevantes antes de modificar. Los estados planificados no significan componentes implementados.
