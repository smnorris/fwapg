UPDATE
  whse_basemapping.fwa_stream_networks_sp s
SET
  upstream_lake_ha  = t.upstream_lake_ha,
  upstream_reservoir_ha  = t.upstream_reservoir_ha,
  upstream_wetland_ha = t.upstream_wetland_ha
FROM whse_basemapping.temp_upstream_wb_area_ha t
WHERE s.linear_feature_id = t.linear_feature_id
AND s.watershed_group_code = %s
