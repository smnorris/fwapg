-- Given a point as a blue_line_key, route_measure, return
-- stream segments upstream in the same first order watershed

-- given a point as a blue_line_key, route_measure, return
-- stream segments upstream in the same first order watershed

CREATE OR REPLACE FUNCTION fwa_watershedstream(blkey integer, meas float)

RETURNS TABLE(linear_feature_id bigint, geom geometry)
AS


$$

WITH local_segment AS
(SELECT
  s.linear_feature_id,
  s.blue_line_key,
  meas as downstream_route_measure,
  s.wscode_ltree,
  s.localcode_ltree,
  ST_Force2D(
    ST_Multi(
      ST_LineSubstring((ST_Dump(s.geom)).geom,
                   ((meas - s.downstream_route_measure) / s.length_metre),
                   1)
                   )
  ) AS geom,
ST_LineInterpolatePoint(
      (ST_Dump(s.geom)).geom,
      ROUND(CAST((meas - s.downstream_route_measure) / s.length_metre AS NUMERIC), 5)
          ) as geom_pt
FROM whse_basemapping.fwa_stream_networks_sp s
WHERE s.blue_line_key = blkey
AND s.downstream_route_measure <= meas
ORDER BY s.downstream_route_measure desc
LIMIT 1),

wsd AS
(SELECT
  w.watershed_feature_id,
  w.geom
 FROM whse_basemapping.fwa_watersheds_poly w
 INNER JOIN local_segment ls ON ST_Intersects(w.geom, ls.geom_pt)
)

SELECT
  linear_feature_id,
  geom
from local_segment
UNION ALL
SELECT
  b.linear_feature_id,
  b.geom
FROM local_segment a
INNER JOIN whse_basemapping.fwa_stream_networks_sp b
-- not the same line
ON b.linear_feature_id != a.linear_feature_id
-- same watershed code
AND a.wscode_ltree = b.wscode_ltree
-- upstream
AND
 (
    (a.wscode_ltree = a.localcode_ltree AND
    b.wscode_ltree <@ a.wscode_ltree)
  OR
    (
      a.wscode_ltree != a.localcode_ltree
      AND
      b.wscode_ltree <@ a.wscode_ltree
      AND
      (
          (b.wscode_ltree > a.localcode_ltree AND NOT
           b.wscode_ltree <@ a.localcode_ltree)
          OR
          (b.wscode_ltree = a.wscode_ltree AND
          b.localcode_ltree >= a.localcode_ltree)
      )
     )
  OR
  (a.blue_line_key = b.blue_line_key AND
    b.downstream_route_measure > a.downstream_route_measure
  )
)
-- within same first order watershed as input location
INNER JOIN wsd
ON ST_Within(b.geom, ST_Buffer(wsd.geom, .1))

$$
language 'sql' immutable parallel safe;



CREATE FUNCTION fwa_watershedstream(blkey integer, meas integer)

RETURNS TABLE(linear_feature_id bigint, geom geometry)
AS


$$

WITH local_segment AS
(SELECT
  s.linear_feature_id,
  s.blue_line_key,
  meas as downstream_route_measure,
  s.wscode_ltree,
  s.localcode_ltree,
  ST_Force2D(
    ST_Multi(
      ST_LineSubstring((ST_Dump(s.geom)).geom,
                   ((meas - s.downstream_route_measure) / s.length_metre),
                   1)
                   )
  ) AS geom,
ST_LineInterpolatePoint(
      (ST_Dump(s.geom)).geom,
      ROUND(CAST((meas - s.downstream_route_measure) / s.length_metre AS NUMERIC), 5)
          ) as geom_pt
FROM whse_basemapping.fwa_stream_networks_sp s
WHERE s.blue_line_key = blkey
AND s.downstream_route_measure <= meas
ORDER BY s.downstream_route_measure desc
LIMIT 1),

wsd AS
(SELECT
  w.watershed_feature_id,
  w.geom
 FROM whse_basemapping.fwa_watersheds_poly w
 INNER JOIN local_segment ls ON ST_Intersects(w.geom, ls.geom_pt)
)

SELECT
  linear_feature_id,
  geom
from local_segment
UNION ALL
SELECT
  b.linear_feature_id,
  b.geom
FROM local_segment a
INNER JOIN whse_basemapping.fwa_stream_networks_sp b
-- not the same line
ON b.linear_feature_id != a.linear_feature_id
-- same watershed code
AND a.wscode_ltree = b.wscode_ltree
-- upstream
AND
 (
    (a.wscode_ltree = a.localcode_ltree AND
    b.wscode_ltree <@ a.wscode_ltree)
  OR
    (
      a.wscode_ltree != a.localcode_ltree
      AND
      b.wscode_ltree <@ a.wscode_ltree
      AND
      (
          (b.wscode_ltree > a.localcode_ltree AND NOT
           b.wscode_ltree <@ a.localcode_ltree)
          OR
          (b.wscode_ltree = a.wscode_ltree AND
          b.localcode_ltree >= a.localcode_ltree)
      )
     )
  OR
  (a.blue_line_key = b.blue_line_key AND
    b.downstream_route_measure > a.downstream_route_measure
  )
)
-- within same first order watershed as input location
INNER JOIN wsd
ON ST_Within(b.geom, ST_Buffer(wsd.geom, .1))

$$
language 'sql' immutable parallel safe;
