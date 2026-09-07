# Garage99 — Plan de implementación

Fecha: 2026-09-06. Estado: hito de arranque DB completado; modelo operacional aplicado y validado en desarrollo.
Contexto rector: [CONTEXT.md](CONTEXT.md).

Avance del alcance de hoy: configuración preparada y migración `connection_check`
aplicada al proyecto `bxhavpyvoijawzqiaspk`. Pruebas SQL y REST reales en PASS;
16 pruebas locales aprobadas. [Evidencia](docs/VALIDACION-DB-2026-09-05.md).
Este cierre corresponde al plan acotado de hoy; no equivale al hito 1 de inventario
completo descrito más adelante. Reconstrucción de un entorno descartable e historial
CLI siguen pendientes dentro del plan general.
Procedimiento: [docs/SUPABASE-ARRANQUE.md](docs/SUPABASE-ARRANQUE.md).
Modelo y diccionario: [docs/MODELO-DATOS.md](docs/MODELO-DATOS.md). Estándares:
[docs/ESTANDARES-DATOS.md](docs/ESTANDARES-DATOS.md).
Migraciones: `supabase/migrations/20260906000100_create_garage99_schema.sql` y
`supabase/migrations/20260906000200_seed_garage99_demo.sql`. Aplicador:
`scripts/apply_garage99_migrations.py`. Validación: `scripts/validacion-modelo-db.sql`.

## 1. Resultado y orden de trabajo

Construir una tienda propia con inventario centralizado en Supabase y ventas por web y Mercado Libre. La secuencia solicitada es: **montar la base de datos → demostrar consultas y movimientos → construir el sitio → conectarlo → incorporar pagos y sincronización → lanzar**.

Cada fase termina con una demostración y un criterio de aceptación. No avanzar al sitio hasta aprobar el funcionamiento y los permisos del inventario. La revisión temprana de requisitos de Mercado Libre sirve para validar el modelo, sin activar aún la sincronización ni modificar publicaciones reales.

Situación inicial al planificar: el repositorio contenía `CONTEXT.md` y `README.md`, sin aplicación, migraciones ni pruebas. Ahora existe una DB remota con tabla técnica y modelo de negocio aplicado. La documentación, migraciones y validación están registradas en `docs/VALIDACION-MODELO-DB-2026-09-06.md`.

## 2. Decisiones y supuestos de planificación

**Ya definidos:** Next.js en Vercel, Route Handlers como API, Supabase Postgres/Auth/Storage, inventario por variante, una ubicación propia, Chile/CLP en v1, Mercado Libre como canal, compatibilidad por marca/modelo/año/motor, ventas web y mostrador, devoluciones/garantías, stock compartido con margen y reserva web de 15 minutos.

**Propuestas para implementar, revisables antes de su fase:**

- Desarrollo en un proyecto Supabase de pruebas; SQL versionado desde el primer cambio. Reproducción y pruebas locales con Supabase CLI y Docker cuando estén disponibles. Producción separada antes del piloto.
- Una variante predeterminada para productos sin talla/color. SKU único en la variante vendible; el producto agrupa variantes.
- `on_hand`: unidades vendibles contabilizadas, incluyendo unidades comprometidas aún no descontadas por venta. `reserved`: parte comprometida. `available = on_hand - reserved`. Un producto dañado no vuelve a stock vendible.
- El saldo de `inventory` es una proyección del registro de movimientos. Saldo, movimiento, reserva y cambios del pedido se actualizan juntos en una transacción. No sumar todo el historial en cada visita al catálogo.
- Reservar al iniciar el checkout, después de revalidar precios y cantidades. El carrito no reserva. La vigencia inicial confirmada para el diseño es de 15 minutos; podrá ajustarse después de elegir la pasarela.
- Un pago confirmado consume la reserva y registra la salida por venta. El despacho actualiza el cumplimiento del pedido y no descuenta otra vez. Esta es una definición contable de stock vendible, no una medición de todo lo físicamente presente en bodega.
- Partir con CLP y operación en Chile, confirmado para el diseño inicial. Guardar moneda explícita e importes exactos; evitar coma flotante para dinero.
- Para v1, checkout alojado por la pasarela y un método inicial de despacho/retiro, sujetos a la elección comercial. No almacenar datos de tarjeta.
- Los cambios comerciales del catálogo y ajustes de inventario se administran en Garage99. Mercado Libre aporta eventos de pedidos y estados de publicaciones; una cantidad recibida desde ML no sustituye automáticamente el saldo central.
- El diseño ampliado incorpora proveedores/recepciones, ventas de mostrador, devoluciones y garantías. El taller de reparaciones, multi-bodega, multi-moneda y kits armables quedan fuera del primer incremento.

