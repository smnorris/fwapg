delete from whse_basemapping.fwa_named_watersheds_poly;

insert into whse_basemapping.fwa_named_watersheds_poly (
  named_watershed_id,
  gnis_id,
  gnis_name,
  blue_line_key,
  watershed_key,
  fwa_watershed_code,
  stream_order,
  stream_magnitude,
  area_ha,
  feature_code,
  geom
)
select
  named_watershed_id::integer as named_watershed_id,
  gnis_id::integer as gnis_id,
  gnis_name,
  blue_line_key::integer as blue_line_key,
  watershed_key::integer as watershed_key,
  fwa_watershed_code,
  stream_order::integer as stream_order,
  stream_magnitude::integer as stream_magnitude,
  area_ha::double precision as area_ha,
  feature_code,
  geom
from fwapg.fwa_named_watersheds_poly;
