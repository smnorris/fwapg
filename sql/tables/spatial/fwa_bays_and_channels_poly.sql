drop table if exists fwapg.fwa_bays_and_channels_poly;

create table if not exists fwapg.fwa_bays_and_channels_poly (
    bay_and_channel_id integer primary key,
    bay_channel_type character varying(14),
    gnis_id integer,
    gnis_name character varying(80),
    area_ha double precision,
    feature_code character varying(10),
    geom public.geometry(multipolygon,3005)
);

insert into fwapg.fwa_bays_and_channels_poly (
    bay_and_channel_id,
    bay_channel_type,
    gnis_id,
    gnis_name,
    area_ha,
    feature_code,
    geom
)
select
  (data -> 'properties' ->> 'BAY_AND_CHANNEL_ID')::integer as bay_and_channel_id,
  (data -> 'properties' ->> 'BAY_CHANNEL_TYPE') as bay_channel_type,
  (data -> 'properties' ->> 'GNIS_ID')::integer as gnis_id,
  (data -> 'properties' ->> 'GNIS_NAME') as gnis_name,
  (data -> 'properties' ->> 'AREA_HA')::double precision as area_ha,
  (data -> 'properties' ->> 'FEATURE_CODE') as feature_code,
  st_multi(ST_SetSRID(ST_GeomFromGeoJSON(data -> 'geometry'), 3005)) as geom
from fwapg.fwa_bays_and_channels_poly_load;

create index on fwapg.fwa_bays_and_channels_poly (gnis_name);
create index on fwapg.fwa_bays_and_channels_poly using gist(geom);