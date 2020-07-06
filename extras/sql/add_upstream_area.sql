WITH upstr as
(SELECT
  s.linear_feature_id,
  SUM(ST_Area(w.geom)) / 10000 as upstream_area_ha
FROM whse_basemapping.fwa_stream_networks_sp s
INNER JOIN whse_basemapping.fwa_watersheds_poly w
ON FWA_Upstream(s.wscode_ltree, s.localcode_ltree, w.wscode_ltree, w.localcode_ltree)
AND s.localcode_ltree != w.localcode_ltree
WHERE s.watershed_group_code = %s
GROUP BY s.linear_feature_id)

UPDATE whse_basemapping.fwa_stream_networks_sp a
SET upstream_area_ha = upstr.upstream_area_ha
FROM upstr
WHERE a.linear_feature_id = upstr.linear_feature_id;