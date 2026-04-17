#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "ERROR: A migration description is required"
  echo "Usage: $(basename "$0") <description>"
  echo "Example: $(basename "$0") add_users_table"
  exit 1
fi

description="$1"
timestamp=$(date +%Y%m%d%H%M)
filename="${timestamp}__${description// /_}.sql"
touch migrations/"$filename"
echo "Created migrations/$filename"