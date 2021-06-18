### Extras

#### Neighbouring jurisdictions
For generating trans-boundary watersheds (`sql/fwa_watershedexbc.sql`), non-FWA data from neighbouring jurisdictions is required. Download and add to the database with this script:

    ./neighbours.sh

#### Upstream watershed area

It is often useful to know how much area is upstream of a given location, and often this needs to be calculated for many locations. Rather than run the calculation each time it is required, we can run the calculation for all fundamental watersheds and cache the result in a lookup table.

**NOTE** - output currently includes area upstream **WITHIN BC ONLY**, this will not be accurate in watersheds that have contributing drainage outside of BC!

    ./fwa_watersheds_upstream_area.sh

When working with watersheds, join to the lookup via `watershed_feature_id`. When working with streams, the
join is a bit more complex because there is no easy way to relate streams to watershed polyons for 100% of features. This query will get area upstream of stream segments:

    SELECT DISTINCT ON (linear_feature_id)
      s.linear_feature_id,
      ua.upstream_area
    FROM whse_basemapping.fwa_stream_networks_sp s
    INNER JOIN whse_basemapping.fwa_watersheds_poly w
    ON ST_Intersects(ST_pointonsurface(s.geom), w.geom)
    INNER JOIN whse_basemapping.fwa_watersheds_upstream_area ua
    ON w.watershed_feature_id = ua.watershed_feature_id
    WHERE NOT s.wscode_ltree  <@ '999'
    ORDER BY s.linear_feature_id, s.stream_order


#### Upstream waterbody area

As with upstream watershed area, it is often useful to know how much lake/reservoir/wetland is upstream of a given location, and often this needs to be calculated for many locations. Rather than run the calculation each time it is required, we can run the calculation for all streams and cache the result in a lookup table. Note that this is different than upstream watershed area above - we use streams as the lookup base rather than watersheds because waterbodies can be nested within fundamental watersheds.

**NOTE** - output currently includes area upstream **WITHIN BC ONLY**, this will not be accurate in watersheds that have contributing drainage outside of BC!

    ./fwa_waterbodies_upstream_area.sh

#### Assessment watersheds lookup

Some workflows require relating `fwa_assessment_watersheds_poly` to stream segments and fundamental watersheds. There are no existing keys in the data that maintain this link - the query requires a resource intensive spatial function.  Rather than running a spatial query every time, we can create lookups. The lookups are provided at `https://hillcrestgeo.ca/outgoing/public/fwapg/` and loaded by `01_load.sh`, but they can be created from scratch with this script:

    ./assessment_watersheds_lookups.sh
