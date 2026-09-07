# Graph Report - garage99_product_website  (2026-09-06)

## Corpus Check
- Corpus is ~27,698 words - fits in a single context window. You may not need a graph.

## Summary
- 128 nodes · 314 edges · 9 communities
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 11 edges (avg confidence: 0.95)
- Token cost: unavailable (semantic extraction in the assistant session)

## Community Hubs (Navigation)
- [PLAN] Garage99
- [PLAN] supabase_migrations_20260906000100_create_garage99_schema_app_customers
- Grafo Graphify del proyecto
- [VERIFICADO] Hito de arranque DB completo
- Rebuild Garage99 with Graphify AST + reviewed semantic context; no external…
- Apply Garage99 business migrations through the verified TLS pooler. The…
- Pruebas del validador
- Validación REST
- Run the Garage99 synthetic SQL checks via the verified TLS session pooler.…

## God Nodes (most connected - your core abstractions)
1. `CONTEXT: contexto rector` - 30 edges
2. `Plan de implementación` - 28 edges
3. `Memoria y protocolo permanente` - 24 edges
4. `README: entrada del repositorio` - 18 edges
5. `Contexto: índice de entrada` - 18 edges
6. `Evidencia DB del 2026-09-05` - 15 edges
7. `Guía de arranque Supabase` - 13 edges
8. `AGENTS: continuidad de Garage99` - 11 edges
9. `api.create_order()` - 9 edges
10. `Modelo de datos operacional` - 9 edges

## Surprising Connections (you probably didn't know these)
- `CONTEXT: contexto rector` --defines--> `Modelo de datos operacional`  [INFERRED]
  CONTEXT.md → docs/MODELO-DATOS.md
- `Modelo de datos operacional` --defines_next_implementation--> `[PLAN] Próximo hito: catálogo e inventario`  [INFERRED]
  docs/MODELO-DATOS.md → contexto-proyecto.md
- `Estándares de datos` --specifies--> `[PLAN] Operaciones atómicas de inventario`  [INFERRED]
  docs/ESTANDARES-DATOS.md → CONTEXT.md
- `Estándares de datos` --specifies--> `[PLAN] Idempotencia de operaciones`  [INFERRED]
  docs/ESTANDARES-DATOS.md → PLAN-IMPLEMENTACION.md
- `CONTEXT: contexto rector` --references--> `Estándares de datos`  [EXTRACTED]
  CONTEXT.md → docs/ESTANDARES-DATOS.md

## Import Cycles
- None detected.

## Communities (9 total, 0 thin omitted)

### Community 0 - "[PLAN] Garage99"
Cohesion: 0.13
Nodes (28): [PLAN] Vercel Cron y webhooks, [POR DECIDIR] Despacho por definir, CONTEXT: contexto rector, [POR DECIDIR] Boleta y facturación, [PLAN] Garage99, [PLAN] inventory: saldo central, [PLAN] inventory_movements: historial inmutable, [PLAN] Integración Mercado Libre (+20 more)

### Community 1 - "[PLAN] supabase_migrations_20260906000100_create_garage99_schema_app_customers"
Cohesion: 0.13
Nodes (25): app.ensure_inventory_row, app.prevent_price_overlap, api.adjust_inventory(), api.confirm_order_sale(), api.create_order(), api.expire_reservations(), api.receive_purchase(), api.register_return() (+17 more)

### Community 2 - "Grafo Graphify del proyecto"
Cohesion: 0.31
Nodes (12): Verificar y regenerar el grafo, Capa semántica docs/graph-context.json, AGENTS: continuidad de Garage99, Grafo Graphify del proyecto, Contexto: índice de entrada, Estándares de datos, Guía Graphify: consulta y regeneración, Modelo de datos operacional (+4 more)

