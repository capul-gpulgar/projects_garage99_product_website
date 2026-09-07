"""Apply Garage99 business migrations through the verified TLS pooler.

The PostgreSQL password is read interactively or from stdin and is never written
to arguments, files, reports, or logs. Existing migrations are tracked in
app.schema_migrations; the technical connection_check migration is left alone.
"""

import argparse
import getpass
import hashlib
import json
import re
import ssl
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "artifacts/python-db"))


def read_config(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        name, separator, value = line.partition("=")
        if not separator or name.strip() in values:
            raise ValueError("Invalid or duplicate configuration field")
        values[name.strip()] = value.strip().strip("\"'")
    ref = values.get("SUPABASE_PROJECT_REF", "")
    host = values.get("SUPABASE_DB_HOST", "")
    if not re.fullmatch(r"[a-z0-9]{20}", ref):
        raise ValueError("Invalid project reference")
    if not re.fullmatch(r"aws-[0-9]+-[a-z0-9-]+\.pooler\.supabase\.com", host):
        raise ValueError("Expected a Supabase shared session pooler")
    if values.get("SUPABASE_DB_PORT") != "5432":
        raise ValueError("Expected session pooler port 5432")
    if values.get("SUPABASE_DB_USER") != "postgres." + ref:
        raise ValueError("Database user does not match project reference")
    if values.get("SUPABASE_DB_NAME") != "postgres":
        raise ValueError("Unexpected database")
    return values


def sqlstate(error: Exception) -> str | None:
    if error.args and isinstance(error.args[0], dict):
        value = error.args[0].get("C", "")
        return value if re.fullmatch(r"[A-Z0-9]{5}", value) else None
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--password-stdin", action="store_true")
    args = parser.parse_args()
    report: dict[str, object] = {
        "status": "FAIL",
        "scope": "garage99_business_migrations",
        "checked_at_utc": datetime.now(timezone.utc).isoformat(),
        "applied": [],
        "skipped": [],
    }
    connection = None
    try:
        from pg8000.native import Connection

        config = read_config(ROOT / ".env.local")
        report["project_ref"] = config["SUPABASE_PROJECT_REF"]
        tls_context = ssl.create_default_context()
        ca_file = ROOT / "artifacts/certificates/prod-ca-2021.crt"
        if ca_file.is_file():
            tls_context.load_verify_locations(cafile=str(ca_file))
            report["ca_sha256"] = hashlib.sha256(ca_file.read_bytes()).hexdigest()
        password = sys.stdin.readline().rstrip("\r\n") if args.password_stdin else getpass.getpass("PostgreSQL password (not saved): ")
        if not password:
            raise ValueError("Missing password")
        try:
            connection = Connection(
                user=config["SUPABASE_DB_USER"], password=password,
                host=config["SUPABASE_DB_HOST"], port=5432,
                database=config["SUPABASE_DB_NAME"], timeout=30,
                ssl_context=tls_context, application_name="garage99-migrations",
            )
        finally:
            password = None
        connection.run("set statement_timeout = '60s'")
        connection.run("set lock_timeout = '10s'")
        identity = connection.run("select current_database(), current_user")[0]
        report["database"] = identity[0]
        report["database_role"] = identity[1]
        migration_dir = ROOT / "supabase/migrations"
        migrations = sorted(migration_dir.glob("20260906*.sql"))
        if not migrations:
            raise RuntimeError("No business migrations found")
        has_tracking = connection.run("select to_regclass('app.schema_migrations')")[0][0]
        applied_versions: set[str] = set()
        if has_tracking:
            applied_versions = {row[0] for row in connection.run("select version from app.schema_migrations")}
        for migration in migrations:
            version = migration.name.split("_", 1)[0]
            if version in applied_versions:
                report["skipped"].append(version)
                continue
            connection.run(migration.read_text(encoding="utf-8"))
            report["applied"].append(version)
        report["status"] = "PASS"
    except Exception as error:
        report["error_type"] = type(error).__name__
        if sqlstate(error):
            report["sqlstate"] = sqlstate(error)
        print("Migration application failed; see sanitized report.")
    finally:
        if connection is not None:
            try:
                connection.run("rollback")
            except Exception:
                pass
            try:
                connection.close()
            except Exception:
                pass
        output = ROOT / "artifacts/garage99-migrations.json"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
