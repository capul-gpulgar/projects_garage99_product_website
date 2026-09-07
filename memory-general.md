# Memoria general — Garage99

## Protocolo de continuidad — instrucción permanente del usuario

**Al retomar este proyecto, leer primero el grafo y mantenerlo siempre actualizado.**

- Verificar `contexto-proyecto.md` y esta sección; comprobar vigencia con `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Update-ProjectGraph.ps1 -Check`.
- Leer `graphify-out/RESUMEN.md` y consultar `graphify query "<tema>" --budget 1200` antes de abrir muchos archivos. No leer de entrada `graph.json` completo ni todo este historial.
- Seguir las referencias del grafo hacia las fuentes necesarias y comprobar allí las decisiones y el código antes de actuar. El ahorro de tokens depende de la consulta; no es una garantía fija.
- Tras cambios de código, arquitectura, decisiones, estado o próximos pasos, y antes de cerrar cada sesión: actualizar contexto y memoria, revisar `docs/graph-context.json`, regenerar mediante `scripts/Update-ProjectGraph.ps1` y comprobar que `-Check` pasa.
- Un grafo desactualizado no es fuente suficiente para responder. Si falla la actualización, registrar el pendiente y usar las fuentes afectadas directamente.
- Nunca incluir credenciales, `.env*`, dependencias ni salidas de `artifacts/`. El grafo no implica nuevas consultas a la DB.
- Documentación: [docs/GRAFO-PROYECTO.md](docs/GRAFO-PROYECTO.md). Grafo visual: [graphify-out/graph.html](graphify-out/graph.html).

## 2026-09-05 — Planificación inicial

- El usuario indicó `context.md`; el archivo encontrado es `CONTEXT.md`, que se conserva como contexto rector.
- Solicitud: planificación completa, priorizando montar DB y probar consultas/movimientos antes de construir y conectar el sitio.
- Se creó `PLAN-IMPLEMENTACION.md` con fases, dependencias, estimaciones, entregables, pruebas de aceptación y decisiones pendientes.
- No había `contexto-proyecto.md` ni `memory-general.md`; se crearon. El primero referencia el contexto original para evitar duplicación.
- Estado observado: solo documentación en el proyecto. `README.md` ya estaba modificado y `CONTEXT.md` sin seguimiento en Git; se preservó el README. No se crearon recursos remotos, aplicación o migraciones ni se ejecutaron pruebas de DB.
- Decisión de secuencia confirmada por el usuario: DB → validación → web y conexión. Reservas al checkout, duración de 15 minutos, CLP, checkout alojado y cuenta de cliente son propuestas del plan, pendientes de confirmar en sus fases.
- Precisión técnica: un log inmutable no evita por sí solo carreras. Se requieren transacciones, validación atómica e idempotencia. La DB puede garantizar sus reglas locales; la sincronización con ML tiene latencia y exige una política explícita de cupos o aceptación de riesgo residual.
- Propuesta de modelo: saldo proyectado en `inventory`, historial de deltas en `inventory_movements` y reservas explícitas; actualizados en una sola transacción. Los pedidos se incorporan antes de la web para probar las reglas.
- Aclaración: sincronización bidireccional significa incorporar eventos de pedidos/estados y publicar disponibilidad; no sobrescribir el inventario central con cualquier cantidad recibida de ML.
- Documentación oficial consultada: Vercel Hobby es para uso personal no comercial y su cron es diario. Presupuestar plan comercial y jobs con frecuencia adecuada. Referencias en el plan.
- Estimación inicial: 93–149 h base; aproximadamente 120–190 h con contingencia. Hito de preparación y DB: 27–43 h. Reestimar con datos reales.
- Próximo trabajo: fase 0/1, verificar herramientas y proyecto Supabase de pruebas, preparar conexión y primera consulta. Acceso a cuentas externas aún no comprobado.

## 2026-09-05 — Implementación del arranque Supabase

