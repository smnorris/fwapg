-- Provided a location as blue_line_key and downstream_route_measure,
-- return upstream stream segments within the same first order watershed

-- Typical use is for generating pour 'points' (linear pour points as per
-- https://pro.arcgis.com/en/pro-app/tool-reference/spatial-analyst/watershed.htm)

CREATE OR REPLACE FUNCTION whse_basemapping.FWA_WatershedStream(blue_line_key integer, downstream_route_measure float)

RETURNS TABLE(linear_feature_id bigint, geom geometry)
AS


$$

declare
   v_blkey    integer := blue_line_key;
   v_measure  float := downstream_route_measure;


begin

return query

WITH local_segment AS
(SELECT
  s.linear_feature_id,
  s.blue_line_key,
  v_measure as measure,
  s.wscode_ltree,
  s.localcode_ltree,
  ST_Force2D(
    ST_Multi(
      ST_LocateBetween(s.geom, v_measure, s.upstream_route_measure)
    )
  ) AS geom,
  ST_LocateAlong(s.geom, v_measure) as geom_pt
FROM whse_basemapping.fwa_stream_networks_sp s
WHERE s.blue_line_key = v_blkey
AND s.downstream_route_measure <= v_measure
AND s.upstream_route_measure > v_measure
),

wsd AS
(SELECT
  w.watershed_feature_id,
  w.geom
 FROM whse_basemapping.fwa_watersheds_poly w
 INNER JOIN local_segment ls ON ST_Intersects(w.geom, ls.geom_pt)
)

SELECT
  ls.linear_feature_id,
  ST_Multi(ls.geom) as geom
from local_segment ls
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
b.downstream_route_measure > a.measure)

-- within same first order watershed as input location
INNER JOIN wsd
ON ST_Within(b.geom, ST_Buffer(wsd.geom, .1));

end

$$
language 'plpgsql' immutable parallel safe;

COMMENT ON FUNCTION whse_basemapping.fwa_watershedstream IS 'Provided a location as blue_line_key and downstream_route_measure, return stream segments upstream, within the same first order watershed.';
