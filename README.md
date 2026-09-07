# garage99_product_website
Desarrollo de pagina web para garage99

## Base de datos de desarrollo

El stack definido es Next.js en Vercel y Supabase/Postgres. Para crear
`garage99-dev` y verificar consultas SQL y acceso desde PowerShell, seguir
[la guía de arranque](docs/SUPABASE-ARRANQUE.md).

DB remota operativa: esquema Garage99 aplicado y validado.
[Evidencia del arranque](docs/VALIDACION-DB-2026-09-05.md) ? [Evidencia del modelo](docs/VALIDACION-MODELO-DB-2026-09-06.md).
Contexto: [CONTEXT.md](CONTEXT.md). Plan: [PLAN-IMPLEMENTACION.md](PLAN-IMPLEMENTACION.md).
Continuidad: [docs/RETOMAR-PROXIMA-SESION.md](docs/RETOMAR-PROXIMA-SESION.md).

Modelo de datos implementado: [docs/MODELO-DATOS.md](docs/MODELO-DATOS.md).
Nomenclatura y buenas prácticas: [docs/ESTANDARES-DATOS.md](docs/ESTANDARES-DATOS.md).
Migraciones del modelo: [supabase/migrations/20260906000100_create_garage99_schema.sql](supabase/migrations/20260906000100_create_garage99_schema.sql) y [supabase/migrations/20260906000200_seed_garage99_demo.sql](supabase/migrations/20260906000200_seed_garage99_demo.sql).
Aplicación reproducible: [scripts/apply_garage99_migrations.py](scripts/apply_garage99_migrations.py). Validación: [scripts/validacion-modelo-db.sql](scripts/validacion-modelo-db.sql).
Carga demo reproducible: [scripts/crear-items-demo.sql](scripts/crear-items-demo.sql).
La tabla `connection_check` es únicamente técnica; el modelo comercial se aplica
por migraciones versionadas.

## Grafo del proyecto

[Grafo interactivo de Graphify](graphify-out/graph.html) ·
[Resumen para retomar](graphify-out/RESUMEN.md) ·
[Consulta y actualización](docs/GRAFO-PROYECTO.md).

Al retomar, comprobar la vigencia del grafo y consultar solo el contexto necesario.
El protocolo permanente está al inicio de `memory-general.md` y en `AGENTS.md`.
