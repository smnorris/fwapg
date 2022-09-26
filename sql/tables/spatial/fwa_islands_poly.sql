delete from whse_basemapping.fwa_islands_poly where watershed_group_code = :'wsg';
insert into fwapg.fwa_islands_poly (
  island_id,
  island_type,
  gnis_id_1,
  gnis_name_1,
  gnis_id_2,
  gnis_name_2,
  gnis_id_3,
  gnis_name_3,
  fwa_watershed_code,
  local_watershed_code,
  area_ha,
  feature_code,
  geom
)
select
  island_id::integer as island_id,
  island_type,
  gnis_id_1::integer as gnis_id_1,
  gnis_name_1,
  gnis_id_2::integer as gnis_id_2,
  gnis_name_2,
  gnis_id_3::integer as gnis_id_3,
  gnis_name_3,
  fwa_watershed_code,
  local_watershed_code,
  ble precision as area_ha,
  feature_code,
  st_multi(geom) as geom
from fwapg.fwa_islands_poly
watershed_group_code = :'wsg';

