insert into whse_basemapping.fwa_coastlines_sp (
  linear_feature_id,
  watershed_group_id,
  edge_type,
  blue_line_key,
  watershed_key,
  fwa_watershed_code,
  local_watershed_code,
  watershed_group_code,
  downstream_route_measure,
  length_metre,
  feature_source,
  feature_code,
  geom
)
select
  linear_feature_id,
  watershed_group_id,
  edge_type,
  blue_line_key,
  watershed_key,
  fwa_watershed_code,
  local_watershed_code,
  watershed_group_code,
  downstream_route_measure,
  length_metre,
  feature_source,
  feature_code,
  ST_SetSRID(geom, 3005) as geom
from fwapg.fwa_coastlines_sp
where watershed_group_code = :'wsg';