**Corrección de arquitectura:** un registro de movimientos permite auditar, pero por sí solo no evita carreras. Las operaciones deben validar y bloquear/actualizar el saldo de forma atómica. Entre Supabase y Mercado Libre no existe una transacción compartida: el stock compartido deja riesgo residual por latencia. La política elegida para el diseño inicial es stock compartido con margen configurable, comenzando con una unidad de seguridad por SKU; antes del piloto se medirá el riesgo y se decidirá si algún SKU requiere cupos exclusivos.

## 3. Fases, entregables y criterios de avance

Los tiempos son estimaciones de trabajo técnico efectivo, no compromisos de calendario. Las esperas por cuentas, aprobaciones comerciales o proveedores van aparte.

| Fase | Dependencia | Horas | Resultado |
|---|---|---:|---|
| 0. Preparación | Ninguna | 3–5 | Insumos y reglas mínimas |
| 1. Montar DB de pruebas | 0 | 4–6 | Postgres accesible |
| 2. Catálogo e inventario base | 1 | 6–10 | Modelo y datos de ejemplo |
| 3. Movimientos y reservas | 2 | 8–12 | Operaciones atómicas |
| 4. Validación de DB y permisos | 3 | 6–10 | Hito DB aprobado |
| 5. API y conexión técnica | 4 | 6–10 | Contratos probados sin interfaz |
| 6. Sitio de compra | 5 | 12–18 | Catálogo y carrito conectados |
| 7. Administración | 5; se integra con 6 | 8–12 | Operación diaria desde panel |
| 8. Pagos y despacho | 6–7 y proveedor definido | 10–16 | Compra completa en pruebas |
| 9. Mercado Libre | 5 y accesos ML; cierre tras 8 | 18–30 | Inventario coordinado por canal |
| 10. Validación integral | 8–9 | 8–12 | Candidato a producción |
| 11. Piloto y lanzamiento | 10 | 4–8 | Primera venta real verificada |

Total base: **93–149 horas**. Reservar aproximadamente 25% para ajustes: **120–190 horas**. Con 5–10 horas semanales: aproximadamente **12–38 semanas**; cuentas y habilitaciones pueden ampliar el plazo. Reestimar al cerrar la fase 4 y después de la primera prueba real de API de ML. Un catálogo amplio o distintas modalidades logísticas requieren revisar este cálculo.

### Fase 0 — Preparación e insumos

1. Verificar herramientas locales, acceso personal al repositorio y existencia de proyectos Supabase/Vercel. Usar cuentas y recursos propios.
2. Reunir una muestra de 5–10 productos con SKU, variantes, precio, stock inicial y una imagen. Empezar con datos ficticios si faltan datos reales.
3. Confirmar país, moneda, una bodega, existencia de publicaciones ML y uso de variantes, Full u otras modalidades. El stock gestionado por Full requiere delimitar disponibilidad antes de compartirlo con la web.
4. Acordar el vocabulario del inventario, ajustes permitidos, tratamiento de cancelaciones y devoluciones. Registrar responsable de ajustes y conciliación.
5. Verificar acceso al programa de desarrolladores y requisitos de la cuenta de ML; comprobar el modelo de publicaciones/variantes aplicable. Detectar impedimentos temprano, sin implementar aún el conector.
6. Abrir una lista de pendientes de pagos, despacho, documentación tributaria, volumen y presupuesto. Asignar a cada uno una fase límite, según la sección 7.