- El usuario confirmó que tiene cuenta Supabase sin proyecto y autorizó implementar el plan de hoy: entorno, proyecto `garage99-dev`, SQL de conectividad/CRUD y prueba REST externa.
- Se crearon `.gitignore`, `.env.example`, migración SQL para `connection_check`, validación SQL con insert/select/update/delete/rollback, validador PowerShell 5.1 y guía `docs/SUPABASE-ARRANQUE.md`.
- La tabla contiene solo datos ficticios; `anon` y `authenticated` tienen lectura con RLS. Se revocan escrituras directas a los roles de API. El propietario ejecuta la prueba SQL desde Dashboard.
- El validador usa solo clave `sb_publishable_`, valida URL/referencia y comprueba que POST/PATCH/DELETE reciben SQLSTATE 42501 y los datos permanecen iguales. No considera errores de red o claves inválidas como un éxito de seguridad.
- Validación local ejecutada: 15 casos con respuestas simuladas aprobados; sintaxis PowerShell correcta y `.env.local`/artefactos excluidos de Git. Esto NO demuestra conexión con Supabase ni ejecución SQL real.
- Windows usa PowerShell 5.1. La primera ejecución fue rechazada por la política predeterminada de scripts. MachinePolicy y UserPolicy están Undefined; las pruebas se ejecutaron con `-ExecutionPolicy Bypass` solo para ese proceso, sin cambiar políticas persistentes.
- Se intentó conectar el navegador mediante la habilidad Browser. El runtime respondió `No browser is available` y la lista de navegadores fue vacía. Tras el aviso «listo» del usuario se repitió la comprobación, con el mismo resultado. Se solicitó aclarar si conectó navegador o creó ya el proyecto.
- Pendiente: acceso al Dashboard o identificación del proyecto creado, región/ref verificadas, ejecutar migración/SQL y validar REST real. No se ha creado ni verificado un proyecto remoto desde esta sesión.
- La ejecución manual de la migración en SQL Editor no registra por sí sola el historial de Supabase CLI; al adoptar CLI será necesario alinear el estado remoto antes de aplicar migraciones.

## 2026-09-05 — Proyecto identificado y conectividad pendiente

- El usuario proporcionó el Dashboard del proyecto `bxhavpyvoijawzqiaspk`. Se registraron en `.env.local` la referencia y la URL API `https://bxhavpyvoijawzqiaspk.supabase.co`, preservando los demás campos.
- El usuario compartió una contraseña en el chat. Se indicó reemplazarla y guardarla en su gestor; no se copió a archivos, documentación ni configuración, ni se utilizó para autenticación.
- Nueva comprobación de Browser: no hay navegador disponible. La resolución DNS de `db.bxhavpyvoijawzqiaspk.supabase.co` devuelve IPv6; el intento TCP a 5432 por IPv6 no fue accesible desde el equipo.
- Se solicitó host/puerto de Connect → Session pooler y completar localmente `SUPABASE_PUBLISHABLE_KEY`. No se infiere la región desde DNS ni se prueban servidores alternativos al azar.
- Se preparó el cliente Python `pg8000` 1.31.5 en `artifacts/python-db` (ignorado por Git) para poder ejecutar SQL por Session pooler cuando estén disponibles los datos de conexión. No se instaló un servidor PostgreSQL ni se modificaron paquetes globales de Python.
- Sigue pendiente: comprobar nombre/región y estado del proyecto, ejecutar SQL y validar acceso REST real. Las 15 pruebas anteriores son locales y simuladas.

## 2026-09-05 — Arranque remoto completado

