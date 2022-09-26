delete from whse_basemapping.fwa_stream_networks_sp where watershed_group_code = :'wsg';

insert into whse_basemapping.fwa_stream_networks_sp (linear_feature_id, watershed_group_id,
  edge_type, blue_line_key, watershed_key, fwa_watershed_code, local_watershed_code,
  watershed_group_code, downstream_route_measure, length_metre, feature_source, gnis_id, gnis_name,
  left_right_tributary, stream_order, stream_magnitude, waterbody_key, blue_line_key_50k,
  watershed_code_50k, watershed_key_50k, watershed_group_code_50k, feature_code, geom)
select
  linear_feature_id::bigint as linear_feature_id,
  watershed_group_id::integer as watershed_group_id,
  edge_type::integer as edge_type,
  blue_line_key::integer as blue_line_key,
  watershed_key::integer as watershed_key,
  fwa_watershed_code,
  local_watershed_code,
  watershed_group_code,
  downstream_route_measure::double precision as downstream_route_measure,
  length_metre::double precision as length_metre,
  feature_source,
  gnis_id::integer as gnis_id,
  gnis_name,
  left_right_tributary,
  stream_order::integer as stream_order,
  stream_magnitude::integer as stream_magnitude,
  waterbody_key::integer as waterbody_key,
  blue_line_key_50k::integer as blue_line_key_50k,
  watershed_code_50k as watershed_code_50k,
  watershed_key_50k::integer as watershed_key_50k,
  watershed_group_code_50k,
  feature_code,
  st_addmeasure(
    (st_dump(geom)).geom, 
    downstream_route_measure::double precision, 
    downstream_route_measure::double precision + st_length((st_dump(geom)).geom)
  ) as geom
from fwapg.fwa_stream_networks_sp
where watershed_group_code = :'wsg'
order by random(); --https://blog.crunchydata.com/blog/tricks-for-faster-spatial-indexes