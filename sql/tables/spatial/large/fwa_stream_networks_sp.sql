delete from whse_basemapping.fwa_stream_networks_sp where watershed_group_code = :'wsg';

insert into whse_basemapping.fwa_stream_networks_sp (linear_feature_id, watershed_group_id,
  edge_type, blue_line_key, watershed_key, fwa_watershed_code, local_watershed_code,
  watershed_group_code, downstream_route_measure, length_metre, feature_source, gnis_id, gnis_name,
  left_right_tributary, stream_order, stream_order_parent, stream_order_max, stream_magnitude, 
  waterbody_key, blue_line_key_50k, watershed_code_50k, watershed_key_50k, watershed_group_code_50k, 
  feature_code, geom)
select
  s.linear_feature_id::bigint as linear_feature_id,
  s.watershed_group_id::integer as watershed_group_id,
  s.edge_type::integer as edge_type,
  s.blue_line_key::integer as blue_line_key,
  s.watershed_key::integer as watershed_key,
  s.fwa_watershed_code,
  s.local_watershed_code,
  s.watershed_group_code,
  s.downstream_route_measure::double precision as downstream_route_measure,
  s.length_metre::double precision as length_metre,
  s.feature_source,
  s.gnis_id::integer as gnis_id,
  s.gnis_name,
  s.left_right_tributary,
  s.stream_order::integer as stream_order,
  p.stream_order_parent as stream_order_parent,
  m.stream_order_max as stream_order_max,
  s.stream_magnitude::integer as stream_magnitude,
  s.waterbody_key::integer as waterbody_key,
  s.blue_line_key_50k::integer as blue_line_key_50k,
  s.watershed_code_50k as watershed_code_50k,
  s.watershed_key_50k::integer as watershed_key_50k,
  s.watershed_group_code_50k,
  s.feature_code,
  st_addmeasure(
    (st_dump(s.geom)).geom, 
    s.downstream_route_measure::double precision, 
    s.downstream_route_measure::double precision + st_length((st_dump(s.geom)).geom)
  ) as geom
from fwapg.fwa_stream_networks_sp s
left outer join fwapg.fwa_stream_order_parent p on s.blue_line_key = p.blue_line_key
left outer join fwapg.fwa_stream_order_max m on s.blue_line_key = m.blue_line_key
where watershed_group_code = :'wsg'
order by random(); --https://blog.crunchydata.com/blog/tricks-for-faster-spatial-indexes