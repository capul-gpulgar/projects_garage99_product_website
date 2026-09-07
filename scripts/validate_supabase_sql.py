"""Run the Garage99 synthetic SQL checks via the verified TLS session pooler.

Password is read interactively or from stdin, never from arguments or files.
Install pg8000 into artifacts/python-db; no PostgreSQL server is required.
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


def read_config(path):
    values = {}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        name, separator, value = line.partition("=")
        if not separator or name.strip() in values:
            raise ValueError("Invalid or duplicate configuration field")
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        values[name.strip()] = value
    ref = values.get("SUPABASE_PROJECT_REF", "")
    host = values.get("SUPABASE_DB_HOST", "")
    if not re.fullmatch(r"[a-z0-9]{20}", ref):
        raise ValueError("Invalid project reference")
    if not re.fullmatch(r"aws-[0-9]+-[a-z0-9-]+\.pooler\.supabase\.com", host):
        raise ValueError("Expected a Supabase shared session pooler")
    if values.get("SUPABASE_DB_PORT") != "5432":
        raise ValueError("Expected session pooler port 5432")
    if values.get("SUPABASE_DB_USER") != "postgres." + ref:
        raise ValueError("Database user does not match the project reference")
    if values.get("SUPABASE_DB_NAME") != "postgres":
        raise ValueError("Unexpected database")
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--password-stdin", action="store_true")
    parser.add_argument("--apply-migration", action="store_true",
                        help="Create the synthetic probe table only if absent")
    args = parser.parse_args()
    report = {"status": "FAIL", "scope": "live_supabase_postgres_sql",
              "checked_at_utc": datetime.now(timezone.utc).isoformat()}
    connection = None
    stage = "configuration"
    try:
        from pg8000.native import Connection

        config = read_config(ROOT / ".env.local")
        report["project_ref"] = config["SUPABASE_PROJECT_REF"]
        tls_context = ssl.create_default_context()
        ca_file = ROOT / "artifacts/certificates/prod-ca-2021.crt"
        if ca_file.is_file():
            tls_context.load_verify_locations(cafile=str(ca_file))
            report["ca_sha256"] = hashlib.sha256(ca_file.read_bytes()).hexdigest()
        stage = "authentication"
        if args.password_stdin:
            print("Waiting for database password on stdin (not logged).", flush=True)
            password = sys.stdin.readline().rstrip("\r\n")
        else:
            password = getpass.getpass("PostgreSQL password (not saved): ")
        if not password:
            raise ValueError("Missing password")
        try:
            connection = Connection(
                user=config["SUPABASE_DB_USER"], password=password,
                host=config["SUPABASE_DB_HOST"], port=5432,
                database="postgres", timeout=20,
                ssl_context=tls_context,
                application_name="garage99-db-validation",
            )
        finally:
            password = None
        stage = "inspect"
        connection.run("set statement_timeout = '20s'")
        connection.run("set lock_timeout = '5s'")
        identity = connection.run("select current_database(), current_user, now()")
        report["database"] = identity[0][0]
        report["database_role"] = identity[0][1]
        if identity[0][0] != "postgres":
            raise RuntimeError("Unexpected database")
        existing = connection.run("select to_regclass('public.connection_check')")[0][0]
        migration = ROOT / "supabase/migrations/20260905000100_connection_check.sql"
        if existing is None:
            if not args.apply_migration:
                raise RuntimeError("Probe table missing; apply the reviewed migration")
            stage = "migration"
            connection.run(migration.read_text(encoding="utf-8"))
            report["migration_applied"] = True
        else:
            marker = connection.run(
                "select obj_description('public.connection_check'::regclass, 'pg_class')"
            )[0][0]
            if marker != "Garage99 development connectivity probe. Synthetic public data only.":
                raise RuntimeError("Existing table is not the expected synthetic probe")
            report["migration_applied"] = False
        report["migration_sha256"] = hashlib.sha256(migration.read_bytes()).hexdigest()
        stage = "sql_validation"
        validation = ROOT / "scripts/validacion-db.sql"
        connection.run(validation.read_text(encoding="utf-8"))
        fixture = connection.run(
            "select id, message from public.connection_check where id = 'garage99-db-check'"
        )
        if fixture != [["garage99-db-check", "garage99-dev: lectura verificada"]]:
            raise RuntimeError("Fixture differs from expected SQL result")
        report["validation_sha256"] = hashlib.sha256(validation.read_bytes()).hexdigest()
        report["checks"] = ["sql_connection", "insert_select_update", "delete_rollback",
                            "rls_enabled", "anonymous_read", "write_grants_denied"]
        report["status"] = "PASS"
    except Exception as error:
        report["failed_stage"] = stage
        report["error_type"] = type(error).__name__
        # Database error messages may contain sensitive input; retain only SQLSTATE.
        if error.args and isinstance(error.args[0], dict):
            sqlstate = error.args[0].get("C", "")
            if re.fullmatch(r"[A-Z0-9]{5}", sqlstate):
                report["sqlstate"] = sqlstate
        print("SQL validation failed at " + stage + "; see sanitized report.")
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
        output = ROOT / "artifacts/supabase-sql.json"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