### Community 3 - "[VERIFICADO] Hito de arranque DB completo"
Cohesion: 0.23
Nodes (12): [VERIFICADO] public.connection_check, Guía de arranque Supabase, [VERIFICADO] RLS y permisos de connection_check, Evidencia DB del 2026-09-05, [VERIFICADO] Hito de arranque DB completo, [VERIFICADO] REST público: lectura y permisos PASS, [VERIFICADO] Session pooler us-east-1, [VERIFICADO] SQL CRUD y ROLLBACK: PASS (+4 more)

### Community 4 - "Rebuild Garage99 with Graphify AST + reviewed semantic context; no external…"
Cohesion: 0.58
Nodes (8): Path, fingerprint(), main(), normalized_semantics(), Rebuild Garage99 with Graphify AST + reviewed semantic context; no external…, read_json(), relative(), write_json()

### Community 5 - "Apply Garage99 business migrations through the verified TLS pooler. The…"
Cohesion: 0.57
Nodes (5): Exception, main(), Apply Garage99 business migrations through the verified TLS pooler. The…, read_config(), sqlstate()

### Community 6 - "Pruebas del validador"
Cohesion: 0.57
Nodes (5): Assert-Throws(), Assert-True(), Invoke-Garage99Request(), Set-TestConfig(), Test-Case()

### Community 7 - "Validación REST"
Cohesion: 0.80
Nodes (4): Get-Garage99Snapshot(), Invoke-Garage99Request(), Invoke-Garage99Validation(), Read-Garage99Config()

### Community 8 - "Run the Garage99 synthetic SQL checks via the verified TLS session pooler.…"
Cohesion: 0.80
Nodes (3): main(), Run the Garage99 synthetic SQL checks via the verified TLS session pooler.…, read_config()

## Knowledge Gaps
- **4 isolated node(s):** `[PLAN] supabase_migrations_20260906000100_create_garage99_schema_app_staff_roles`, `[PLAN] supabase_migrations_20260906000100_create_garage99_schema_app_sales_channels`, `[PLAN] supabase_migrations_20260906000100_create_garage99_schema_app_product_variants`, `[PLAN] supabase_migrations_20260906000100_create_garage99_schema_app_order_items`
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 12 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CONTEXT: contexto rector` connect `[PLAN] Garage99` to `Grafo Graphify del proyecto`, `[VERIFICADO] Hito de arranque DB completo`?**
  _High betweenness centrality (0.021) - this node is a cross-community bridge._
- **Why does `Memoria y protocolo permanente` connect `Grafo Graphify del proyecto` to `[PLAN] Garage99`, `[VERIFICADO] Hito de arranque DB completo`, `Apply Garage99 business migrations through the verified TLS pooler. The…`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `Plan de implementación` connect `Grafo Graphify del proyecto` to `[PLAN] Garage99`, `[PLAN] supabase_migrations_20260906000100_create_garage99_schema_app_customers`, `[VERIFICADO] Hito de arranque DB completo`, `Apply Garage99 business migrations through the verified TLS pooler. The…`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `Contexto: índice de entrada` (e.g. with `Estándares de datos` and `Modelo de datos operacional`) actually correct?**
  _`Contexto: índice de entrada` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `[PLAN] supabase_migrations_20260906000100_create_garage99_schema_app_staff_roles`, `[PLAN] supabase_migrations_20260906000100_create_garage99_schema_app_sales_channels`, `[PLAN] supabase_migrations_20260906000100_create_garage99_schema_app_product_variants` to the rest of the system?**
  _4 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `[PLAN] Garage99` be split into smaller, more focused modules?**
  _Cohesion score 0.13227513227513227 - nodes in this community are weakly interconnected._
- **Should `[PLAN] supabase_migrations_20260906000100_create_garage99_schema_app_customers` be split into smaller, more focused modules?**
  _Cohesion score 0.13105413105413105 - nodes in this community are weakly interconnected._
## Token accounting and freshness

Semantic token usage is not available from the session tools. No external LLM API was called by this build. Source hashes: source-manifest.json. Python standard-library import edges are omitted to keep the graph focused on project code.
