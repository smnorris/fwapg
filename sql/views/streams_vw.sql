drop view if exists whse_basemapping.fwa_streams_vw;

create or replace view whse_basemapping.fwa_streams_vw as
  SELECT
  s.linear_feature_id,
  s.edge_type,
  s.blue_line_key,
  s.watershed_key,
  s.wscode_ltree as wscode,
  s.localcode_ltree as localcode,
  s.watershed_group_code,
  s.downstream_route_measure,
  s.upstream_route_measure,
  s.length_metre,
  s.waterbody_key,
  s.gnis_name,
  s.stream_order,
  s.stream_magnitude,
  s.feature_code,
  s.gradient,
  s.stream_order_parent,
  s.stream_order_max,
  ua.upstream_area_ha,
  p.map_upstream,
  cw.channel_width,
  mad.mad_m3s,
  s.geom
FROM whse_basemapping.fwa_stream_networks_sp s
LEFT OUTER JOIN whse_basemapping.fwa_streams_watersheds_lut l
ON s.linear_feature_id = l.linear_feature_id
INNER JOIN whse_basemapping.fwa_watersheds_upstream_area ua
ON l.watershed_feature_id = ua.watershed_feature_id
LEFT OUTER JOIN bcfishpass.mean_annual_precip p ON s.wscode_ltree = p.wscode_ltree AND s.localcode_ltree = p.localcode_ltree
LEFT OUTER JOIN bcfishpass.channel_width cw ON s.linear_feature_id = cw.linear_feature_id
LEFT OUTER JOIN bcfishpass.discharge mad ON s.linear_feature_id = mad.linear_feature_id;