**Entregable:** muestra de catálogo y decisiones mínimas registradas. **Salida:** conocemos la unidad vendible y podemos crear el esquema sin depender del diseño web.

### Fase 1 — Montar la base de datos

1. Crear o identificar un proyecto Supabase de desarrollo, revisar región y conectividad. Registrar el identificador del proyecto, sin guardar credenciales en documentación.
2. Preparar `.gitignore`, `.env.example` sin valores secretos y configuración privada de conexión. Distinguir clave pública de claves privilegiadas.
3. Inicializar `supabase/` y migraciones SQL. Todo cambio de esquema, función y permiso debe quedar en archivos reproducibles. El SQL Editor se puede usar para explorar y ejecutar consultas.
4. Conectar con SQL Editor y un cliente SQL o script local. Ejecutar `select current_database(), current_user, now();` y registrar el resultado sin secretos.
5. Validar conexión desde fuera del Dashboard mediante una operación de lectura. Una conexión exitosa con el usuario propietario no certifica los permisos de la futura aplicación.
6. Preparar un entorno descartable para probar reconstrucción por migraciones; cualquier reset se limita explícitamente al entorno local/de pruebas destinado a ello.

**Entregables:** configuración, primera migración y procedimiento de conexión. **Salida:** una consulta se ejecuta desde dos accesos y el entorno queda identificado. **Primer resultado visible:** DB conectada, antes de tener una web.

### Fase 2 — Modelo y carga de ejemplo

1. Crear los esquemas `app` e `api` y las entidades de catálogo/compatibilidad definidas en `docs/MODELO-DATOS.md`; después crear `products`, `product_variants`, `inventory` e `inventory_movements`.
2. Definir identificadores, relaciones, SKU único, estados de producto, timestamps UTC, precio exacto, cantidades enteras y restricciones de saldo/reserva.
3. Crear una vista segura de catálogo/disponibilidad. No exponer costes, tokens, movimientos ni datos de clientes a visitantes.
4. Definir índices para SKU, variante, producto activo y consulta de movimientos por variante/fecha.
5. Cargar al menos 5 productos y 8 variantes, incluyendo un producto sin opciones, uno agotado y otro con una sola unidad.
6. Crear saldos inicialmente en cero. La carga de stock se realizará mediante la función de entrada de fase 3, también desde el seed definitivo.
7. Preparar consultas comentadas: catálogo, búsqueda por SKU, disponibles, agotados, stock bajo e historial de una variante.

**Entregables:** migraciones, [diccionario de datos](docs/MODELO-DATOS.md), [estándares](docs/ESTANDARES-DATOS.md), datos de ejemplo y `scripts/validacion-db.sql`. **Salida:** relaciones y restricciones funcionan; no se puede duplicar un SKU ni crear referencias inválidas.

### Fase 3 — Movimientos, pedidos y reservas

1. Incorporar `orders`, `order_items` e `inventory_reservations`. Separar estado comercial, pago y cumplimiento. Guardar en el pedido el SKU, nombre y precio vendidos como fotografía histórica.
2. Crear funciones para entrada, ajuste con motivo, reserva de pedido, liberación, confirmación de venta y devolución inspeccionada.
3. Cada operación verifica actor autorizado, cantidades y transición de estado. Bloquea/actualiza filas de inventario dentro de una única transacción y registra su movimiento.
4. Para pedidos con varias variantes, bloquear en orden estable y confirmar todas las líneas o ninguna. Evitar reservas parciales involuntarias.
5. Añadir clave de idempotencia con unicidad: repetir la misma solicitud devuelve su resultado previo y no repite el efecto. Rechazar la misma clave con parámetros diferentes.
6. Registrar actor o servicio, motivo, referencia, canal, fecha y deltas de `on_hand` y `reserved`. Prohibir edición/borrado de movimientos al rol de aplicación; corregir mediante un movimiento compensatorio.
7. Modelar vencimiento de reservas. Expiración, pago y cancelación deben competir por una transición atómica para no liberar/descontar dos veces.
8. Crear reconciliación: suma de deltas frente a saldo, y reservas activas frente a `reserved`. Una diferencia genera investigación, no un ajuste automático sin explicación.