- El usuario proporcionó Session pooler `aws-0-us-east-1.pooler.supabase.com:5432`, base `postgres` y usuario `postgres.bxhavpyvoijawzqiaspk`. Se guardaron los parámetros no secretos en `.env.local`. Región del host: us-east-1; se respetó el proyecto creado por el usuario, sin recrearlo en São Paulo.
- El usuario proporcionó la clave publicable; se guardó únicamente en `.env.local`, excluido de Git. No se registra su valor en documentación ni reportes.
- La conexión TCP al pooler funcionó. La primera conexión SQL con credencial falló por validación del certificado antes de autenticarse. Se localizó la URL del certificado CA en el código público oficial de Supabase Studio y se descargó en `artifacts/certificates/prod-ca-2021.crt`.
- Se ejecutó SQL con pg8000 por Session pooler, verificando certificado y hostname. La contraseña previamente proporcionada se introdujo por entrada oculta del proceso, sin guardarla en disco, argumentos ni informes. Su reemplazo sigue pendiente del usuario, dado que fue publicada en el chat.
- A las 15:35 UTC: conexión SQL PASS, base/rol efectivos postgres, migración aplicada y script completo de CRUD, rollback, RLS y permisos en PASS. No se utilizó navegador ni SQL Editor.
- A las 15:36 UTC: REST real PASS. GET devolvió la fila esperada; POST/PATCH/DELETE respondieron HTTP 401 con SQLSTATE 42501 y las lecturas posteriores confirmaron datos intactos.
- Se corrigió un error de compatibilidad del validador REST: PowerShell 5.1 no resolvía PSScriptRoot en los valores por defecto de parámetros. Ahora se resuelven en el cuerpo del script; prueba de regresión por proceso independiente añadida. Suite local: 16 pruebas PASS.
- Evidencia resumida y hashes en `docs/VALIDACION-DB-2026-09-05.md`; informes de ejecución en artifacts. El nombre visible del proyecto y el plan contratado no se comprobaron; no bloquean la validación técnica completada.
- Se cierra el alcance acotado de hoy: DB montada y consultas/operaciones técnicas probadas desde el computador. Siguiente trabajo: productos, variantes e inventario; luego movimientos transaccionales. La reconstrucción del entorno descartable y alineación de historial CLI siguen pendientes en el plan general.

## 2026-09-05 — Grafo Graphify y continuidad

- El usuario pidió crear un grafo con Graphify y leerlo/actualizarlo siempre al retomar para reducir relecturas y consumo de contexto. Se incorporó el protocolo permanente al inicio de esta memoria y en `AGENTS.md` del proyecto.
- Graphify 0.9.53 ya estaba instalado vía uv. Se añadió `tree-sitter-sql` 0.3.11 a ese entorno para extraer SQL; no se modificó la DB para generar el grafo.
- Diseño: extracción estructural local con Graphify + entidades/relaciones semánticas revisadas en `docs/graph-context.json`. La extracción de documentos se delegó a un agente según la habilidad incluida en Graphify; no se usaron APIs externas de modelos.
- El grafo distingue evidencia de implementación actual, capacidades planificadas y decisiones pendientes. La tabla dummy sugerida en conversación no se considera creada ni probada sin evidencia.
- `scripts/Update-ProjectGraph.ps1` regenera el grafo; `-Check` compara huellas SHA-256 y detecta nuevos archivos, cambios y eliminaciones. Para cambios de documentos exige revisión semántica explícita con `-ReviewedDocs`; no se declara actualizado solo por reextraer código.
- Los archivos generados de referencia viven en `graphify-out/`: JSON consultable, HTML interactivo, informe y resumen. `.graphifyignore` excluye secretos, configuración privada, dependencias, artefactos y el propio grafo.
- El ahorro depende de la consulta y del tamaño de la respuesta. Los tokens de extracción semántica de la sesión no están disponibles como medición independiente; no confundir contadores vacíos de Graphify con costo cero.
- La actualización es una instrucción de trabajo persistente, sin proceso de vigilancia ni hooks instalados. Las fuentes originales y las pruebas prevalecen cuando contradicen el grafo.
- Verificación: consultas Graphify de inventario y Supabase devuelven fuentes y etiquetas PLAN/VERIFICADO/POR DECIDIR. Integridad sin extremos faltantes ni relaciones colapsadas en modo dirigido. Se probó detección STALE de un documento nuevo y recuperación CURRENT al retirarlo.
- El resumen para retomar queda en unas 250 palabras. `--budget` es orientativo en esta versión y puede sobrepasarse para mantener relaciones completas; acotar tema o usar `explain` con ID exacto si ocurre. No se adopta el ratio del benchmark genérico como ahorro real medido.

