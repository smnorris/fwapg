-- fwa_watershedexbc.sql

-- Given a point as (blue_line_key, downstream_route_measure),
-- return upstream watershed boundary including HUC12 / hydrosheds data outside of BC.

CREATE OR REPLACE FUNCTION FWA_WatershedExBC(blkey integer, meas float)

RETURNS TABLE(src text, geom geometry) AS

$$

DECLARE
  v_borderval varchar;
  v_geom geometry;

BEGIN

-- find points at which stream flows into BC
SELECT border
FROM FWA_UpstreamBorderCrossings(blkey, meas)
LIMIT 1 into v_borderval;

-- get the point (nesting the FWA_LocateAlong call as subquery in the below recursive query
-- gets materialized - on pg13 it is *extremely* slow, so just extract the point here)
SELECT *
FROM FWA_LocateAlong(blkey, meas)
LIMIT 1 into v_geom;

-- For streams along the 49th parallel, we can generate all streams that
-- cross the border and find HUC12s upstream.
-- Note - could we just use the same approach as for hydrosheds,
-- find the huc12 that the point is in and return everything upstream?
-- This would be far simpler, I'm not sure if there is a specific reason for generating these upstream border points
IF v_borderval = 'USA_49' THEN return query

    WITH RECURSIVE walkup (huc12, geom) AS
    (
        SELECT huc12, wsd.geom
        FROM usgs.wbdhu12 wsd
        WHERE ST_Intersects(wsd.geom, v_geom)

        UNION ALL

        SELECT b.huc12, b.geom
        FROM usgs.wbdhu12 b,
        walkup w
        WHERE b.tohuc = w.huc12
    )
    SELECT
      'NHD HUC12' AS source,
      ST_Union(w.geom) as geom
    FROM walkup w;

ELSE return query

-- For streams in other areas we use hydrosheds, which has far less detail
-- Find the hydroshed at the point of interest and work upstream from there
    WITH RECURSIVE walkup (hybas_id, geom) AS
        (
            SELECT hybas_id, wsd.geom
            FROM hydrosheds.hybas_lev12_v1c wsd
            WHERE ST_Intersects(wsd.geom, v_geom)

            UNION ALL

            SELECT b.hybas_id, b.geom
            FROM hydrosheds.hybas_lev12_v1c b,
            walkup w
            WHERE b.next_down = w.hybas_id
        )
    SELECT
      'hybas_na_lev12_v1c' AS source,
      ST_Union(w.geom) as geom
    FROM walkup w;

END IF;

END;

$$
language 'plpgsql' immutable strict parallel safe;