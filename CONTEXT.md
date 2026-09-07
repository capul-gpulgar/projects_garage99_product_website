# Garage99 — Contexto del proyecto

> Documento vivo. Define **qué** se construye y **por qué**. El detalle de implementación
> vive en el código; aquí solo quedan decisiones, supuestos y pendientes.

Última actualización: 2026-09-06

---

## 1. Objetivo

Construir una operación comercial propia para **Garage99** que permita vender por
web y mostrador, con **stock centralizado** y **sincronizado con Mercado Libre**,
evitando la sobreventa (vender el mismo producto en dos canales) y la carga manual
de inventario.

La web, el mostrador y Mercado Libre operan sobre **una sola fuente de verdad de stock**.

## 2. Alcance

**Dentro del alcance (v1)**
- Catálogo de productos (listado, detalle, búsqueda/filtros básicos).
- Compatibilidad de repuestos por marca, modelo, año y motor.
- Carrito y checkout con pago online.
- Gestión de stock centralizada en base de datos.
- Panel de administración mínimo: productos, stock, pedidos.
- Compras, recepciones y ventas de mostrador.
- Devoluciones y garantías.
- Integración con Mercado Libre: publicación/actualización de productos y
  sincronización bidireccional de stock y órdenes.

**Fuera del alcance (v1)**
- App móvil nativa.
- Multi-bodega / multi-moneda.
- Gestión de reparaciones de taller, agenda y asignación de mecánicos.
- Kits armables que consumen componentes; los kits cerrados se modelan como SKU
  independientes.
- Programa de fidelización, cupones avanzados, suscripciones.
- ERP o contabilidad (se integra después si hace falta).

## 3. Stack y arquitectura

| Capa | Decisión |
|---|---|
| Frontend + hosting | **Next.js en Vercel** (App Router, SSR/ISR para SEO del catálogo) |
| Backend / API | **Route Handlers de Next.js** en Vercel (sin servidor aparte en v1) |
| Base de datos | **Supabase (Postgres)** — fuente de verdad de productos, stock, pedidos |
| Auth | Supabase Auth (clientes y administradores; roles vía RLS) |
| Archivos | Supabase Storage (imágenes de producto) |
| Jobs / sincronización | Vercel Cron + webhooks de Mercado Libre |
| Pagos | *Por definir* (ver §6) |
| Marketplace | **API de Mercado Libre** (OAuth, items, orders, notifications) |

Flujo base:

```
Cliente ──► Next.js (Vercel) ──► Supabase (Postgres + RLS)
                                      ▲
                                      │  sync stock / órdenes
                                      ▼
                            API + webhooks Mercado Libre
```

## 4. Modelo de datos (implementado y validado en desarrollo)

- `products` — SKU, nombre, descripción, precio, estado, imágenes.
- `product_variants` — talla/color/etc.; **el stock vive a nivel de variante**.
- `inventory` — cantidad disponible, reservada; una fila por variante.
- `inventory_movements` — log inmutable de cada cambio de stock (venta, devolución,
  ajuste manual, sync ML). Permite auditar diferencias entre canales.
- `orders` / `order_items` — pedido, canal de origen (`web` | `mercadolibre`), estado.
- `ml_listings` — mapeo `variant_id` ↔ `item_id` de Mercado Libre.
- `ml_sync_log` — resultado de cada sincronización (para depurar desfases).

El diseño completo, con compatibilidad de motocicletas, compras, mostrador,
devoluciones, garantías, pagos, entregas, integraciones y auditoría, está en
[docs/MODELO-DATOS.md](docs/MODELO-DATOS.md). Las convenciones están en
[docs/ESTANDARES-DATOS.md](docs/ESTANDARES-DATOS.md). Las tablas de negocio se aplicaron mediante migraciones versionadas en el proyecto de
desarrollo. `public.connection_check` permanece como tabla técnica de conectividad.
La [evidencia del modelo](docs/VALIDACION-MODELO-DB-2026-09-06.md) registra la aplicación, la validación transaccional y los límites pendientes.
**Regla clave:** el stock nunca se edita directo desde la aplicación; saldo y
movimiento se actualizan en una misma transacción mediante operaciones controladas.
El disponible se deriva del saldo y las reservas. El historial permite auditar;
evitar carreras locales requiere validación atómica e idempotencia. La sincronización
con Mercado Libre tiene latencia y requiere una política explícita de stock por canal.

