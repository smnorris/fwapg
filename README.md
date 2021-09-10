# fwapg

Tools to create a PostgreSQL database for working with British Columbia's [Freshwater Atlas](https://www2.gov.bc.ca/gov/content/data/geographic-data-services/topographic-data/freshwater).


## Key features

- find the closest stream to any given point in BC
- extract the watershed boundary upstream of an arbitrary point on a stream
- indexed (speedy) upstream/downstream queries like:
    + [*how many salmon observations are there upstream of a point?*](https://github.com/smnorris/bcfishobs)
    + [*what is the area of a watershed above a stream guage?*](https://github.com/smnorris/bcbasins)
    + [*how many km of potential fish habitat are upstream of a failed culvert?*](https://github.com/smnorris/bcfishpass)
- convenience tables for mapping, watershed aggregation, etc (`fwa_named_streams`, `fwa_basins_poly` and more)
- `gradient`  for every FWA stream
- combines FWA data with similar data from adjacent jurisdictions for cross-boundary queries
- enable serving FWA data direct from the db as MVT (vector tiles) via [`pg_tileserv`](https://github.com/CrunchyData/pg_tileserv):
    + [MVT service](https://www.hillcrestgeo.ca/pg_tileserv)
- enable serving FWA data features and spatial functions via API provided by [`pg_featureserv`](https://github.com/CrunchyData/pg_featureserv):
    + [API](https://www.hillcrestgeo.ca/fwapg)
    + [R client](https://github.com/poissonconsulting/fwapgr/)


## Requirements

- PostgreSQL (requires >= v12, best with >=13)
- PostGIS (tested with >= v3.0.1, best with >=3.1)
- GDAL (tested with >= v2.4.4)
- GNU make


## Configuration

The data load script requires that the [postgres environment variables](https://www.postgresql.org/docs/current/libpq-envars.html) `$PGHOST`, `$PGUSER`,`$PGDATABASE`,`$PGPORT` are set to point at the database you wish to use. For example:

    export PGHOST=localhost
    export PGUSER=postgres
    export PGPORT=5432
    export PGDATABASE=postgis

To provide the script with a password to the database, either [create a password file]( https://www.postgresql.org/docs/current/libpq-pgpass.html) or modify the connection strings in the script.

This document does not cover PostgreSQL configuration - this is a detailed topic which depends on hardware and workload:

- [general guide](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [sample setup script for GIS processing on MacOS](https://github.com/bcgov/designatedlands/blob/master/scripts/postgres_mac_setup.sh)


## Create and load database

If you are not loading to an existing database, create a new one with a command like this:

    psql -c "CREATE DATABASE $PGDATABASE" postgres

Get the `fwapg` scripts by either:

- manually downloading and unzipping the [latest fwapg release](https://github.com/smnorris/fwapg/releases)
- downloading the development version:

        git clone https://github.com/smnorris/fwapg.git

To run the database load scripts:

    cd fwapg
    make all

Once scripts are complete you have a FWA database ready for speedy queries.

## Usage



## Testing

Extremely basic tests are included for selected functions.
If changing a covered function, run the individual test. For example:

    psql -f tests/test_fwa_upstream.sql

All results should be true.

## Source data

- BC Freshwater Atlas [License](https://www2.gov.bc.ca/gov/content/data/open-data/open-government-licence-bc)
and [Documentation](https://www2.gov.bc.ca/gov/content/data/geographic-data-services/topographic-data/freshwater)

- USGS Watershed Boundary Dataset (WBD) [Metadata](https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.xml)

- Hydrosheds [License and citations](https://www.hydrosheds.org/page/license)