## 2026-09-06 — Modelo operacional documentado

- El usuario pidió implementar la propuesta de modelo de datos y dejar documentadas nomenclatura, buenas prácticas y lo realizado.
- Se confirmó el alcance ampliado: catálogo de repuestos, compatibilidad por marca/modelo/año/motor, compras y recepciones, inventario, ventas web y de mostrador, Mercado Libre, devoluciones y garantías.
- Se confirmó una ubicación inicial, Chile y CLP, unidades y kits cerrados con stock propio. Taller de reparaciones, multi-bodega, multi-moneda y kits armables quedan fuera del primer incremento.
- Se confirmó stock compartido con margen entre web, mostrador y Mercado Libre. El diseño parte con `safety_stock` configurable de una unidad por SKU; el riesgo de latencia se debe medir antes del piloto y puede llevar a cupos exclusivos para algunos SKU.
- Se confirmó que el carrito no reserva y que el checkout reserva durante 15 minutos. Pago, cancelación y expiración deben competir mediante transiciones atómicas e idempotentes.
- Se crearon `docs/MODELO-DATOS.md` y `docs/ESTANDARES-DATOS.md`. El primero define esquemas `app`/`api`, módulos, entidades, relaciones, campos, restricciones, superficie API y flujos; el segundo define nomenclatura, tipos, RLS, auditoría, migraciones y operación.
- Se actualizaron `CONTEXT.md`, `contexto-proyecto.md`, `PLAN-IMPLEMENTACION.md` y `README.md`; se crearon las migraciones versionadas `20260906000100_create_garage99_schema.sql` y `20260906000200_seed_garage99_demo.sql`, el aplicador TLS `scripts/apply_garage99_migrations.py` y la validación transaccional `scripts/validacion-modelo-db.sql`.
- Las migraciones estuvieron preparadas localmente en el primer registro; luego se aplicaron y validaron remotamente. La evidencia final esta en `docs/VALIDACION-MODELO-DB-2026-09-06.md`.
- Proximo hito: cerrar la matriz ampliada de Fase 4 y comenzar la primera API de catalogo/pedidos.

- Historial resuelto: un primer intento remoto fue rechazado con SQLSTATE `28P01`; la credencial correcta permitio aplicar y validar las migraciones. No se guardo ninguna credencial.

## 2026-09-06 ? Aplicaci?n y validaci?n del modelo operacional

- Se aplicaron en Supabase las migraciones `20260906000100` y `20260906000200` para el proyecto `bxhavpyvoijawzqiaspk` mediante Session Pooler TLS.
- La validaci?n transaccional remota pas?: 38 tablas con RLS, vistas API, seed demo, reserva idempotente, confirmaci?n de venta, rollback por falta de stock y permisos m?nimos. La evidencia est? en `docs/VALIDACION-MODELO-DB-2026-09-06.md`.
- La segunda ejecuci?n del aplicador omiti? ambas versiones correctamente, confirmando idempotencia.
- Durante la aplicaci?n se corrigieron el ?ndice de productos publicados y la colisi?n de nombre de una restricci?n de inventario; los cambios quedan en la migraci?n versionada.
- No se almacen? la contrase?a PostgreSQL. La credencial usada debe rotarse despu?s de esta sesi?n por haber sido compartida en el chat.

## 2026-09-06 - Cierre y handoff

- El estado completo para retomar esta en `docs/RETOMAR-PROXIMA-SESION.md`.
- La base remota esta aplicada y validada; la carga adicional `scripts/crear-items-demo.sql` fue probada con rollback y queda disponible para que el usuario la ejecute con commit.
- La siguiente sesion debe comenzar con Fase 4: concurrencia, RLS entre identidades, reconciliacion y escenarios de pago/devolucion; luego Fase 5: Route Handlers y contratos API.
- Las decisiones de pasarela, despacho, boleta/factura, invitado/cuenta, identidad visual y volumen siguen pendientes antes de sus fases respectivas.
- Grafo Graphify regenerado y `-Check` en estado CURRENT al cierre.
