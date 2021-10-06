# Extras

These lookup tables take several hours to generate. Rather than re-generate the lookups each time the database is loaded, `fwapg` defaults to loading the tables from cached csvs. If updates to the lookups are required, regenerate the csv files using these scripts.


## fwa_watersheds_upstream_area

It is often useful to know how much area is upstream of a given location, and often this needs to be calculated for many locations. Rather than run the calculation each time it is required, we can run the calculation for all fundamental watersheds and cache the result in a lookup table. This calculates the upstream area for all watersheds, starting at the outlet of each watershed (ie, the area total includes the area of the fundamental watershed that is the starting point).

**NOTE** - output currently includes area upstream **WITHIN BC ONLY**, this will not be accurate in watersheds that have contributing drainage outside of BC!

    ./fwa_watersheds_upstream_area.sh

When working with watersheds, join to the lookup via `watershed_feature_id`. When working with streams, relate the streams to watersheds via the lookup `fwa_streams_watersheds_lut`:

    SELECT
      s.linear_feature_id,
      ua.upstream_area_ha
    FROM whse_basemapping.fwa_stream_networks_sp s
    LEFT OUTER JOIN whse_basemapping.fwa_streams_watersheds_lut l
    ON s.linear_feature_id = l.linear_feature_id
    INNER JOIN whse_basemapping.fwa_watersheds_upstream_area ua
    ON l.watershed_feature_id = ua.watershed_feature_id

## fwa_waterbodies_upstream_area

As with upstream watershed area, it is often useful to know how much lake/reservoir/wetland is upstream of a given location, and often this needs to be calculated for many locations. Rather than run the calculation each time it is required, we can run the calculation for all streams and cache the result in a lookup table. Note that this is different than upstream watershed area above - we use streams as the lookup base rather than watersheds because waterbodies can be nested within fundamental watersheds.

**NOTE** - output currently includes area upstream **WITHIN BC ONLY**, this will not be accurate in watersheds that have contributing drainage outside of BC!

    ./fwa_waterbodies_upstream_area.sh

## Assessment watersheds lookups

Some workflows require relating `fwa_assessment_watersheds_poly` to stream segments and fundamental watersheds. There are no existing keys in the data that maintain this link - the query requires a resource intensive spatial function.  Rather than running a spatial query every time, we can create lookups. The lookups are provided at `https://hillcrestgeo.ca/outgoing/public/fwapg/` and loaded by `01_load.sh`, but they can be created from scratch with this script:

    ./assessment_watersheds_lookups.sh
