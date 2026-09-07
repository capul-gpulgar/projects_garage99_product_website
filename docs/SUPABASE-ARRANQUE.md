# Garage99 — Arranque de la DB de desarrollo

## Estado

**Arranque completado el 2026-09-05.** Proyecto `bxhavpyvoijawzqiaspk` operativo,
migración aplicada y pruebas SQL y REST reales aprobadas.
[Evidencia](VALIDACION-DB-2026-09-05.md).

Se utilizó el Session pooler `aws-0-us-east-1.pooler.supabase.com:5432` suministrado
por el usuario; el endpoint directo IPv6 no es accesible desde este equipo. Los
parámetros de conexión y la clave publicable están en `.env.local`, sin contraseña
PostgreSQL. El nombre visible del proyecto y el plan contratado no se verificaron.

Los puntos 1 y 2 documentan cómo preparar un entorno nuevo. **No volver a crear
el proyecto ni aplicar la migración sobre la tabla existente.** Para repetir la
validación actual, usar el punto 2b y la prueba REST del punto 4.

## 1. Crear el proyecto

En [Supabase Dashboard](https://supabase.com/dashboard), usar tu organización
personal y crear `garage99-dev` en plan gratuito si hay capacidad disponible.
Elegir São Paulo (`sa-east-1`) si se ofrece, o la región sudamericana disponible
más cercana a Chile. No contratar un plan pagado para completar esta prueba.

Generar una contraseña PostgreSQL y guardarla directamente en tu gestor de
contraseñas. La prueba REST no la necesita; el cliente SQL del punto 2b la pide
por entrada oculta, sin guardarla en archivos ni argumentos.
Esperar a que el proyecto esté activo. Registrar nombre, referencia y región en
la memoria del proyecto, sin contraseñas.

## 2. Crear la tabla y ejecutar pruebas SQL

Abrir SQL Editor en **garage99-dev** y ejecutar primero:

```sql
select current_database(), current_user, now();
```

Ejecutar completo, una sola vez:

`supabase/migrations/20260905000100_connection_check.sql`

La migración crea `public.connection_check(id text primary key, message text)`,
habilita RLS y deja únicamente lectura para `anon` y `authenticated`. La tabla
es pública para lectura: solo contiene mensajes técnicos ficticios.

Después ejecutar completo:

`scripts/validacion-db.sql`

Este script inserta/consulta la fila `garage99-db-check`, modifica su mensaje,
prueba una eliminación con rollback y verifica los permisos. El resultado final
debe indicar `PASS: SQL CRUD, rollback, RLS and grants` y devolver:

| id | message |
|---|---|
| garage99-db-check | garage99-dev: lectura verificada |

Si aparece cualquier error SQL, la prueba no está aprobada aunque existan otros
resultados. Ejecutar `ROLLBACK;` para salir de una transacción fallida antes de
corregir el problema. No volver a aplicar la migración sobre una tabla existente;
no contiene un borrado/recreación automático. La prueba SQL sí es repetible.

El archivo queda versionado como migración, pero ejecutarlo desde Dashboard no
registra automáticamente el historial de Supabase CLI. Antes de adoptar CLI,
capturar/alinear el esquema remoto y su historial; no ejecutar `db push` a ciegas.

## 2b. Repetir las pruebas SQL desde este computador

Python 3.12 y el cliente `pg8000` ya están disponibles localmente para este hito.
El script `validate_supabase_sql.py` lee host, puerto, base y usuario desde
`.env.local` y pide la contraseña de forma oculta en una terminal interactiva:

```powershell
python .\scripts\validate_supabase_sql.py
```

Esto repite la prueba sobre la fila técnica, sin volver a crear la tabla. El
resultado se guarda sin secretos en `artifacts/supabase-sql.json`. La opción
`--apply-migration` solo se necesita para un entorno nuevo donde no exista la tabla;
si encuentra una tabla existente sin el marcador esperado, se detiene sin modificarla.

Para preparar estas dependencias en otro equipo con Python:

```powershell
python -m pip install --target artifacts/python-db pg8000==1.31.5
New-Item -ItemType Directory -Path artifacts/certificates -Force | Out-Null
Invoke-WebRequest -UseBasicParsing -Uri 'https://supabase-downloads.s3-ap-southeast-1.amazonaws.com/prod/ssl/prod-ca-2021.crt' -OutFile 'artifacts/certificates/prod-ca-2021.crt'
```

La dirección de la CA se verificó en el [código oficial de Supabase Studio](https://github.com/supabase/supabase/blob/master/apps/studio/hooks/custom-content/custom-content.json).
El cliente conserva la verificación del certificado y del hostname. Los paquetes
y el certificado quedan en `artifacts`, fuera de Git; no se instala un servidor
PostgreSQL ni se cambian paquetes globales de Python.

## 3. Configuración de la prueba desde PowerShell

Desde la raíz del repositorio, copiar la plantilla si aún no existe:

```powershell
if (-not (Test-Path -LiteralPath '.env.local')) {
    Copy-Item -LiteralPath '.env.example' -Destination '.env.local'
}
```

Editar `.env.local` localmente. Copiar del Dashboard la URL y la clave
**publicable** `sb_publishable_...`. Completar también referencia y región.
La clave se envía solo en el encabezado `apikey`; no se usa una clave privada,
un token de administración ni la contraseña PostgreSQL.
[Claves de API de Supabase](https://supabase.com/docs/guides/getting-started/api-keys).

El lector de configuración no ejecuta contenido del archivo y rechaza claves
privilegiadas, duplicados, URLs ajenas a Supabase y referencias inconsistentes.
`.env.local` está excluido de Git.

## 4. Prueba externa real

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-SupabaseConnection.ps1
```

La prueba usa Windows PowerShell 5.1, sin instalar Node.js, Docker ni PostgreSQL.
Lee `/rest/v1/connection_check`, comprueba la fila esperada y prueba `POST`,
`PATCH` y `DELETE` únicamente sobre datos técnicos. Cada escritura debe responder
con HTTP 401/403 y SQLSTATE `42501` (permiso denegado); después vuelve a consultar
para comprobar que los datos no cambiaron.

Un error de red, clave inválida, tabla inexistente o respuesta vacía **no** se
acepta como evidencia de permisos correctos. Si una escritura funciona por una
configuración incorrecta, la prueba falla: corregir permisos, revisar la tabla
técnica y repetir el SQL. Nunca ejecutar estas pruebas sobre tablas de negocio.

El script guarda `artifacts/supabase-connection.json` sin claves, encabezados ni
respuestas completas del servidor. Devuelve código 0 con PASS y 1 con FAIL;
un intento fallido sustituye el informe anterior para evitar un PASS obsoleto.
Los errores de configuración/conectividad generan FAIL y requieren revisar la
causa; ese estado no significa que el proyecto remoto haya sido probado.

Se verificó que `MachinePolicy` y `UserPolicy` están en `Undefined` en este equipo.
`-ExecutionPolicy Bypass` aplica únicamente al proceso invocado; no modifica la
política permanente. Si existe una política organizacional en otro equipo,
respetarla y revisar con su administrador.

## 5. Comprobaciones locales del validador

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-ConnectionValidator.ps1
```

Verifica configuración, rechazo de claves incorrectas y respuestas simuladas de
lectura/escritura. Distinguir siempre este resultado de la prueba real del punto 4.

## Criterio para cerrar el hito

- Proyecto de desarrollo activo, con referencia y región de conexión registradas.
- Consulta SQL y script de CRUD/rollback/permisos ejecutados sin errores.
- Prueba REST real en PASS; lecturas correctas y tres escrituras rechazadas.
- Evidencia resumida en `memory-general.md` y estado actualizado en el plan.

La tabla es una prueba técnica de conectividad. El catálogo, el inventario,
las reservas, la web y las integraciones aún no forman parte de esta entrega.
