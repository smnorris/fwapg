drop table if exists fwapg.fwa_watershed_groups_poly;

create table fwapg.fwa_watershed_groups_poly (
    watershed_group_id integer primary key,
    watershed_group_code character varying(4),
    watershed_group_name character varying(80),
    area_ha double precision,
    feature_code character varying(10),
    geom public.geometry(multipolygon,3005)
);

insert into fwapg.fwa_watershed_groups_poly (
  watershed_group_id,
  watershed_group_code,
  watershed_group_name,
  area_ha,
  feature_code,
  geom
)
select
  (data -> 'properties' ->> 'WATERSHED_GROUP_ID')::integer as watershed_group_id,
  (data -> 'properties' ->> 'WATERSHED_GROUP_CODE') as watershed_group_code,
  (data -> 'properties' ->> 'WATERSHED_GROUP_NAME') as watershed_group_name,
  (data -> 'properties' ->> 'AREA_HA')::double precision as area_ha,
  (data -> 'properties' ->> 'FEATURE_CODE') as feature_code,
  st_multi(ST_SetSRID(ST_GeomFromGeoJSON(data -> 'geometry'), 3005)) as geom
from fwapg.fwa_watershed_groups_poly_load;

create index on fwapg.fwa_watershed_groups_poly (watershed_group_code);
create index on fwapg.fwa_watershed_groups_poly using gist (geom);