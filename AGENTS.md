# Garage99 — Retomar y mantener contexto

Antes de explorar el repositorio, leer `contexto-proyecto.md` y la sección
«Protocolo de continuidad» al inicio de `memory-general.md`.

1. Verificar vigencia: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Update-ProjectGraph.ps1 -Check`.
2. Leer `graphify-out/RESUMEN.md`; consultar el tema con `graphify query "<tema>" --budget 1200`.
3. Abrir únicamente las fuentes relevantes indicadas por el grafo y verificar en ellas cualquier cambio. No cargar de entrada el JSON completo ni todo el historial.
4. Si el grafo está desactualizado, revisar los archivos cambiados, actualizar `docs/graph-context.json` cuando cambien decisiones/estado/relaciones, y ejecutar `scripts/Update-ProjectGraph.ps1` sin `-Check`.
5. Después de cambios relevantes y antes de cerrar una sesión, actualizar contexto/memoria, regenerar el grafo y comprobar su vigencia. Si no se pudo, dejar explícitamente pendiente su actualización.

El grafo es un índice derivado, no sustituye al código, al contexto rector ni a la
evidencia de pruebas. Distinguir siempre implementado/verificado, planificado y
pendiente de decidir. No indexar `.env*`, contraseñas, claves o `artifacts/`.

Guía: `docs/GRAFO-PROYECTO.md`. No reemplazar el flujo completo por `graphify update`
sin revisar la capa semántica: ese comando actualiza principalmente el código.
