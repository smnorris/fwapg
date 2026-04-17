#!/usr/bin/env bash
set -euo pipefail
 
# Usage: ./create_migration.sh <description>
# eg:    ./create_migration.sh add_users_table
 
MIGRATIONS_DIR="${MIGRATIONS_DIR:-migrations}"
 
if [[ $# -eq 0 ]]; then
  echo "ERROR: A migration description is required"
  echo "Usage: $(basename "$0") <description>"
  echo "Example: $(basename "$0") add_users_table"
  exit 1
fi
 
description="$1"
timestamp=$(date +%Y%m%d%H%M)
filename="${timestamp}__${description// /_}.sql"
filepath="$MIGRATIONS_DIR/$filename"
 
if [[ -f "$filepath" ]]; then
  echo "ERROR: Migration file already exists: $filepath"
  exit 1
fi
 
mkdir -p "$MIGRATIONS_DIR"
 
cat > "$filepath" <<-SQL
BEGIN;
 
-- migration goes here
 
COMMIT;
SQL
 
echo "Created $filepath"