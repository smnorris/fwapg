# fwapg

`fwapg` extends British Columbia's [Freshwater Atlas](https://www2.gov.bc.ca/gov/content/data/geographic-data-services/topographic-data/freshwater) (FWA) with PostgreSQL/PostGIS. `fwapg` provides additional tables, indexes and functions to:

- quickly translate arbitrary point locations (`X,Y`) to a linear reference positions (`blue_line_key, measure`) on the stream network
- enable speedy upstream/downstream queries throughout BC
- quickly and cleanly generate watershed boundaries upstream of arbitrary locations
- enable cross-boundary queries by combining FWA data with data from neighbouring jurisdictions
- enable querying of FWA features via spatial SQL
- provide `gradient` values for every FWA stream
- enable quickly serving FWA features as vector tiles (MVT) via [`pg_tileserv`](https://www.hillcrestgeo.ca/pg_tileserv)
- enable quickly serving FWA features and custom fwapg functions via [`pg_featureserv`](https://www.hillcrestgeo.ca/fwapg)

See [documentation](link) for setup and usage details, plus table and function references.


## Quickstart

1. Ensure you have access to a PostgreSQL 13 (>=13) database with the PostGIS extension (>=3.1) and GDAL (>=3.3) is available on your system.


2. Create or update the required environment variables to point to your database. If a password is required for `$PGUSER`, either [create a password file](https://www.postgresql.org/docs/current/libpq-pgpass.html) or modify the connection strings directly in the `Makefile` as required.

    - `$PGHOST`
    - `$PGUSER`
    - `$PGDATABASE`
    - `$PGPORT`

3. Download and extract [latest fwapg release](https://github.com/smnorris/fwapg/releases)

4. Load and optimize the data (this takes some time):

        cd fwapg
        make all

5. Run `fwapg` enabled queries with your favorite sql client. For example:

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


    See [Usage](link) for more examples.


## Source data

- BC Freshwater Atlas [documentation](https://www2.gov.bc.ca/gov/content/data/geographic-data-services/topographic-data/freshwater) and [license](https://www2.gov.bc.ca/gov/content/data/open-data/open-government-licence-bc)

- USGS Watershed Boundary Dataset (WBD) [Metadata](https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.xml)

- Hydrosheds [License and citation](https://www.hydrosheds.org/page/license)


## Development and testing

Extremely basic tests are included for selected functions.
If changing a covered function, run the individual test. For example:

    psql -f tests/test_fwa_upstream.sql

All results should be true.

