# fwapg

`fwapg` extends British Columbia's [Freshwater Atlas](https://www2.gov.bc.ca/gov/content/data/geographic-data-services/topographic-data/freshwater) (FWA) with PostgreSQL/PostGIS. `fwapg` provides additional tables, indexes and functions to:

- quickly translate arbitrary point locations (`X,Y`) to a linear reference positions (`blue_line_key, measure`) on the stream network
- enable speedy upstream/downstream queries throughout BC
- quickly and cleanly generate watershed boundaries upstream of arbitrary locations
- enable cross-boundary queries by combining FWA data with data from neighbouring jurisdictions
- enable querying of FWA and other features via spatial SQL
- provide `gradient` values for every FWA stream
- quickly serve FWA features as vector tiles (MVT)
- support serving features and custom functions via web API

## Requirements

- PostgreSQL (tested with v13)
- PostGIS (tested with v3.1.2/GEOS 3.9.1)
- GDAL (tested with v3.3.0)
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