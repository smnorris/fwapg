### Extras

For generating trans-boundary watersheds (`sql/fwa_watershedexbc.sql`), non-FWA data from neighbouring jurisdictions is required. Download and add to the database with this script:

    ./neighbours.sh

Some workflows require relating `fwa_assessment_watersheds_poly` to stream segments and fundamental watersheds. There are no existing links in the attribues so this relation requires a resource intensive spatial query.  Rather than running a spatial query every time, we can create lookups. The lookups are provided at `https://hillcrestgeo.ca/outgoing/public/fwapg/` and loaded by `01_load.sh`, but they can be created from scratch with this script:

    ./assessment_watersheds_lookups.sh

Rather than calculate upstream area as needed, this draft script will add and populate an `upstream_area_ha` column in the streams table (currently requires [`pgdata`](https://github.com/smnorris/pgdata) and is extremely slow)

    python add_upstream_area_ha.py