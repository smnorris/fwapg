CREATE OR REPLACE FUNCTION fwa_upstreambordercrossings(blkey integer, meas float)

RETURNS TABLE(border text, linear_feature_id bigint, geom geometry)  AS $$

WITH local_segment AS
(SELECT DISTINCT ON (blue_line_key)
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
  ) AS geom
FROM whse_basemapping.fwa_stream_networks_sp s
WHERE s.blue_line_key = blkey
AND s.downstream_route_measure <= meas + .01
ORDER BY s.blue_line_key, s.downstream_route_measure desc
),

upstream AS

(
  SELECT
    linear_feature_id,
    geom
  FROM local_segment

  UNION ALL

  SELECT
    b.linear_feature_id,
    b.geom
  FROM local_segment a
  INNER JOIN whse_basemapping.fwa_stream_networks_sp b
  ON
  -- upstream but
  -- not the same line or blue_line_key
  -- not a side channel that may be downstream
  (
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
    )
    AND b.linear_feature_id != a.linear_feature_id
    AND b.blue_line_key != a.blue_line_key
    AND b.localcode_ltree IS NOT NULL
  )
  -- upstream on the same blueline
  OR
  (
    b.blue_line_key = a.blue_line_key AND
    b.downstream_route_measure > a.downstream_route_measure
  )
)

SELECT
  b.border,
  s.linear_feature_id,
  CASE
    WHEN b.border = 'USA_49' THEN
      ST_ClosestPoint(
        ST_Translate(b.geom, 0, -50),
          ST_Intersection(s.geom, b.geom)
       )
    WHEN b.border = 'YTNWT_60' THEN
      ST_ClosestPoint(
        ST_Translate(b.geom, 0, 50),
          ST_Intersection(s.geom, b.geom)
       )
    WHEN b.border = 'AB_120' THEN
      ST_ClosestPoint(
        ST_Translate(b.geom, 50, 0),
          ST_Intersection(s.geom, b.geom)
       )
    END AS geom
FROM upstream s
INNER JOIN whse_basemapping.fwa_approx_borders b
ON ST_Intersects(s.geom, b.geom)

$$
language 'sql' immutable strict parallel safe;
