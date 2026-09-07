# Contexto del proyecto

Actualizado: 2026-09-06.

El contexto rector de Garage99 se mantiene en [CONTEXT.md](CONTEXT.md), archivo indicado por el usuario. Este documento es su punto de entrada y no duplica el contenido.

**Al retomar:** seguir el protocolo de `memory-general.md`, verificar vigencia y
leer [el resumen del grafo](graphify-out/RESUMEN.md). Usar consultas Graphify de
alcance acotado antes de abrir el contexto largo.

- Objetivo: tienda propia con stock centralizado en Supabase y coordinación con Mercado Libre.
- Orden solicitado: montar DB, validar consultas y movimientos, construir la web y conectarla; completar pagos e integración antes del lanzamiento.
- Plan detallado: [PLAN-IMPLEMENTACION.md](PLAN-IMPLEMENTACION.md).
- Decisiones y aprendizajes: [memory-general.md](memory-general.md).
- Guía para montar y probar Supabase: [docs/SUPABASE-ARRANQUE.md](docs/SUPABASE-ARRANQUE.md).
- Modelo de datos: [docs/MODELO-DATOS.md](docs/MODELO-DATOS.md).
- Estándares de datos: [docs/ESTANDARES-DATOS.md](docs/ESTANDARES-DATOS.md).
- Migraciones de negocio: `supabase/migrations/20260906000100_create_garage99_schema.sql` y `20260906000200_seed_garage99_demo.sql`.
- Aplicación y validación: `scripts/apply_garage99_migrations.py` y `scripts/validacion-modelo-db.sql`.
- Proyecto operativo: `bxhavpyvoijawzqiaspk` ([Dashboard](https://supabase.com/dashboard/project/bxhavpyvoijawzqiaspk)), con Session pooler `us-east-1` suministrado por el usuario. Nombre visible y plan no verificados; configuración local guardada sin contraseña PostgreSQL.
- Estado: hito de arranque DB completado. Migración aplicada; SQL CRUD/rollback/RLS y REST reales en PASS. Dieciséis pruebas locales adicionales aprobadas. [Evidencia del arranque](docs/VALIDACION-DB-2026-09-05.md). Las migraciones del modelo operacional están aplicadas y validadas en desarrollo. [Evidencia del modelo](docs/VALIDACION-MODELO-DB-2026-09-06.md).
- Proximo paso: cerrar la matriz ampliada de Fase 4 (concurrencia, RLS y reconciliacion) y luego iniciar la primera API de catalogo/pedidos.
- Handoff para la próxima sesión: [docs/RETOMAR-PROXIMA-SESION.md](docs/RETOMAR-PROXIMA-SESION.md).
