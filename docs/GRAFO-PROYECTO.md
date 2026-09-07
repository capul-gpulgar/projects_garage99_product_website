# Grafo de conocimiento de Garage99

Graphify combina extracción estructural del código con una capa semántica revisada
de contexto, decisiones, estado y próximos pasos. El grafo se genera localmente;
no necesita acceder a Supabase ni leer credenciales.

## Retomar con menos contexto

1. Leer `contexto-proyecto.md` y el protocolo al inicio de `memory-general.md`.
2. Comprobar vigencia:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Update-ProjectGraph.ps1 -Check
```

3. Leer `graphify-out/RESUMEN.md` y buscar el tema:

```powershell
graphify query "productos variantes inventario" --budget 1200
graphify query "Supabase RLS SQL REST" --budget 1200
graphify explain "docs_supabase_arranque_connection_check"
```

4. Abrir solo las fuentes que sustenten la respuesta o el cambio. No cargar el
JSON completo ni el historial de memoria por defecto. El grafo es un índice
derivado; las fuentes y la evidencia verificable prevalecen.

## Actualizar

- Cambios solo de código: ejecutar el comando siguiente sin opciones.
- Cambios de documentación, decisiones o estado: revisar y ajustar
  `docs/graph-context.json`, conservando procedencia y estados; ejecutar con
  `-ReviewedDocs`. Ese indicador confirma revisión humana/del agente y no hace
  extracción semántica automática por sí mismo.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Update-ProjectGraph.ps1 -ReviewedDocs
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Update-ProjectGraph.ps1 -Check
```

El actualizador extrae código con Graphify, incorpora la capa semántica, agrupa
comunidades y regenera JSON, informe, resumen y HTML. Detecta archivos nuevos,
cambiados y eliminados por SHA-256. Si reduce el número de nodos, requiere revisar
que la reducción sea legítima antes de usar `-AllowShrink`.

Actualizar primero las fuentes y memoria; regenerar al final. Si cambia una fuente
después de generar, el control debe señalar `STALE`. No basta con `graphify update`:
la documentación requiere revisar también la capa semántica.

No se instala un proceso permanente ni un hook Git. La actualización al retomar
y cerrar se exige mediante `AGENTS.md` y el protocolo permanente de memoria.

## Archivos

| Archivo | Uso |
|---|---|
| `graphify-out/graph.html` | Grafo interactivo de Graphify |
| `graphify-out/graph.json` | Datos para consultas y recorridos |
| `graphify-out/RESUMEN.md` | Entrada breve para retomar |
| `graphify-out/GRAPH_REPORT.md` | Comunidades, nodos centrales y auditoría |
| `graphify-out/source-manifest.json` | Huellas de fuentes para detectar desfases |
| `docs/graph-context.json` | Entidades y relaciones semánticas revisadas |

Se excluyen `.env*`, secretos, certificados, dependencias, `.git`, `artifacts/` y
salidas del propio grafo. Los nodos con estado planificado no describen funciones
ya implementadas. La prueba dummy sugerida en conversación no se considera
ejecutada sin evidencia.

## Herramienta y límites

Instalación detectada: Graphify 0.9.53 mediante `uv tool`, con `tree-sitter-sql`
0.3.11 añadido para analizar las migraciones. El wrapper usa su Python aislado;
no depende del Python usado para conectarse a la DB.

```powershell
uv tool install 'graphifyy[sql]==0.9.53'
```

La primera extracción semántica la realiza el asistente en esta sesión. Sus tokens
no están disponibles como una medida independiente; no afirmar costo cero ni un
porcentaje garantizado de ahorro. El beneficio esperado proviene de consultas
acotadas y referencias a archivos, evitando releer todo el proyecto. El HTML de
Graphify puede necesitar internet para cargar sus bibliotecas visuales.

`--budget` es un objetivo de tamaño de respuesta: esta versión puede superarlo
ligeramente para conservar relaciones completas. Si devuelve demasiado contexto,
acotar el tema o usar `graphify explain` con un identificador exacto.

Se omiten del grafo las importaciones genéricas de la biblioteca estándar de
Python. Se conservan las relaciones del proyecto y los enlaces explícitos entre
documentos y archivos de código. `graph-health.json` audita integridad; la dirección
de las relaciones se conserva.

Validaciones realizadas: consultas sobre inventario y Supabase, referencias de
nodos sin destinos inexistentes, ausencia de fuentes privadas y detección de un
documento nuevo como `STALE`, volviendo a `CURRENT` al retirarlo. El resumen inicial
tiene unas 250 palabras, frente al corpus completo de más de 12.000 palabras.
