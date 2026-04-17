#!/usr/bin/env bash
set -euo pipefail

# Usage: ./migrate.sh [migrations_dir]
# Migration files are named: YYYYMMDDhhmm__description.sql
# eg: 20240115143022__add_users.sql
MIGRATIONS_DIR="${1:-migrations}"
DB_URL="${DATABASE_URL:-}"

if [[ -z "$DB_URL" ]]; then
  echo "ERROR: DATABASE_URL environment variable is not set"
  exit 1
fi

psql_cmd() {
  psql "$DB_URL" --no-psqlrc -v ON_ERROR_STOP=1 "$@"
}

# ----------------------------------------------------------------
# Bootstrap db_version table if it doesn't exist
# ----------------------------------------------------------------
psql_cmd <<-SQL
  CREATE SCHEMA IF NOT EXISTS fwapg;
  CREATE TABLE IF NOT EXISTS fwapg.db_version (
    tag        TEXT        NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  INSERT INTO fwapg.db_version (tag)
  SELECT '0'
  WHERE NOT EXISTS (SELECT 1 FROM fwapg.db_version);
SQL

# ----------------------------------------------------------------
# Get current db version (timestamp of last applied migration).
# ----------------------------------------------------------------
current_version=$(psql_cmd -t -A -c "
  SELECT tag FROM fwapg.db_version ORDER BY applied_at DESC LIMIT 1;
" 2>&1) || {
  echo "ERROR: Could not read fwapg.db_version"
  exit 1
}
current_version="${current_version:-0}"
echo "Current database version: ${current_version}"

# ----------------------------------------------------------------
# Collect migration files with timestamp greater than current version
# ----------------------------------------------------------------
pending=()

for f in "$MIGRATIONS_DIR"/[0-9]*__*.sql; do
  [[ -f "$f" ]] || continue
  filename="$(basename "$f")"
  timestamp="${filename%%__*}"

  if [[ "$timestamp" > "$current_version" ]]; then
    pending+=("$f")
  fi
done

if [[ ${#pending[@]} -eq 0 ]]; then
  echo "No pending migrations. Database is up to date."
  exit 0
fi

# Sort by filename (timestamp prefix ensures correct order)
IFS=$'\n' sorted=($(printf '%s\n' "${pending[@]}" | sort))
unset IFS

echo "Pending migrations: ${#sorted[@]}"

# ----------------------------------------------------------------
# Apply each migration in order
# ----------------------------------------------------------------
for f in "${sorted[@]}"; do
  filename="$(basename "$f")"
  timestamp="${filename%%__*}"

  echo ""
  echo "--- Applying: $filename ---"
  psql_cmd -f "$f"

  psql_cmd -c "INSERT INTO fwapg.db_version (tag, applied_at) VALUES ('${timestamp}', now());"
  echo "  Version updated to ${timestamp}"
done

last="$(basename "${sorted[-1]}")"
echo ""
echo "Migrations complete. Database is now at ${last%%__*}"