**Entregables:** funciones SQL, reglas de transición y demostración sin interfaz. **Salida:** todos los cambios normales de inventario pasan por funciones controladas.

### Fase 4 — Validar la DB antes de avanzar

1. Ejecutar la matriz de la sección 5 con resultados esperados y observados.
2. Probar concurrencia desde dos sesiones independientes, incluyendo última unidad y pedidos con varias líneas.
3. Configurar RLS, permisos de tablas/vistas y ejecución de funciones: visitante solo catálogo publicado; cliente solo sus pedidos; administrador con operaciones autorizadas.
4. Los roles administrativos deben provenir de información que el cliente no pueda editar. Probar funciones privilegiadas, si existen, con privilegios mínimos y `search_path` controlado.
5. Revocar escrituras directas de stock y movimientos para roles de aplicación. Las claves privilegiadas permanecen en servidor y requieren autorización explícita en cada operación que las use.
6. Repetir las pruebas de acceso como anónimo, cliente A, cliente B y administrador; incluir intentos de invocar funciones sensibles directamente.
7. Reconstruir una DB descartable con migraciones y seed y repetir las pruebas críticas. Dejar evidencia de ejecución y comandos reproducibles.

**Entregables:** pruebas automatizadas de reglas críticas y permisos, informe breve y guía de consultas. **Salida obligatoria:** stock consistente, sin negativos, sin efectos duplicados y sin acceso cruzado entre clientes. **Hito 1: base de datos lista para conectar.**

### Fase 5 — API y conexión técnica

1. Inicializar Next.js con TypeScript y configurar variables por entorno. Instanciar acceso Supabase de servidor y de usuario según responsabilidad.
2. Definir contratos para listar/ver productos, consultar disponibilidad, crear reserva/pedido, consultar pedido propio y operar inventario como administrador.
3. Validar entradas, sesión, pertenencia del pedido y rol en el servidor. Recalcular precios y disponibilidad; no confiar en los totales enviados por el navegador.
4. Consumir las funciones de DB desde los Route Handlers sin duplicar las reglas de stock en JavaScript.
5. Añadir errores comprensibles, límites de solicitudes en operaciones sensibles, identificación de peticiones y logs sin credenciales ni datos personales innecesarios.
6. Probar con un cliente HTTP: consultar catálogo, reservar, leer pedido, cancelar y comprobar el saldo.

**Entregables:** API funcional y ejemplos de solicitudes/respuestas. **Salida:** recorrido técnico completo por HTTP antes de diseñar pantallas.

### Fase 6 — Sitio conectado

1. Definir navegación y diseño móvil: inicio, catálogo, detalle, carrito, checkout, resultado y consulta de pedido.
2. Implementar primero catálogo y detalle leyendo productos reales de la DB de pruebas, incluyendo imágenes de Supabase Storage.
3. Incorporar selección de variante, búsqueda/filtros básicos y estados agotado, carga, error y catálogo vacío.
4. Implementar carrito persistente sin reservar unidades. Revalidar cada producto antes del checkout.
5. Conectar el inicio del checkout a reserva/pedido. Mostrar claramente cuando precio o disponibilidad hayan cambiado.
6. Configurar Auth y recuperación de acceso. Propuesta inicial: cuenta para consultar pedidos; revisar compra como invitado antes de finalizar el diseño.
7. Aplicar metadatos, URLs legibles, sitemap y accesibilidad básica. Definir invalidación de caché tras cambios; el stock mostrado nunca reemplaza la validación transaccional al comprar.

