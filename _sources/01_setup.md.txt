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

## Data load and optimization

Get the `fwapg` scripts by either:

- manually downloading and unzipping the [latest fwapg release](https://github.com/smnorris/fwapg/releases)
- downloading the development version:

        git clone https://github.com/smnorris/fwapg.git

Load and optimize the data:

    cd fwapg
    make

Once scripts are complete you have a FWA database ready for speedy queries.