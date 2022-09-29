insert into whse_basemapping.fwa_watershed_groups_poly (
  watershed_group_id,
  watershed_group_code,
  watershed_group_name,
  area_ha,
  feature_code,
  geom
)
select
  watershed_group_id::integer as watershed_group_id,
  watershed_group_code,
  watershed_group_name,
  area_ha::double precision as area_ha,
  feature_code,
  geom
from fwapg.fwa_watershed_groups_poly;

