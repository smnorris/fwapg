# Database schema maintenance

### Small Schema Changes: Migrations

Use migrations for targeted changes (adding a column, changing a function, adding an index):

```bash
# 1. Create a migration file
cd db
./create_migration.sh add_gradient_to_streams

# 2. Edit the generated file
#    db/migrations/202604171030__add_gradient_to_streams.sql
#    Write your SQL between BEGIN and COMMIT

# 3. Preview against local DB
./migrate.sh --dry-run

# 4. Apply locally and test
./migrate.sh

# 5. Commit the migration file
git add db/migrations/202604171030__add_gradient_to_streams.sql
git commit -m "add gradient column to streams table"

# 6. Open a PR — CI runs test-migration.yml automatically
#    (triggers on migrations/*.sql changes targeting main)
```

Migrations accumulate in `db/migrations/` and are applied in order on any database that is behind.


### Major Changes: Regenerating schema.sql

`schema.sql` is a `pg_dump` snapshot of the full database. 
This is the authoritative definition for fresh installs. 
It is **not** auto-updated by migrations — it must be manually regenerated when significant structural changes accumulate.	
When this has occureed, regenerate `schema.sql` from a clean, fully-loaded database.

**Recommended workflow:**

```bash
#    Dump a new schema.sql
#    Use --schema-only to exclude data, --no-owner / --no-privileges
#    to keep it portable
pg_dump \
  --schema-only \
  --no-owner \
  --no-privileges \
  --no-tablespaces \
  "$DATABASE_URL" \
  -f db/schema.sql

# 5. Inspect the diff to confirm only intended changes appear
git diff db/schema.sql

# 6. Commit schema.sql alongside any remaining migration files
git add db/schema.sql
git commit -m "regenerate schema.sql after v0.8.0 migrations"

# 7. Tag the release
git tag v0.8.0
git push origin main --tags
#    CI builds and pushes updated Docker images tagged v0.8.0 and :main
```

**When to regenerate schema.sql:**

- Before a versioned release (e.g., v0.8.0)
- After adding new extensions or schemas
- After large-scale function rewrites where the diff becomes hard to review
- Periodically, to prevent the migration chain from growing unwieldy for new installs

**What NOT to do:**

- Do not hand-edit `schema.sql` — always regenerate it from a live dump
- Do not delete applied migration files — they are the audit trail and may be needed to bring old databases forward
- Do not skip the `db_version` table update step — always run changes to the db via the migrate script