## 5. Decisiones tomadas

1. **Vercel + Supabase** en vez de Shopify: control total del stock, costo variable
   bajo al inicio y libertad para integrar Mercado Libre a medida.
   *(El README actual menciona Shopify; queda obsoleto y debe actualizarse.)*
2. **Stock centralizado en Supabase**, no en Mercado Libre. ML es un canal, no la
   fuente de verdad.
3. **Sin backend separado en v1**: todo en Next.js sobre Vercel. Si la sincronización
   crece, se mueve a workers dedicados.

## 6. Decisiones confirmadas y pendientes

- [ ] **Pasarela de pago**: Mercado Pago (coherente con ML) vs. Transbank/Webpay
      (estándar en Chile) vs. Stripe. Impacta checkout y conciliación.
- [ ] **Despacho**: retiro, courier propio o Mercado Envíos.
- [ ] **Facturación / boleta electrónica** (SII): ¿v1 o después?
- [x] Una ubicación inicial, operación en Chile y CLP.
- [x] Compatibilidad por marca, modelo, año y motor.
- [x] Unidades y kits cerrados con stock propio; kits armables fuera del primer incremento.
- [x] Stock compartido entre web, mostrador y Mercado Libre con margen configurable; propuesta inicial de una unidad de seguridad por SKU.
- [x] Reservar al iniciar checkout durante 15 minutos; el carrito no reserva.
- [x] Incluir ventas de mostrador, devoluciones y garantías; taller de reparaciones queda fuera.
- [ ] Estrategia ante desfase de stock: medir riesgo residual y ajustar margen/cupos antes del piloto.
- [ ] Volumen esperado de SKUs y pedidos/mes (define si Vercel Cron alcanza).

## 7. Riesgos

- **Sobreventa**: latencia entre venta en ML y actualización en la web. Mitigación:
  webhooks + colchón de seguridad de stock + reconciliación periódica.
- **Rate limits y cambios de la API de Mercado Libre**: aislar la integración tras
  una capa propia para no acoplar el dominio.
- **Tokens OAuth de ML**: expiran; requiere refresh automático y almacenamiento seguro.
- **Proyecto personal con 5–10 h/semana**: priorizar v1 delgada y vendible antes que
  automatización completa.

## 8. Criterio de éxito v1

Un pedido real puede completarse de punta a punta en la web (pago incluido), y el
stock se descuenta correctamente tanto si la venta ocurre en la web como en
Mercado Libre, sin intervención manual.

## 9. Secuencia de ejecución acordada

Primero montar Supabase/Postgres y validar consultas, entradas, ajustes, reservas,
ventas y cancelaciones sin interfaz. Después construir la API y el sitio conectado;
completar administración, pagos e integración con Mercado Libre antes del piloto.

El detalle de fases, dependencias, pruebas y estimaciones está en
[PLAN-IMPLEMENTACION.md](PLAN-IMPLEMENTACION.md). Las propuestas aún no confirmadas
se distinguen de las decisiones tomadas. Estado actual: hito de arranque DB
y modelo operacional completados en el proyecto `bxhavpyvoijawzqiaspk`, usando el Session pooler
`us-east-1` proporcionado por el usuario. Migraciones comerciales aplicadas;
validaci?n de esquema, RLS, reservas, idempotencia, venta y permisos en PASS.
[Evidencia del arranque](docs/VALIDACION-DB-2026-09-05.md) y
[evidencia del modelo](docs/VALIDACION-MODELO-DB-2026-09-06.md).
[Instrucciones](docs/SUPABASE-ARRANQUE.md).
