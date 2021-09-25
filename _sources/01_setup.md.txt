# Setup and data load

## Requirements

- [PostgreSQL](https://www.postgresql.org) (>=13)
- [PostGIS](https://postgis.net/) (>=v3.1 with GEOS >=3.9)
- [GDAL](https://gdal.org/index.html) (tested with v3.3.0)
- [GNU parallel](https://www.gnu.org/software/parallel/)
- [`make`](https://www.gnu.org/software/make/)/`unzip`/`wget`/etc

The instructions below presume postgres is set up and accepting connections.


## Create the database

If you are not loading to an existing database, create a new one (adjusting the database name as required):

```bash
createdb fwapg
```

## Environment variables

The data load script requires these [postgres environment variables](https://www.postgresql.org/docs/current/libpq-envars.html) to be set in order to connect to the database:

- `$PGHOST`
- `$PGUSER`
- `$PGDATABASE`
- `$PGPORT`

For example:

```bash
export PGHOST=localhost
export PGUSER=fwapguser
export PGDATABASE=fwapg
export PGPORT=5432
```

If a password is required for `$PGUSER`, [create a password file](https://www.postgresql.org/docs/current/libpq-pgpass.html).

To confirm that you can connect to the database using these environment variables, start `psql` without any arguments:

```bash
$ psql
psql (13.3)
Type "help" for help.

fwapg=#
```

## Data load and optimization

Get the `fwapg` scripts by either:

- manually downloading and unzipping the [latest fwapg release](https://github.com/smnorris/fwapg/releases)
- downloading the development version:

        git clone https://github.com/smnorris/fwapg.git

Load and optimize the data:

    cd fwapg
    make all

Once scripts are complete you have a FWA database ready for speedy queries.