**Entregable:** sitio navegable con catálogo y carrito conectados. **Salida:** cambios en producto/stock aparecen en la web según la política de actualización. **Hito 2: web conectada sin pagos reales.**

### Fase 7 — Panel de administración

1. Crear acceso administrativo y comprobar autorización en servidor, además de la interfaz.
2. Implementar alta/edición/archivado de productos y variantes, precios e imágenes. Evitar borrar registros referenciados por pedidos.
3. Incorporar entradas, ajustes con motivo, consulta de saldos e historial de movimientos.
4. Mostrar pedidos, pago, preparación, despacho/retiro, cancelación y devoluciones con sus transiciones permitidas.
5. Preparar vista de discrepancias e integraciones fallidas; completarla al incorporar ML.

**Entregable:** panel mínimo operativo. **Salida:** administrar catálogo, inventario y pedidos habituales no requiere editar SQL.

### Fase 8 — Pagos y despacho

1. Elegir pasarela verificando habilitación para el comercio/país, comisiones, liquidación, sandbox y modalidades de pago. No asumir disponibilidad de Stripe u otro proveedor.
2. Crear `payment_attempts` y registro duradero de eventos. Relacionar cada intento con pedido, moneda, monto e identificador externo único.
3. Crear el checkout desde servidor a partir del pedido reservado. Si falla la creación, mantener una política definida de reintento/vencimiento y no dejar reservas indefinidas.
4. Procesar webhooks según autenticación/verificación oficial del proveedor y consultar el estado autoritativo cuando corresponda. Validar comercio, pedido, monto y moneda.
5. Confirmar venta solo desde evidencia del proveedor, nunca por la URL de regreso del navegador. Soportar eventos duplicados, tardíos y fuera de orden.
6. Ejecutar vencimientos mediante un job persistente con frecuencia compatible con el plazo de reserva. Ante pago tardío, intentar adquirir stock atómicamente; si no alcanza, registrar la excepción y ejecutar el flujo de devolución/atención acordado.
7. Configurar un método inicial de entrega y su costo antes del pago; persistir dirección o punto de retiro en el pedido.
8. Probar aprobado, rechazado, pendiente, abandono, reintento, pago tardío, reembolso y cancelación. Reembolsar no repone automáticamente mercancía ya entregada; la devolución física requiere inspección.
9. Definir el proceso aplicable de boleta/factura con el responsable contable antes de vender, aunque la automatización tributaria quede fuera de v1.

**Entregable:** compra de prueba completa y conciliación de pagos. **Salida:** un pago confirmado afecta el stock una sola vez. **Hito 3: tienda transaccional en pruebas.**

### Fase 9 — Integración con Mercado Libre

