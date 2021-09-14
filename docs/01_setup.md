# Setup and data load


## Requirements

- PostgreSQL (>=13)
- PostGIS (>=v3.1 with GEOS >=3.9)
- GDAL (tested with v3.3.0)
- GNU make


## Environment variables configuration

The data load makefile requires these [postgres environment variables](https://www.postgresql.org/docs/current/libpq-envars.html) to be set in order to connect to the database:

- `$PGHOST`
- `$PGUSER`
- `$PGDATABASE`
- `$PGPORT`

If a password is required for `$PGUSER`, either [create a password file](https://www.postgresql.org/docs/current/libpq-pgpass.html) or modify the connection strings directly in the `Makefile` as required.


## Create the database

If you are not loading to an existing database, create a new one with a command like this:

    psql -c "CREATE DATABASE $PGDATABASE" postgres


## Data load and optimization

Get the `fwapg` scripts by either:

- manually downloading and unzipping the [latest fwapg release](https://github.com/smnorris/fwapg/releases)
- downloading the development version:

        git clone https://github.com/smnorris/fwapg.git

Load and optimize the data:

    cd fwapg
    make all

Once scripts are complete you have a FWA database ready for speedy queries.