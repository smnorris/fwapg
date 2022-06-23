# Setup and data load

## Dependencies

- [PostgreSQL](https://www.postgresql.org) (>=13)
- [PostGIS](https://postgis.net/) (>=v3.1 with GEOS >=3.9)
- [GDAL](https://gdal.org/index.html) (tested with v3.5)
- Python 3 
- [`bcdata`](https://github.com/smnorris/bcdata) >= 0.6.3
- [GNU parallel](https://www.gnu.org/software/parallel/)
- [`make`](https://www.gnu.org/software/make/)/`unzip`/`wget`/etc

The instructions below presume above requirements are installed and postgres is accepting connections.


## Create the database

If you are not loading to an existing database, create a new one (adjusting the database name as required):

```bash
createdb fwapg
```

## Environment variables

The data load script requires the environment variable `DATABASE_URL` to be set in order to connect to the database.

For example:

```bash
export DATABASE_URL=postgresql://postgres:postgres@db:5432/fwapg
```

To confirm that you can connect to the database with this environment variable, start `psql` with it as the first argument:

```bash
$ psql $DATABASE_URL
psql (13.3)
Type "help" for help.

fwapg=#
```

## Data load

Get the `fwapg` scripts by either downloading and unzipping the [latest release](https://github.com/smnorris/fwapg/releases), or downloading the development version:

        git clone https://github.com/smnorris/fwapg.git

Load and optimize the data:

    cd fwapg
    make

For a given spatial FWA table, the load sequence is:
- download features from `openmaps.gov.bc.ca` WFS service in 5k chunks
- load geojson responses to temp table in `fwapg` schema with single `jsonb` column
- create output table in `fwapg` schema
- copy data from the load table to output table, translating data from geojson
- change the schema name of the table to `whse_basemapping`

Note that the download time for the larger tables is *very* slow, the full load takes several hours.
However, once scripts are complete you have an up-to-date FWA database ready for speedy queries. 

## Partial loads

Partial loads are possible but require some manual intervention. Load an individual table like this:

    # load required table to staging schema
    make .make/fwa_stream_networks_sp   
    # drop existing table in whse_basemapping if present
    psql -c "drop table if exists whse_basemapping.fwa_stream_networks_sp"
    # switch data from staging schema into whse_basemapping
    psql -c "alter table fwapg.fwa_stream_networks_sp set schema whse_basemapping"


## Updates

No tracking of changes to source FWA data changes is available. To apply updates, full table refreshes are required.

To drop all `fwapg` managed data and functions and re-load:

    make clean_targets
    make clean_db
    make

To refresh in the background:

    make clean_targets
    make

To refresh a specific table, remove the `make` created placeholder files for the given table then re-load as noted above:

    rm .make/fwa_stream_networks_sp*
    make .make/fwa_stream_networks_sp
    psql -c "drop table if exists whse_basemapping.fwa_stream_networks_sp"
    psql -c "alter table fwapg.fwa_stream_networks_sp set schema whse_basemapping"


## Data currency

All tables containing geometries (ie spatial data) are downloaded from DataBC WFS server and are guaranteed to the be latest available.

All tables without geometries (code tables, 20k-50k lookups) are downloaded from GeoBC FTP site and are thus only as current as the latest publication of the `FWA_BC.zip` file to FTP.