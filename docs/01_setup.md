# Setup and data load

## Dependencies

- [PostgreSQL](https://www.postgresql.org) (>=13)
- [PostGIS](https://postgis.net/) (>=v3.1 with GEOS >=3.9)
- Python 3 and [`bcdata`](https://github.com/smnorris/bcdata)
- [GDAL](https://gdal.org/index.html) (tested with v3.5)
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

Once scripts are complete you have a FWA database ready for speedy queries. 

## Partial loads

Partial loads are possible. If you only require certain FWA tables, load them individually like this:

    make .make/fwa_stream_networks_sp

## Updates

No tracking of changes to source FWA data changes is available. To apply updates, full table refreshes are required.

To drop all `fwapg` managed data and functions and re-load:

    make clean_targets
    make clean_db
    make

To refresh a specific table, remove the `make` created placeholder files for the given table and re-load:

    rm .make/*.fwa_stream_networks_sp
    make .make/fwa_stream_networks_sp

Note that while downloading large tables from WFS is very slow, downtime from applying single-table updates is minimal.

## Data currency

All tables containing geometries (ie spatial data) are downloaded from DataBC WFS server and are guaranteed to the be latest available.

All tables without geometries (code tables, 20k-50k lookups) are downloaded from GeoBC FTP site and are thus only as current as the latest publication of the `FWA_BC.zip` file to FTP.