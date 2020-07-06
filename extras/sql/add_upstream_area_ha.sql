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

INSERT INTO whse_basemapping.fwa_stream_networks_sp_tmp
(linear_feature_id, watershed_group_id,
  edge_type, blue_line_key, watershed_key, fwa_watershed_code, local_watershed_code,
  watershed_group_code, downstream_route_measure, length_metre, feature_source, gnis_id, gnis_name,
  left_right_tributary, stream_order, stream_magnitude, waterbody_key, blue_line_key_50k,
  watershed_code_50k, watershed_key_50k, watershed_group_code_50k, feature_code, upstream_area_ha, geom)
SELECT
  l.linear_feature_id,
  l.watershed_group_id,
  l.edge_type,
  l.blue_line_key,
  l.watershed_key,
  l.fwa_watershed_code,
  l.local_watershed_code,
  l.watershed_group_code,
  l.downstream_route_measure,
  l.length_metre,
  l.feature_source,
  l.gnis_id,
  l.gnis_name,
  l.left_right_tributary,
  l.stream_order,
  l.stream_magnitude,
  l.waterbody_key,
  l.blue_line_key_50k,
  l.watershed_code_50k,
  l.watershed_key_50k,
  l.watershed_group_code_50k,
  l.feature_code,
  upstr.upstream_area_ha,
  l.geom
FROM whse_basemapping.fwa_stream_networks_sp l
INNER JOIN upstr ON l.linear_feature_id = upstr.linear_feature_id;
