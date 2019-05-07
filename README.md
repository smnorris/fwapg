# fwapg

PostgreSQL tools for working with British Columbia's [Freshwater Atlas](https://www2.gov.bc.ca/gov/content/data/geographic-data-services/topographic-data/freshwater). Mostly a scripting language agnostic replacement for Python tools in [fwakit](https://github.com/smnorris/fwakit).

## Requirements

- PostgreSQL/PostGIS (tested with v11.2/2.5.2)
- GDAL (tested with v2.4.1)


## Installation

The repository is a collection of sql files and shell scripts, no installation is required, just download the files:

    git clone pgfwa


## Configuration

The data load scripts require that the [postgres environment variables](https://www.postgresql.org/docs/11/libpq-envars.html) `$PGHOST`, `$PGUSER`,`$PGDATABASE`,`$PGPORT` are set to point at the database you wish to use. For example, on linux/mac:

    export PGHOST=localhost
    export PGUSER=postgres
    export PGPORT=5432
    export PGDATABASE=postgis

To provide the script with a password to the database, either [create a password file]( https://www.postgresql.org/docs/11/libpq-pgpass.html) or modify the connection strings in the script.

This document does not cover PostgreSQL setup - this is a detailed topic which depends on hardware and workload. See these links for more:

- [general guide](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [sample setup script for GIS processing on MacOS](https://github.com/bcgov/designatedlands/blob/master/scripts/postgres_mac_setup.sh)


## Data load

### Setup

Create the target database if it does not already exist, with a command something like this:

    psql -c "CREATE DATABASE $PGDATABASE" postgres

Create the required extensions and schema:

    psql -c "CREATE EXTENSION IF NOT EXISTS postgis"
    psql -c "CREATE EXTENSION IF NOT EXISTS ltree"
    psql -c "CREATE SCHEMA IF NOT EXISTS whse_basemapping"


### Load

Download `FWA.zip`, extract the zipfile and run the load script which uses `ogr2ogr` to load all tables to the staging schema `fwa_load`. For example:

    aws s3 cp s3://bc-fwa-gpkg/FWA.zip FWA.zip
    unzip FWA.zip
    ./01_load.sh

Loading is relatively quick, but to speed it up even more, the `ogr2ogr` commands in the script can be run in parallel (requires [GNU parallel](https://www.gnu.org/software/parallel), sed usage plagiarized from [here](https://catonmat.net/sed-one-liners-explained-part-one)):

    cat load.sh | sed 's/^[ \t]*//' | sed -e :a -e '/\\$/N; s/\\\n//; ta' | parallel {}

To run the load script on Windows, rename to `load.bat` and change the line continuation characters from `\` to `^`.


### Clean / optimize

    ./02_clean.sh

It takes time to build all the indexes but once done you have a Provincial FWA database ready for speedy queries.


