# fwapg

`fwapg` extends British Columbia's [Freshwater Atlas](https://www2.gov.bc.ca/gov/content/data/geographic-data-services/topographic-data/freshwater) (FWA) with PostgreSQL/PostGIS. `fwapg` provides additional tables, indexes and functions to:

- quickly translate arbitrary point locations (`X,Y`) to a linear reference positions (`blue_line_key, measure`) on the stream network
- enable speedy upstream/downstream queries throughout BC
- quickly and cleanly generate watershed boundaries upstream of arbitrary locations
- enable cross-boundary queries by combining FWA data with data from neighbouring jurisdictions
- enable querying of FWA features via spatial SQL
- provide `gradient` values for every FWA stream
- enable quickly serving FWA features as vector tiles (MVT)
- enable quickly serving FWA features and custom fwapg functions
- using [`bcdata`](https://github.com/smnorris/bcdata), extract FWA data from DataBC WFS for easy data updates

See [documentation](https://smnorris.github.io/fwapg/) for setup and usage details, plus table and function references.


## Quickstart

1. Ensure all requirements/dependencies are met/installed:
    - access to a PostgreSQL (>=13) database with the PostGIS extension (>=3.1) installed
    - GDAL >=3.4
    - Python 3
    - [`bcdata`](https://github.com/smnorris/bcdata) >= 0.7.3
    - [GNU parallel](https://www.gnu.org/software/parallel/)
    - [`make`](https://www.gnu.org/software/make/)/`unzip`/`wget`/etc

2. Ensure you have a `DATABASE_URL` environment variable set to point to your database, for example:

        export DATABASE_URL=postgres://username:password@localhost:5432/fwapg

3. FWA functions are added to the `whse_basemapping` schema - add them to the `SEARCH_PATH` to ensure they are picked up without schema qualification:

        psql -c "ALTER DATABASE <database_name> SET search_path TO public,whse_basemapping,usgs,hydrosheds"


4. Get scripts, load and optimize the data:

        git clone https://github.com/smnorris/fwapg.git
        cd fwapg
        make

The full load takes several hours, but once complete, you can run `fwapg` enabled queries with your favorite sql client. For example:

*Locate the nearest point on the FWA stream network to a X,Y location on Highway 14:*

        SELECT gnis_name, blue_line_key, downstream_route_measure
        FROM FWA_IndexPoint(-123.7028, 48.3858, 4326);

          gnis_name  | blue_line_key | downstream_route_measure
        -------------+---------------+--------------------------
         Sooke River |     354153927 |        350.2530543284006

*Generate the watershed upstream of above location:*

        SELECT ST_ASText(geom) FROM FWA_WatershedAtMeasure(354153927, 350);

         st_astext
        --------------
        POLYGON((...


See [Usage](https://smnorris.github.io/fwapg/02_usage.html) for more examples.


## Docker

Download the repo, create containers, create database, load fwa data:

    git clone https://github.com/smnorris/fwapg.git
    cd fwapg
    docker-compose build
    docker-compose up -d
    docker-compose run --rm loader psql -c "CREATE DATABASE fwapg" postgres
    docker-compose run --rm loader make --debug=basic

As long as you do not remove the container `fwapg-db`, it will retain all the data you put in it.
If you have shut down Docker or the container, start it up again with this command:

    docker-compose up -d

Connect to the db from your host OS via the port specified in `docker-compose.yml`:

    psql -p 8000 -U postgres fwapg

Or see the FWA data in the browser as vector tiles/geojson features:

    http://localhost:7800/
    http://localhost:9000/

Delete the containers (and associated fwa data):

    docker-compose down


## Tile and feature services

`fwapg` features and functions are served from hillcrestgeo.ca as GeoJSON or vector tiles via these web services and wrappers:

- [features.hillcrestgeo.ca/fwa](https://features.hillcrestgeo.ca/fwa): tables and functions served as GeoJSON
- [fwapgr (R)](https://github.com/poissonconsulting/fwapgr): an R wrapper around the `features.hillcrestgeo.ca/fwa` feature service
- [fwatlasbc (R)](https://github.com/poissonconsulting/fwatlasbc): an R package for higher level queries
- [tiles.hillcrestgeo.ca/bcfishpass](https://tiles.hillcrestgeo.ca/bcfishpass): FWA features (and others) served as vector tiles (MVT)


## Source data

- BC Freshwater Atlas [documentation](https://www2.gov.bc.ca/gov/content/data/geographic-data-services/topographic-data/freshwater) and [license](https://www2.gov.bc.ca/gov/content/data/open-data/open-government-licence-bc)

- USGS Watershed Boundary Dataset (WBD) [Metadata](https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.xml)

- Hydrosheds [License and citation](https://www.hydrosheds.org/page/license)


## Development and testing

Extremely basic tests are included for selected functions.
If changing a covered function, run the individual test. For example:

    psql -f tests/test_fwa_upstream.sql

All results should be true.

## Documentation

Documentation is built from the markdown files in `/docs`.
Info in the table reference page (`03_tables.md`) can be autogenerated from comments in the database. To dump the text to stdout:
```
cd docs
./table_reference.sh 
```