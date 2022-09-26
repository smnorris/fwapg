delete from whse_basemapping.fwa_bays_and_channels_poly;

insert into whse_basemapping.fwa_bays_and_channels_poly (
    bay_and_channel_id,
    bay_channel_type,
    gnis_id,
    gnis_name,
    area_ha,
    feature_code,
    geom
)
select
  bay_and_channel_id::integer as bay_and_channel_id,
  bay_channel_type as bay_channel_type,
  gnis_id::integer as gnis_id,
  gnis_name as gnis_name,
  area_ha::double precision as area_ha,
  feature_code as feature_code,
  st_multi(geom) as geom
from fwapg.fwa_bays_and_channels_poly;
