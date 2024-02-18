delete from whse_basemapping.fwa_watersheds_poly where watershed_group_code = :'wsg';

insert into whse_basemapping.fwa_watersheds_poly (
  watershed_feature_id,
  watershed_group_id,
  watershed_type,
  gnis_id_1,
  gnis_name_1,
  gnis_id_2,
  gnis_name_2,
  gnis_id_3,
  gnis_name_3,
  waterbody_id,
  waterbody_key,
  watershed_key,
  fwa_watershed_code,
  local_watershed_code,
  watershed_group_code,
  left_right_tributary,
  watershed_order,
  watershed_magnitude,
  local_watershed_order,
  local_watershed_magnitude,
  area_ha,
  river_area,
  lake_area,
  wetland_area,
  manmade_area,
  glacier_area,
  average_elevation,
  average_slope,
  aspect_north,
  aspect_south,
  aspect_west,
  aspect_east,
  aspect_flat,
  feature_code,
  geom
)
select
  watershed_feature_id::integer as watershed_feature_id,
  watershed_group_id::integer as watershed_group_id,
  watershed_type,
  gnis_id_1::integer as gnis_id_1,
  gnis_name_1,
  gnis_id_2::integer as gnis_id_2,
  gnis_name_2,
  gnis_id_3::integer as gnis_id_3,
  gnis_name_3,
  waterbody_id::integer as waterbody_id,
  waterbody_key::integer as waterbody_key,
  watershed_key::integer as watershed_key,
  fwa_watershed_code,
  local_watershed_code,
  watershed_group_code,
  left_right_tributary,
  watershed_order::integer as watershed_order,
  watershed_magnitude::integer as watershed_magnitude,
  local_watershed_order::integer as local_watershed_order,
  local_watershed_magnitude::integer as local_watershed_magnitude,
  area_ha::double precision as area_ha,
  river_area::double precision as river_area,
  lake_area::double precision as lake_area,
  wetland_area::double precision as wetland_area,
  manmade_area::double precision as manmade_area,
  glacier_area::double precision as glacier_area,
  average_elevation::double precision as average_elevation,
  average_slope::double precision as average_slope,
  aspect_north::double precision as aspect_north,
  aspect_south::double precision as aspect_south,
  aspect_west::double precision as aspect_west,
  aspect_east::double precision as aspect_east,
  aspect_flat::double precision as aspect_flat,
  feature_code,
  geom
from fwapg.fwa_watersheds_poly 
where watershed_group_code = :'wsg';
