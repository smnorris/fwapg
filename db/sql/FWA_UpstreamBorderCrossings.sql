CREATE OR REPLACE FUNCTION whse_basemapping.FWA_UpstreamBorderCrossings(blkey integer, meas float)

RETURNS text

AS $$

WITH local_segment AS
(
  SELECT
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
  AND s.upstream_route_measure > meas
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
  ON FWA_Upstream(a.blue_line_key, a.downstream_route_measure, a.wscode_ltree, a.localcode_ltree,
                  b.blue_line_key, b.downstream_route_measure, b.wscode_ltree, b.localcode_ltree)
)

-- Return only one value - we don't currently do any thing different for ab vs yt/nwt so
-- there is no need to differentiate in event that a point has both borders upstream
SELECT border FROM
(
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
LIMIT 1) as f;


$$
language 'sql' immutable strict parallel safe;

COMMENT ON FUNCTION whse_basemapping.FWA_UpstreamBorderCrossings IS 'Provided a location as blue_line_key and downstream_route_measure, return border name if any streams upstream of the location intersect parallels 49/60 or longitude -120 ';
