# fwapg

PostgreSQL tools for working with British Columbia's [Freshwater Atlas](https://www2.gov.bc.ca/gov/content/data/geographic-data-services/topographic-data/freshwater). Mostly a scripting language agnostic replacement for Python tools in [fwakit](https://github.com/smnorris/fwakit).

## Rationale

BC FWA data is already available on request [via WFS](https://openmaps.gov.bc.ca/geo/pub/wfs?service=WFS&version=2.0.0&request=GetFeature&typeName=WHSE_BASEMAPPING.FWA_LAKES_POLY&outputFormat=json&SRSNAME=epsg%3A3005&CQL_FILTER=GNIS_NAME_1=%27Quamichan%20Lake%27) and via R and Python WFS wrappers such as:

- [fwabc](https://github.com/poissonconsulting/fwabc)
- [bcdata (R)](https://github.com/bcgov/bcdata)
- [bcdata (Python)](https://github.com/smnorris/bcdata)

These work well but using WFS has some specific limitations for Provincal analysis:

- requesting many features is surprisingly stable (with a good internet connection), but for larger FWA tables it can be error prone (there are 4.9M individual stream segments, or 1M for the Fraser system alone)
- non-spatial FWA lookup tables required for some workloads (such as [linking fish observations to waterbodies](https://github.com/smnorris/bcfishobs)) are not published via WFS ([example](https://catalogue.data.gov.bc.ca/dataset/freshwater-atlas-20k-50k-stream-cross-reference-table))
- querying WFS via `CQL_FILTER` expressions works well but the WFS does not specifically support upstream/downstream relationships built into the FWA data

As a zipped geopackage, the FWA is under 7G - by downloading this and loading to Postgres, we can:

- leverage the upstream/downstream materialized paths built into FWA watershed codes by using the Postgres [`ltree` module](https://www.postgresql.org/docs/current/ltree.html)
- add additional convenience tables (named streams, optimized watershed groups)
- populate the empty `gradient` column in the streams table for ongoing use
- connect directly to the database to run various ad-hoc queries using spatial SQL and tools that support the PostgreSQL / PostGIS ecosystem


## Requirements

- PostgreSQL/PostGIS (tested with v11.2/2.5.2)
- GDAL (tested with v2.4.1)


## Installation

The repository is a collection of sql files and shell scripts - no installation is required, just download the files:

    git clone https://github.com/smnorris/fwapg.git


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

Download `FWA.zip`, extract the zipfile and run the load script. For example (requires `awscli`):

    aws s3 cp s3://bc-fwa-gpkg/FWA.zip FWA.zip
    unzip FWA.zip
    ./01_load.sh

Loading is relatively quick, but to speed it up even more, the `ogr2ogr` commands in the script can be run in parallel (requires [GNU parallel](https://www.gnu.org/software/parallel), sed usage plagiarized from [here](https://catonmat.net/sed-one-liners-explained-part-one)):

    cat load.sh | sed 's/^[ \t]*//' | sed -e :a -e '/\\$/N; s/\\\n//; ta' | parallel {}

To run the load script on Windows, rename to `load.bat` and change the line continuation characters from `\` to `^`.


### Clean / optimize

    ./02_clean.sh

It takes time to build all the indexes but once done you have a Provincial FWA database ready for speedy queries.


