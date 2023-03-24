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

## Adjust search path

Functions are loaded to schemas `whse_basemapping`, `usgs`, and `hydrosheds`. Ensure they are found by altering the `search_path` something like this:

   psql -c "ALTER DATABASE fwapg SET search_path TO public,whse_basemapping,usgs,hydrosheds"

## Environment variables

The data load script requires the environment variable `DATABASE_URL` to be set in order to connect to the database.

For example:

```bash
export DATABASE_URL=postgresql://postgres:postgres@db:5432/fwapg
```

To confirm that you can connect to the database with this environment variable, start `psql` with it as the first argument:

```bash
$ psql $DATABASE_URL
psql (14.7)
Type "help" for help.

fwapg=#
```

## Data load

Get the `fwapg` scripts by either downloading and unzipping the [latest release](https://github.com/smnorris/fwapg/releases), or downloading the development version:

    git clone https://github.com/smnorris/fwapg.git

Load and optimize the data:

    cd fwapg
    make

For a given spatial FWA table, the load sequence is generally:
- download .gdb from FWA ftp
- load data to temp table in `fwapg` schema 
- copy data from the load table to output `whse_basemapping` table, adding custom types and columns


## Updates

No tracking of changes to source FWA data changes is available. To apply updates, full table refreshes are required.

To drop all `fwapg` managed data and functions and re-load:

    make clean_targets
    make clean_db
    make


## Data currency

All data are downloaded from GeoBC FWA FTP and will thus be as current as the latest publication of the data to FTP. 
Note that the ftp data is not automatically synced with the BCGW - it is manually refreshed by GeoBC.