1. Registrar/configurar aplicación, permisos y OAuth. Validar `state`, restringir la conexión al administrador y proteger tokens; implementar renovación y aviso ante desconexión.
2. Crear mapeos entre variante local y los identificadores vigentes de publicación/variante de ML para la cuenta. No asumir que `item_id` solo identifica cada SKU vendible.
3. Vincular publicaciones existentes y resolver SKUs ambiguos antes de crear nuevas. Evitar publicar duplicados.
4. Crear/actualizar una publicación de prueba con los atributos requeridos de su categoría. Verificar precio, imágenes, variante, estado y stock según el modelo aplicable a la cuenta.
5. Implementar bandeja persistente de notificaciones recibidas. Responder rápido tras guardar el evento y consultar el recurso autorizado de ML; validar cuenta, aplicación y recurso esperado. No seguir URLs arbitrarias recibidas en un webhook.
6. Importar pedidos con clave única por canal e identificador externo. Aplicar la transición de inventario una vez; posteriores actualizaciones modifican el pedido según su estado, sin registrar una segunda venta.
7. Crear una cola de salida en Postgres en la misma transacción del cambio de inventario. Un job toma trabajos con bloqueo/lease y publica la disponibilidad vigente, evitando que trabajos antiguos restauren cantidades obsoletas.
8. Implementar reintentos con espera creciente, manejo de límites de API y errores permanentes, historial y recuperación manual. No depender de tareas en memoria después de responder HTTP.
9. Reconciliar periódicamente pedidos recientes, publicaciones y disponibilidad. Una actualización emitida por Garage99 y recibida de vuelta no debe generar otro ajuste de inventario.
10. Aplicar la política elegida para stock escaso, reservas web, colchón/cupos y desconexión de ML. La reasignación de cupos requiere reducir y confirmar el canal de origen antes de aumentarlos en el destino.
11. Hacer la carga inicial mediante conteo y un punto de corte de pedidos. Conciliar ventas/reservas en curso antes de publicar el nuevo saldo; no importar todo el historial como ventas nuevas.
12. Probar venta ML, venta web con actualización de ML, cancelación, devolución, notificación duplicada, token expirado, API caída y recuperación. Si llega una venta externa sin stock suficiente, registrar el pedido como excepción y alertar; no descartarlo ni fabricar stock.

**Entregables:** conector, jobs, publicaciones vinculadas y panel de estado. **Salida:** pedidos y cantidades se concilian con evidencia; existe un procedimiento para desfases. **Hito 4: dos canales integrados.**

### Fase 10 — Validación integral y preparación productiva

1. Ejecutar recorridos completos en móvil/escritorio: compra, agotado, pago fallido, cancelación, devolución y acceso de administración.
2. Probar compras concurrentes web/web y web/ML; documentar el alcance de la política de cupos o el riesgo residual del stock compartido.
3. Probar recuperación tras fallos de webhooks/jobs y verificar reintentos sin duplicación.
4. Crear entorno productivo separado; revisar variables, dominio, HTTPS, URLs OAuth/webhooks y políticas de Storage.
5. Validar copia y restauración de DB en un entorno aislado y estrategia separada para imágenes. Revisar retención y capacidad del plan contratado.
6. Configurar alertas de errores de pago, sincronización atrasada, trabajos fallidos y diferencias de inventario. Metas iniciales propuestas: cero discrepancias pendientes al abrir y revisar cualquier sincronización demorada más de 5 minutos; ajustar tras medir el piloto.
7. Medir consultas de catálogo con datos representativos, revisar índices y límites de funciones/conexiones. Acordar presupuesto mensual y alertas de consumo.
8. Dejar guía para desplegar, aplicar migraciones, desactivar checkout, detener sincronización y recuperar operación. Volver a una versión web anterior no revierte por sí solo los movimientos ya registrados.

**Entregables:** reporte de aceptación y guía operativa. **Salida:** sin fallos críticos de stock, pagos o permisos; responsable de operación y proceso de incidencias definidos.

### Fase 11 — Piloto y lanzamiento

1. Cargar catálogo inicial acotado y verificar stock físico, precios, publicaciones vinculadas y pedidos pendientes.
2. Activar producción para un grupo/catálogo controlado. Ejecutar una compra real de bajo monto y comprobar pago, pedido, stock y entrega/documento comercial aplicable.
3. Verificar una venta por ML y su reflejo en Garage99. Confirmar que no hay doble descuento.
4. Revisar diariamente durante la primera semana pagos, inventario, reservas vencidas y sincronización; conciliar antes de ampliar catálogo.
5. Corregir incidencias y ampliar gradualmente. Actualizar contexto, memoria y backlog posterior a v1.

**Salida:** pedido real completo en web y venta ML correctamente contabilizada, sin corrección manual en el recorrido normal. Mantener procedimiento de atención para excepciones externas.

