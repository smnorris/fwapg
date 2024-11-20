create view whse_basemapping.fwa_streams_vw as
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

comment on view whse_basemapping.fwa_streams_vw is 'View of FWA stream networks and value-added attributes';
comment on column whse_basemapping.fwa_streams_vw.linear_feature_id is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams_vw.edge_type is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams_vw.blue_line_key is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams_vw.watershed_key is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams_vw.wscode is 'FWA watershed code as postgres ltree type, with trailing -000000 strings removed';
comment on column whse_basemapping.fwa_streams_vw.localcode is 'FWA local watershed code as postgres ltree type, with trailing -000000 strings removed';
comment on column whse_basemapping.fwa_streams_vw.watershed_group_code is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams_vw.downstream_route_measure is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams_vw.upstream_route_measure is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams_vw.length_metre is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams_vw.waterbody_key is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams_vw.gnis_name is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams_vw.stream_order is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams_vw.stream_magnitude is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams_vw.feature_code is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams_vw.gradient is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams_vw.left_right_tributary is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams_vw.stream_order_parent is 'Stream order of parent stream at confluence with stream having `blue_line_key` of the stream segment';
comment on column whse_basemapping.fwa_streams_vw.stream_order_max is 'Maxiumum order of the stream with equivalent `blue_line_key` as given segment)';
comment on column whse_basemapping.fwa_streams_vw.upstream_area_ha is 'Area (ha) upstream of the stream segment (including all fundamental watersheds with equivalent watershed code)';
comment on column whse_basemapping.fwa_streams_vw.map_upstream is 'Area weighted average mean annual precipitation upstream of the stream segment, source ClimateBC';
comment on column whse_basemapping.fwa_streams_vw.channel_width is 'Channel width of the stream segment in metres, with source as per channel_width_source';
comment on column whse_basemapping.fwa_streams_vw.channel_width_source is 'Data source for channel_width at given segment, with values (FIELD_MEASURMENT, FWA_RIVERS_POLY, MODELLED). FIELD_MEASUREMENT is derived from PSCIS and FISS data, MODELLED is taken from Thorley et al, 2021';
comment on column whse_basemapping.fwa_streams_vw.mad_m3s is 'Modelled mean annual discharge at the stream segment (Pacific Climate Impacts Consortium, University of Victoria, (January 2020) VIC-GL BCCAQ CMIP5: Gridded Hydrologic Model Output)';