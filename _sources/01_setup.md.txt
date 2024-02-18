# Setup and data load


The instructions below presume all requirements listed in the README are installed and postgres is accepting connections.


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
psql (14.7)
Type "help" for help.

fwapg=#
```

## Schema and data load

Get the `fwapg` scripts by either downloading and unzipping the [latest tag](https://github.com/smnorris/fwapg/tags), or downloading the development version:

    git clone https://github.com/smnorris/fwapg.git

Create output schema in the target database:

    cd fwapg
    make .make/db

Download source FWA files, load to target database:

    make all

## Updates

To apply updates, full table refreshes are generally required.

To drop all `fwapg` managed data and functions and re-load:

    make clean_targets
    make clean_db
    make

If the source data has changed sufficiently, re-building the various datasets in `extras` will be necessary - see the various READMEs for each dataset.

## Data currency

All data are downloaded from the latest posted to GeoBC FWA FTP. 