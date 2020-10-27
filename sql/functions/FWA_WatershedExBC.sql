-- fwa_watershedexbc.sql

-- Given a point as (blue_line_key, downstream_route_measure),
-- return upstream watershed boundary for portion of watershed outside of BC.

CREATE OR REPLACE FUNCTION FWA_WatershedExBC(blkey integer, meas float)

RETURNS TABLE(src text, geom geometry) AS

$$

DECLARE
  borderval varchar;

BEGIN

-- find points at which stream flows into BC
SELECT border
FROM FWA_UpstreamBorderCrossings(blkey, meas)
LIMIT 1 into borderval;

-- For streams along the 49th parallel, we can generate all streams that
-- cross the border and find HUC12s upstream
IF borderval = 'USA_49' THEN return query

    WITH RECURSIVE walkup (huc12, geom) AS
    (
        SELECT huc12, wsd.geom
        FROM usgs.wbdhu12 wsd
        INNER JOIN (select * FROM FWA_UpstreamBorderCrossings(blkey, meas)) as pt
        ON ST_Intersects(wsd.geom, pt.geom)

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
            INNER JOIN (select * FROM FWA_LocateAlong(blkey, meas)) as pt
            ON ST_Intersects(wsd.geom, pt.geom)

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