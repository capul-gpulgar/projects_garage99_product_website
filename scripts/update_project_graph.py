"""Rebuild Garage99 with Graphify AST + reviewed semantic context; no external LLM.

Run in the installed Graphify interpreter via Update-ProjectGraph.ps1.
--check reads only and detects changed/deleted/new corpus and build inputs.
"""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "graphify-out"
SEMANTIC = ROOT / "docs/graph-context.json"
MANIFEST = OUT / "source-manifest.json"


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def relative(path):
    resolved = Path(path).resolve()
    return resolved.relative_to(ROOT).as_posix()


def fingerprint(paths):
    return {relative(p): hashlib.sha256(Path(p).read_bytes()).hexdigest()
            for p in sorted(set(paths)) if Path(p).is_file()}


def normalized_semantics(raw):
    for kind in ("nodes", "edges", "hyperedges"):
        for item in raw.get(kind, []):
            source = Path(item["source_file"])
            if not source.is_absolute():
                source = ROOT / source
            name = relative(source)
            if not source.is_file() or name.startswith(("artifacts/", "graphify-out/")) or source.name.startswith(".env"):
                raise ValueError("Invalid semantic source: " + name)
            item["source_file"] = name
            item["_origin"] = "semantic"
    return raw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--reviewed-docs", action="store_true")
    parser.add_argument("--allow-shrink", action="store_true")
    args = parser.parse_args()
    from graphify.detect import detect, save_manifest

    detection = detect(ROOT)
    corpus = [Path(p) for group in detection["files"].values() for p in group]
    controls = [SEMANTIC, ROOT / ".graphifyignore", ROOT / ".gitignore"]
    hashes = fingerprint(corpus + controls)
    previous = read_json(MANIFEST) if MANIFEST.exists() else {}
    prior_hashes = previous.get("sources", {})
    changed = sorted(k for k in hashes.keys() | prior_hashes.keys() if hashes.get(k) != prior_hashes.get(k))
    outputs = ["graph.json", "graph.html", "GRAPH_REPORT.md", "RESUMEN.md"]
    missing = [p for p in outputs if not (OUT / p).is_file()]
    if args.check:
        if changed or missing:
            print("STALE: graph requires review/update.")
            for name in changed:
                print("  source: " + name)
            for name in missing:
                print("  missing output: " + name)
            return 1
        print("CURRENT: graph matches all tracked corpus/build inputs.")
        return 0

    docs = {relative(p) for p in detection["files"].get("document", [])}
    changed_docs = docs.intersection(changed) | {p for p in changed if p.endswith(".md")}
    if previous and changed_docs and not args.reviewed_docs:
        print("Review docs/graph-context.json against the changed documents first:")
        for name in sorted(changed_docs):
            print("  " + name)
        print("Then rerun with -ReviewedDocs (even if no semantic changes were needed).")
        return 2
    if not SEMANTIC.is_file():
        raise ValueError("Missing reviewed semantic extraction: docs/graph-context.json")

    from graphify.extract import extract
    from graphify.build import build_from_json
    from graphify.cluster import cluster, score_all
    from graphify.analyze import god_nodes, surprising_connections, suggest_questions
    from graphify.report import generate
    from graphify.export import to_json
    from graphify.diagnostics import diagnose_extraction

    OUT.mkdir(exist_ok=True)
    (OUT / ".graphify_python").write_text(sys.executable, encoding="utf-8")
    (OUT / ".graphify_root").write_text(str(ROOT), encoding="utf-8")
    ast = extract([Path(p) for p in detection["files"].get("code", [])], cache_root=ROOT)
    semantic = normalized_semantics(read_json(SEMANTIC))
    # Retain the reviewed semantic source in portable repo-relative form.
    write_json(SEMANTIC, semantic)
    nodes = {n["id"]: n for n in ast["nodes"]}
    nodes.update({n["id"]: n for n in semantic["nodes"]})
    edges = ast["edges"] + semantic["edges"]
    # Graphify emits standard-library import endpoints without local nodes.
    # Omit those generic dependencies; retain all project/semantic relationships.
    stdlib_edges = [e for e in edges if e.get("target") not in nodes
                    and e.get("relation") in ("imports", "imports_from")
                    and e.get("target", "").split(".")[0] in sys.stdlib_module_names]
    edges = [e for e in edges if e not in stdlib_edges]

    # Explicit file membership makes unsupported symbols/doc-only files retrievable.
    file_nodes = {}
    for path in corpus:
        name = relative(path)
        existing_doc = next((n for n in semantic["nodes"] if n["file_type"] == "document" and n["source_file"] == name), None)
        if existing_doc:
            file_id = existing_doc["id"]
        else:
            file_id = "corpus_" + re.sub(r"[^a-z0-9]", "_", name.lower())
            nodes[file_id] = {"id": file_id, "label": name, "file_type": "document" if path.suffix == ".md" else "code",
                              "source_file": name, "source_location": None, "_origin": "semantic"}
        file_nodes[name] = file_id
        for node in list(nodes.values()):
            source = node.get("source_file")
            if node["id"] == file_id or not source:
                continue
            source_path = Path(source)
            origin = relative(source_path) if source_path.is_absolute() else source_path.as_posix()
            if origin == name:
                if any(e.get("source") == file_id and e.get("target") == node["id"] for e in edges):
                    continue
                edges.append({"source": file_id, "target": node["id"], "relation": "documents" if path.suffix == ".md" else "defines",
                              "confidence": "EXTRACTED", "confidence_score": 1.0, "weight": 1.0,
                              "source_file": name, "source_location": None})

    # Cross-file navigation from literal Markdown links and inline file paths.
    pairs = {(e["source"], e["target"]) for e in edges}
    for path in corpus:
        if path.suffix != ".md":
            continue
        source_name = relative(path)
        for line_no, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
            refs = re.findall(r"\[[^\]]+\]\(([^)]+)\)", line)
            refs += re.findall(r"`([^`\n]+\.(?:py|ps1|sql|md))`", line)
            for ref in refs:
                if "://" in ref:
                    continue
                for base in (path.parent, ROOT):
                    target_path = (base / ref.split("#")[0]).resolve()
                    if not target_path.is_relative_to(ROOT):
                        continue
                    target_name = relative(target_path)
                    if target_name not in file_nodes or target_name == source_name:
                        continue
                    pair = (file_nodes[source_name], file_nodes[target_name])
                    if pair not in pairs:
                        edges.append({"source": pair[0], "target": pair[1], "relation": "references",
                                      "confidence": "EXTRACTED", "confidence_score": 1.0, "weight": 1.0,
                                      "source_file": source_name, "source_location": "L" + str(line_no)})
                        pairs.add(pair)
                    break

    # SQL extraction can emit a relationship to a table/view identifier without
    # a standalone AST node for that relation target. Materialize a lightweight
    # database reference node so the graph remains navigable and health checks do
    # not leave dangling endpoints. These are extracted references, not evidence
    # that the remote object exists outside the migration source.
    missing_targets = [e for e in edges if e.get("target") not in nodes]
    for edge in missing_targets:
        target = edge.get("target")
        if not target:
            continue
        nodes[target] = {
            "id": target,
            "label": target,
            "file_type": "database_reference",
            "source_file": edge.get("source_file"),
            "source_location": edge.get("source_location"),
            "status": "planned",
            "description": "Referencia SQL extraída; existencia remota se valida al aplicar la migración.",
            "_origin": "extracted_reference",
        }

    extraction = {"nodes": list(nodes.values()), "edges": edges,
                  "hyperedges": semantic.get("hyperedges", []), "input_tokens": 0, "output_tokens": 0}
    health = diagnose_extraction(extraction, directed=True, root=str(ROOT))
    health["omitted_python_stdlib_import_edges"] = len(stdlib_edges)
    if health.get("dangling_endpoint_edges", 0) or health.get("missing_endpoint_edges", 0):
        raise ValueError("Graph extraction contains missing endpoints; existing graph preserved")
    graph = build_from_json(extraction, directed=True, root=ROOT)
    if not graph.number_of_nodes():
        raise ValueError("Empty extraction; existing graph preserved")
    status_tags = {"planned": "PLAN", "decision_pending": "POR DECIDIR", "implemented_and_verified": "VERIFICADO"}
    for _, node in graph.nodes(data=True):
        tag = status_tags.get(node.get("status"))
        if tag:
            node["label"] = "[" + tag + "] " + node["label"]
    communities = cluster(graph)
    cohesion = score_all(graph, communities)
    labels = {}
    for cid, members in communities.items():
        concepts = [n for n in members if graph.nodes[n].get("file_type") in ("concept", "rationale")]
        candidates = concepts or members
        central = max(candidates, key=lambda n: graph.degree(n))
        label = graph.nodes[central].get("label", "Grupo " + str(cid))
        if not concepts:
            sources = Counter(graph.nodes[n].get("source_file", "") for n in members)
            common_source = sources.most_common(1)[0][0]
            label = {"scripts/update_project_graph.py": "Actualización del grafo",
                     "scripts/validate_supabase_sql.py": "Conexión y validación SQL",
                     "scripts/Test-SupabaseConnection.ps1": "Validación REST",
                     "tests/Test-ConnectionValidator.ps1": "Pruebas del validador"}.get(common_source, Path(common_source).stem)
        labels[cid] = label
    if not to_json(graph, communities, str(OUT / "graph.json"), force=args.allow_shrink, community_labels=labels):
        raise ValueError("Graph shrink refused; verify deleted sources before using -AllowShrink")
    gods = god_nodes(graph)
    surprises = surprising_connections(graph, communities)
    questions = suggest_questions(graph, communities, labels)
    report = generate(graph, communities, cohesion, labels, gods, surprises, detection,
                      {"input": 0, "output": 0}, str(ROOT), suggested_questions=questions)
    report = report.replace("Token cost: 0 input · 0 output", "Token cost: unavailable (semantic extraction in the assistant session)")
    report += "\n## Token accounting and freshness\n\nSemantic token usage is not available from the session tools. No external LLM API was called by this build. Source hashes: source-manifest.json. Python standard-library import edges are omitted to keep the graph focused on project code.\n"
    (OUT / "GRAPH_REPORT.md").write_text(report, encoding="utf-8")
    analysis = {"communities": communities, "cohesion": cohesion, "gods": gods, "surprises": surprises, "questions": questions}
    write_json(OUT / ".graphify_analysis.json", analysis)
    write_json(OUT / ".graphify_labels.json", labels)
    write_json(OUT / "graph-health.json", health)

    resume = ["# Garage99 — entrada breve al grafo", "", "Consultar este índice antes del historial completo. Verificar vigencia con `scripts/Update-ProjectGraph.ps1 -Check`.", "",
              "El grafo registra evidencia histórica; no consulta el estado remoto en tiempo real.", ""]
    for title, status, full_description in [("Verificado", "implemented_and_verified", False),
                                             ("Decisiones pendientes", "decision_pending", True)]:
        resume += ["## " + title, ""]
        for node in semantic["nodes"]:
            if node.get("status") != status:
                continue
            description = node.get("description", "") if full_description else ""
            resume.append("- " + node["label"] + (": " + description if description else ""))
        resume.append("")
    resume += ["## Próximo trabajo y alcance", ""]
    for node in semantic["nodes"]:
        if node["label"].startswith("Próximo hito"):
            resume += [node.get("description", node["label"]), ""]
    resume += ["El catálogo, inventario comercial, web, pagos y Mercado Libre siguen planificados. "
               "No confundir la prueba de conectividad con inventario listo para vender.", "",
               "Fuentes: `CONTEXT.md`, `PLAN-IMPLEMENTACION.md`, `docs/VALIDACION-DB-2026-09-05.md`. "
               "Protocolo y actualización: `AGENTS.md` y `docs/GRAFO-PROYECTO.md`.", ""]
    resume += ["## Consulta acotada", "", '`graphify query "productos variantes inventario" --budget 1200`', "",
               "Leer solo las fuentes relevantes antes de modificar. Los estados planificados no significan componentes implementados.", ""]
    (OUT / "RESUMEN.md").write_text("\n".join(resume), encoding="utf-8")
    # Export in a subprocess using the same installed environment, with no LLM.
    subprocess.run([sys.executable, "-m", "graphify", "export", "html"], cwd=ROOT, check=True)
    save_manifest(detection["files"], root=ROOT)
    manifest = {"built_at_utc": datetime.now(timezone.utc).isoformat(), "graphify_version": "0.9.53",
                "sources": fingerprint(corpus + controls), "nodes": graph.number_of_nodes(),
                "edges": graph.number_of_edges(), "communities": len(communities),
                "semantic_review": "assistant_reviewed", "token_usage": "unavailable"}
    write_json(MANIFEST, manifest)
    print(f"Graph ready: {graph.number_of_nodes()} nodes, {graph.number_of_edges()} edges, {len(communities)} communities")
    for field in ("self_loop_edges", "directed_same_endpoint_collapsed_edges"):
        if health.get(field, 0):
            print("Graph health note: " + field + "=" + str(health[field]))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, FileNotFoundError) as exc:
        print("Graph update failed: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
