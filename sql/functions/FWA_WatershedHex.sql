-- Given blue_line_key and downstream_route_measure, return 25m hex grid
-- covering all area upstream of the point, within the same first order
-- watershed


CREATE OR REPLACE FUNCTION FWA_WatershedHex(blkey integer, meas float)

RETURNS TABLE(hex_id bigint, geom geometry)
AS


$$

-- interpolate point on stream
WITH pt AS (
  SELECT
    s.linear_feature_id,
    s.blue_line_key,
    s.downstream_route_measure,
    ST_LineInterpolatePoint(
      (ST_Dump(s.geom)).geom,
      ROUND(CAST((meas - s.downstream_route_measure) / s.length_metre AS NUMERIC), 5)
          ) as geom
  FROM whse_basemapping.fwa_stream_networks_sp s
  WHERE s.blue_line_key = blkey
  AND s.downstream_route_measure <= meas
  ORDER BY s.downstream_route_measure desc
  LIMIT 1
),

-- find the watershed in which the point falls
wsd AS (
  SELECT w.watershed_feature_id, w.geom
  FROM pt
  INNER JOIN whse_basemapping.fwa_watersheds_poly w
  ON ST_Intersects(pt.geom, w.geom)
),

-- generate a hex grid (with 25m sides) covering the entire watershed polygon
hex AS (
  SELECT ST_ForceRHR(ST_Force2D(CDB_HexagonGrid(ST_Buffer(geom, 25), 25))) as geom
  FROM wsd
)

-- cut the hex watersheds with the watershed polygon
SELECT
  row_number() over() as hex_id,
  CASE
    WHEN ST_Within(a.geom, b.geom) THEN ST_Multi(a.geom)
    ELSE ST_ForceRHR(ST_Multi(ST_Force2D(ST_Intersection(a.geom, b.geom))))
  END as geom
 FROM hex a
INNER JOIN wsd b ON ST_Intersects(a.geom, b.geom);

$$
language 'sql' immutable parallel safe;