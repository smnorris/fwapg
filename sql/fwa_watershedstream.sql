-- Given a point as a blue_line_key, route_measure, return
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
      ST_LocateBetween(s.geom, meas, s.upstream_route_measure)
    )
  ) AS geom,
  ST_LocateAlong(s.geom, meas) as geom_pt
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
  ST_Multi(geom) as geom
from local_segment
UNION ALL
SELECT
  b.linear_feature_id,
  ST_Multi(b.geom) as geom
FROM local_segment a
INNER JOIN whse_basemapping.fwa_stream_networks_sp b
ON
-- upstream, but not same blue_line_key
(
FWA_Upstream(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
-- not the same line or blue_line_key
AND b.linear_feature_id != a.linear_feature_id
AND b.blue_line_key != a.blue_line_key
-- same watershed code
AND a.wscode_ltree = b.wscode_ltree
-- not a side channel that may be downstream
AND b.localcode_ltree IS NOT NULL
)
-- or upstream on the same blueline
OR (b.blue_line_key = a.blue_line_key AND
b.downstream_route_measure > a.downstream_route_measure)

-- within same first order watershed as input location
INNER JOIN wsd
ON ST_Within(b.geom, ST_Buffer(wsd.geom, .1))

$$
language 'sql' immutable parallel safe;