## 4. Modelo por incremento

| Cuándo | Entidades | Propósito |
|---|---|---|
| Fase 2 | `products`, `product_variants` | Catálogo y unidad vendible |
| Fase 2 | categorías, marcas, motos y `product_fitments` | Clasificación y compatibilidad |
| Fase 2 | `inventory`, `inventory_movements` | Saldo y trazabilidad |
| Fase 3 | `orders`, `order_items`, `inventory_reservations` | Pedidos y compromisos de stock |
| Fases 3–7 | proveedores, compras, recepciones, mostrador y posventa | Abastecimiento y operación ampliada |
| Fases 4–7 | Perfil/rol administrativo protegido | Autorización de clientes y equipo |
| Fase 8 | `payment_attempts`, eventos de proveedor | Estado y conciliación de pagos |
| Fase 9 | `ml_connections`, `ml_listings` | Cuenta y correspondencia de publicaciones |
| Fase 9 | Eventos entrantes, trabajos de salida, `ml_sync_log` | Procesamiento duradero y diagnóstico |

Los nombres están adoptados en el esquema aplicado. La integración funcional se incorporará por fases; los tokens y eventos sensibles quedan fuera del acceso público.

## 5. Demostración obligatoria de base de datos

La siguiente secuencia usa una variante con saldo inicial cero. Cada movimiento usa una clave nueva salvo el caso de repetición indicado.

| Paso | Operación | `on_hand` | `reserved` | `available` |
|---|---|---:|---:|---:|
| 1 | Entrada de 10 | 10 | 0 | 10 |
| 2 | Reservar 2 para pedido A | 10 | 2 | 8 |
| 3 | Confirmar venta de A | 8 | 0 | 8 |
| 4 | Repetir confirmación de A con la misma clave | 8 | 0 | 8 |
| 5 | Reservar 3 para pedido B | 8 | 3 | 5 |
| 6 | Cancelar B y liberar reserva | 8 | 0 | 8 |
| 7 | Devolución apta para venta de 1 unidad de A | 9 | 0 | 9 |
| 8 | Ajuste de −1 con motivo | 8 | 0 | 8 |
| 9 | Intentar reservar 9 | 8 | 0 | 8 |

En el paso 9 la operación se rechaza completamente. Pruebas adicionales:

- Dos sesiones intentan reservar la última unidad: solo una tiene éxito.
- Pedido con dos variantes y una agotada: no se reserva ninguna línea.
- Reserva vence: se libera una sola vez; concurrencia entre expiración y pago no duplica efectos.
- Un ajuste no puede dejar `on_hand < reserved` ni cantidades negativas. Un faltante físico sobre unidades comprometidas abre una incidencia que requiere resolver reservas/pedidos.
- Una devolución no puede exceder la cantidad vendida menos lo ya devuelto.
- Suma de movimientos = saldo; suma de reservas activas = reservado.
- Cliente A no puede ver/cancelar pedido de B; visitante no puede ajustar stock ni ejecutar funciones administrativas.
- Un error a mitad de la operación revierte saldo, movimiento, reserva y pedido juntos.

Entregar consultas reutilizables para listar productos activos, localizar SKU, ver disponibilidad, detectar stock bajo, revisar movimientos, listar pedidos/reservas y encontrar discrepancias. Los comandos de escritura se documentarán con las firmas SQL reales cuando existan; no son consultas ejecutadas en esta planificación.

## 6. Primeras sesiones de trabajo

| Sesión | Trabajo | Evidencia visible |
|---|---|---|
| 1 | Revisar acceso Supabase, entorno e insumos | Proyecto identificado y primera consulta |
| 2 | Preparar migraciones y catálogo básico | Productos/variantes consultables |
| 3 | Crear inventario y función de entrada | Entrada de 10 unidades auditada |
| 4 | Agregar reservas y ventas | Reserva y descuento correctos |
| 5 | Agregar cancelación, devolución y ajuste | Secuencia completa de movimientos |
| 6 | Probar concurrencia, permisos y reproducción | Informe para cerrar hito DB |

