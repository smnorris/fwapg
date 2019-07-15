CREATE OR REPLACE FUNCTION fwa_upstreambordercrossings(blkey integer, meas float)

RETURNS TABLE(border text, linear_feature_id bigint, geom geometry)  AS $$

WITH pt AS
(
SELECT DISTINCT ON (blue_line_key)
linear_feature_id,
blue_line_key,
wscode_ltree,
localcode_ltree,
downstream_route_measure,
length_metre
FROM whse_basemapping.fwa_stream_networks_sp
WHERE blue_line_key = blkey
AND downstream_route_measure <= meas +.01
ORDER BY blue_line_key, downstream_route_measure desc
)


SELECT
  b.border,
  s.linear_feature_id,
  ST_ClosestPoint(
    -- I am not sure why we shift the border down by 50m, one would think
    -- that this depends on which border is being considered?
    -- this likely only works on 49th parallel...
    ST_Translate(b.geom, 0, -50),
    ST_Intersection(s.geom, b.geom)
  ) as geom
FROM pt
INNER JOIN whse_basemapping.fwa_stream_networks_sp s
ON
(pt.wscode_ltree = pt.localcode_ltree AND
    s.wscode_ltree <@ pt.wscode_ltree)
  OR
    (
      pt.wscode_ltree != pt.localcode_ltree
      AND
      s.wscode_ltree <@ pt.wscode_ltree
      AND
      (

          (s.wscode_ltree > pt.localcode_ltree AND NOT
           s.wscode_ltree <@ pt.localcode_ltree)
          OR
          (s.wscode_ltree = pt.wscode_ltree AND
          s.localcode_ltree >= pt.localcode_ltree)

    )
    )
INNER JOIN whse_basemapping.fwa_approx_borders b
ON ST_Intersects(s.geom, b.geom)

$$
language 'sql' immutable strict parallel safe;
