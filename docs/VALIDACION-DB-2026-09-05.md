# Validación real de Supabase — 2026-09-05

**Resultado: PASS para el hito de arranque de DB y acceso externo.**

## Entorno verificado

- Proyecto: `bxhavpyvoijawzqiaspk` ([Dashboard](https://supabase.com/dashboard/project/bxhavpyvoijawzqiaspk)).
- API: `https://bxhavpyvoijawzqiaspk.supabase.co`.
- Session pooler suministrado por el usuario: `aws-0-us-east-1.pooler.supabase.com:5432`.
- Región indicada por el host proporcionado: `us-east-1`; no se cambió la región ni se creó otro proyecto.
- Base y rol efectivos devueltos por PostgreSQL: `postgres` / `postgres`.
- El nombre visible del proyecto y el plan contratado no se comprobaron en Dashboard; no se contrataron servicios desde esta sesión.

## SQL real

Comprobación iniciada a las `2026-09-05T15:35:44Z`.

Se conectó desde este equipo por Session pooler con TLS, validando cadena y
hostname. Se aplicó `20260905000100_connection_check.sql` porque la tabla aún
no existía. Después se ejecutó completo `scripts/validacion-db.sql` sin errores.

| Prueba | Resultado |
|---|---|
| Consulta de base, usuario y fecha | PASS |
| Inserción y consulta de fila ficticia | PASS |
| Actualización del mensaje | PASS |
| Eliminación y rollback que restaura la fila | PASS |
| RLS habilitado | PASS |
| Lectura bajo rol `anon` | PASS |
| Permisos de escritura/truncate ausentes para `anon` y `authenticated` | PASS |

Estado final de la fila:

| id | message |
|---|---|
| garage99-db-check | garage99-dev: lectura verificada |

Huella SHA-256 de la migración ejecutada:
`ecb71c67e8a5de5750d51b30483206f4da990abc5fbdd04db8a43766b7485ef1`.

Huella SHA-256 del SQL de validación ejecutado:
`53ce83bf7aa5462260a3190ec2886353f0f7620eb6c9a323c0bf196b222a8481`.

## REST real desde PowerShell

Comprobación a las `2026-09-05T15:36:26Z`, usando únicamente la clave publicable.

| Prueba | Resultado |
|---|---|
| GET de la fila, comparada con el resultado SQL | PASS |
| POST rechazado | HTTP 401, SQLSTATE 42501 |
| PATCH rechazado | HTTP 401, SQLSTATE 42501 |
| DELETE rechazado | HTTP 401, SQLSTATE 42501 |
| Lectura después de cada intento: datos intactos | PASS |

Estos 401 corresponden a permisos PostgreSQL denegados, no a una clave inválida:
la lectura con la misma clave funcionó y el código de error fue `42501`.

Informes de ejecución sin credenciales:
`artifacts/supabase-sql.json` y `artifacts/supabase-connection.json` (salidas locales
excluidas de Git). Este documento conserva el resumen revisable en el repositorio.

## Correcciones y reproducción

- El endpoint PostgreSQL directo IPv6 no fue accesible; se utilizó el Session pooler IPv4 proporcionado por el usuario.
- Se cargó la CA oficial de Supabase sin desactivar la validación TLS. La URL se verificó en el [código oficial de Studio](https://github.com/supabase/supabase/blob/master/apps/studio/hooks/custom-content/custom-content.json): `https://supabase-downloads.s3-ap-southeast-1.amazonaws.com/prod/ssl/prod-ca-2021.crt`.
- Huella SHA-256 del certificado descargado: `700723581420dd1ac98fd7e9ac529f0ef210eadcaf87fc868a3ad7d114c2f3b7`.
- Se corrigió la resolución de rutas por defecto del script REST en Windows PowerShell 5.1. La regresión está cubierta por una prueba que ejecuta el script como proceso independiente sin conectar a la red.
- Suite local: **16 pruebas aprobadas**, adicionales a las pruebas remotas anteriores. Sintaxis Python comprobada.
- Procedimiento de reproducción: [SUPABASE-ARRANQUE.md](SUPABASE-ARRANQUE.md). La migración ya está aplicada; no volver a crear la tabla.

## Próximo hito

Crear productos, variantes y modelo de inventario, e implementar movimientos
transaccionales. Esta prueba técnica no valida todavía stock, reservas, compras,
pagos, autenticación de clientes ni integración con Mercado Libre.

La contraseña compartida previamente en el chat sigue pendiente de reemplazo
por el propietario. Se utilizó exclusivamente para la conexión SQL verificada;
no se guardó en archivos, argumentos de proceso ni informes.