Son sesiones de resultado; pueden requerir varios bloques de 2–3 horas. El bloque completo de preparación y DB (fases 0–4) estima **27–43 horas**, aproximadamente **3–9 semanas** con la disponibilidad indicada. El primer acceso y consulta llega antes de completar ese hito.

## 7. Decisiones pendientes y fecha límite

| Decisión o insumo | Propuesta / dato requerido | Resolver antes de |
|---|---|---|
| Supabase disponible | Proyecto existente o nuevo entorno de pruebas | Fase 1 |
| Catálogo y stock inicial | 5–10 productos de muestra; conteo para producción | Fase 2 / fase 11 |
| País, moneda y modalidades ML | Chile/CLP confirmados; verificar Full y variantes de la cuenta | Cierre fase 0 |
| Política de reservas | Inicio de checkout; 15 min confirmados para el diseño | Fase 3; ajustar en 8 si el proveedor lo requiere |
| Compra con cuenta o invitado | Cuenta inicialmente; decidir impacto en conversión | Fase 6 |
| Identidad visual | Logo, colores, fotos y referencias | Fase 6 |
| Pasarela y métodos de pago | Comparación concreta por habilitación, costo y flujo | Fase 8 |
| Despacho y costo | Un método inicial operativo | Fase 8 |
| Boleta/factura | Definir proceso con responsable contable | Primera venta real |
| Política de última unidad | Stock compartido con margen; medir si algún SKU requiere cupos exclusivos | Fase 9 |
| Volumen SKU/pedidos y presupuesto | Dimensionar planes, frecuencia y tiempo de jobs | Fases 9–10 |
| Operación de excepciones | Responsable y canal de alerta | Piloto |

Estas decisiones no impiden preparar el esquema y trabajar con datos de ejemplo, salvo las señaladas para las primeras fases. No se han contratado servicios ni activado integraciones.

## 8. Restricciones técnicas verificadas y referencias

- Supabase permite versionar cambios con migraciones y reconstruir el entorno de desarrollo. Se utilizará este flujo para no depender de cambios manuales sin registro. [Migraciones de Supabase](https://supabase.com/docs/guides/local-development/database-migrations).
- RLS debe acompañarse de permisos y pruebas con los roles reales de la aplicación. No basta con probar desde el propietario de la DB. [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security).
- Vercel Hobby se limita a uso personal no comercial; para esta tienda hay que presupuestar un plan habilitado para uso comercial. [Plan Hobby](https://vercel.com/docs/plans/hobby).
- El cron de Hobby solo permite ejecución diaria; Pro admite frecuencia por minuto. Dimensionar jobs y tiempos máximos antes de implementar reconciliación frecuente y vencimientos. [Límites de Cron](https://vercel.com/docs/cron-jobs/usage-and-pricing).
- Las notificaciones `orders_v2` de ML permiten conocer cambios de órdenes y consultar el recurso correspondiente. Su configuración y los recursos de stock aplicables a la cuenta chilena deben verificarse al implementar. [Notificaciones de Mercado Libre](https://developers.mercadolibre.com.ar/es_ar/productos-recibe-notificaciones).

Consultadas el 2026-09-05. El resto de las reglas y estimaciones de este documento son propuestas de diseño para Garage99. Revalidar condiciones del proveedor antes de contratar o implementar cada integración.

## 9. Seguimiento

Al cerrar cada fase: registrar qué se hizo, evidencia de aceptación, decisiones nuevas, pendientes y horas consumidas. Actualizar este plan, `CONTEXT.md` cuando cambie el alcance y `memory-general.md` con aprendizajes. Mantener `contexto-proyecto.md` como índice hacia el contexto rector para evitar versiones contradictorias.
