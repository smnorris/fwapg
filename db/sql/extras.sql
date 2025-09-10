insert into whse_basemapping.fwa_streams (
  linear_feature_id,
  edge_type,
  blue_line_key,
  watershed_key,
  wscode,
  localcode,
  watershed_group_code,
  downstream_route_measure,
  upstream_route_measure,
  length_metre,
  waterbody_key,
  gnis_name,
  stream_order,
  stream_magnitude,
  feature_code,
  gradient,
  left_right_tributary,
  stream_order_parent,
  stream_order_max,
  upstream_area_ha,
  map_upstream,
  channel_width,
  channel_width_source,
  mad_m3s,
  geom
)
select
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
  s.left_right_tributary,
  op.stream_order_parent,
  om.stream_order_max,
  ua.upstream_area_ha,
  p.map_upstream,
  cw.channel_width,
  cw.channel_width_source,
  mad.mad_m3s,
  s.geom
from whse_basemapping.fwa_stream_networks_sp s
left outer join whse_basemapping.fwa_streams_watersheds_lut l on s.linear_feature_id = l.linear_feature_id
inner join whse_basemapping.fwa_watersheds_upstream_area ua on l.watershed_feature_id = ua.watershed_feature_id
left outer join whse_basemapping.fwa_stream_networks_order_parent op on s.blue_line_key = op.blue_line_key
left outer join whse_basemapping.fwa_stream_networks_order_max om on s.blue_line_key = om.blue_line_key
left outer join whse_basemapping.fwa_stream_networks_mean_annual_precip p on s.wscode_ltree = p.wscode_ltree and s.localcode_ltree = p.localcode_ltree
left outer join whse_basemapping.fwa_stream_networks_channel_width cw on s.linear_feature_id = cw.linear_feature_id
left outer join whse_basemapping.fwa_stream_networks_discharge mad on s.linear_feature_id = mad.linear_feature_id;