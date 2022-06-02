drop table if exists whse_basemapping.fwa_bays_and_channels_poly;

create table if not exists whse_basemapping.fwa_bays_and_channels_poly (
    bay_and_channel_id integer primary key,
    bay_channel_type character varying(14),
    gnis_id integer,
    gnis_name character varying(80),
    area_ha double precision,
    feature_code character varying(10),
    geom public.geometry(multipolygon,3005)
);

insert into whse_basemapping.fwa_bays_and_channels_poly (
    bay_and_channel_id,
    bay_channel_type,
    gnis_id,
    gnis_name,
    area_ha,
    feature_code,
    geom
)
select    bay_and_channel_id,
    bay_channel_type,
    gnis_id,
    gnis_name,
    area_ha,
    feature_code,
    st_multi(geom) as geom
from fwapg.fwa_bays_and_channels_poly;

create index on whse_basemapping.fwa_bays_and_channels_poly (gnis_name);
create index on whse_basemapping.fwa_bays_and_channels_poly using gist(geom);