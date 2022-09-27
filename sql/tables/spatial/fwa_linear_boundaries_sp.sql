delete from whse_basemapping.fwa_linear_boundaries_sp where watershed_group_code = :'wsg';

insert into whse_basemapping.fwa_linear_boundaries_sp (
  linear_feature_id,
  watershed_group_id,
  edge_type,
  waterbody_key,
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
  linear_feature_id::integer as linear_feature_id,
  watershed_group_id::integer as watershed_group_id,
  edge_type::integer as edge_type,
  waterbody_key::integer as waterbody_key,
  blue_line_key::integer as blue_line_key,
  watershed_key::integer as watershed_key,
  fwa_watershed_code as fwa_watershed_code,
  local_watershed_code as local_watershed_code,
  watershed_group_code as watershed_group_code,
  downstream_route_measure::double precision as downstream_route_measure,
  length_metre::double precision as length_metre,
  feature_source,
  feature_code,
  geom
from fwapg.fwa_linear_boundaries_sp
where watershed_group_code = :'wsg';

