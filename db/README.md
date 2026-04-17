# schema and migrations


## Current schema

Entire current schema is in `schema.sql`. To load:

	psql $DATABASE_URL -f schema.sql

Note that this is not required for the dockerized database.

## Migrations

To update the database, create a migration file or files.

	$ ./create_migration.sh fix_foo
	Created migrations/202604170407__fix_foo.sql

After adding the sql to the migration files, consider checking the latest migration already applied to the db and listing all the pending migrations:

	$ ./migrate.sh --dry-run
	Current database version: 202604170339
	Pending migrations: 1

	Dry run — the following migrations would be applied:
	  202604170407__fix_foo.sql

 When ready, run the new migration(s).

	./migrate.sh