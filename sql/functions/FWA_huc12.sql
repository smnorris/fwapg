CREATE OR REPLACE FUNCTION FWA_huc12(id character varying)

RETURNS TABLE
    (
        geom geometry(Polygon, 3005)
    )

AS

$$

WITH RECURSIVE walkup (huc12, geom) AS
    (
        SELECT huc12, wsd.geom
        FROM usgs.wbdhu12 wsd
        WHERE huc12 = id

        UNION ALL

        SELECT b.huc12, b.geom
        FROM usgs.wbdhu12 b,
        walkup w
        WHERE b.tohuc = w.huc12
    )
SELECT
  ST_Union(w.geom) as geom
FROM walkup w;

$$
language 'sql' immutable strict parallel safe;


COMMENT ON FUNCTION FWA_huc12 IS 'Return geometry of aggregated watershed boundary for watershed upstream of provided huc12 id';