drop table if exists fwapg.fwa_glaciers_poly;

create table fwapg.fwa_glaciers_poly (
    waterbody_poly_id integer primary key,
    watershed_group_id integer,
    waterbody_type character varying(1),
    waterbody_key integer,
    area_ha double precision,
    gnis_id_1 integer,
    gnis_name_1 character varying(80),
    gnis_id_2 integer,
    gnis_name_2 character varying(80),
    gnis_id_3 integer,
    gnis_name_3 character varying(80),
    blue_line_key integer,
    watershed_key integer,
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    watershed_group_code character varying(4),
    left_right_tributary character varying(7),
    waterbody_key_50k integer,
    watershed_group_code_50k character varying(4),
    waterbody_key_group_code_50k character varying(55),
    watershed_code_50k character varying(45),
    feature_code character varying(10),
    wscode_ltree public.ltree generated always as ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) stored,
    localcode_ltree public.ltree generated always as ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) stored,
    geom public.geometry(multipolygon,3005)
);

insert into fwapg.fwa_glaciers_poly (
  waterbody_poly_id,
  watershed_group_id,
  waterbody_type,
  waterbody_key,
  area_ha,
  gnis_id_1,
  gnis_name_1,
  gnis_id_2,
  gnis_name_2,
  gnis_id_3,
  gnis_name_3,
  blue_line_key,
  watershed_key,
  fwa_watershed_code,
  local_watershed_code,
  watershed_group_code,
  left_right_tributary,
  waterbody_key_50k,
  watershed_group_code_50k,
  waterbody_key_group_code_50k,
  watershed_code_50k,
  feature_code,
  geom
)
select
  (data -> 'properties' ->> 'WATERBODY_POLY_ID')::integer as waterbody_poly_id,
  (data -> 'properties' ->> 'WATERSHED_GROUP_ID')::integer as watershed_group_id,
  (data -> 'properties' ->> 'WATERBODY_TYPE') as waterbody_type,
  (data -> 'properties' ->> 'WATERBODY_KEY')::integer as waterbody_key,
  (data -> 'properties' ->> 'AREA_HA')::double precision as area_ha,
  (data -> 'properties' ->> 'GNIS_ID_1')::integer as gnis_id_1,
  (data -> 'properties' ->> 'GNIS_NAME_1') as gnis_name_1,
  (data -> 'properties' ->> 'GNIS_ID_2')::integer as gnis_id_2,
  (data -> 'properties' ->> 'GNIS_NAME_2') as gnis_name_2,
  (data -> 'properties' ->> 'GNIS_ID_3')::integer as gnis_id_3,
  (data -> 'properties' ->> 'GNIS_NAME_3') as gnis_name_3,
  (data -> 'properties' ->> 'BLUE_LINE_KEY')::integer as blue_line_key,
  (data -> 'properties' ->> 'WATERSHED_KEY')::integer as watershed_key,
  (data -> 'properties' ->> 'FWA_WATERSHED_CODE') as fwa_watershed_code,
  (data -> 'properties' ->> 'LOCAL_WATERSHED_CODE') as local_watershed_code,
  (data -> 'properties' ->> 'WATERSHED_GROUP_CODE') as watershed_group_code,
  (data -> 'properties' ->> 'LEFT_RIGHT_TRIBUTARY') as left_right_tributary,
  (data -> 'properties' ->> 'WATERBODY_KEY_50K')::integer as waterbody_key_50k,
  (data -> 'properties' ->> 'WATERSHED_GROUP_CODE_50K') as watershed_group_code_50k,
  (data -> 'properties' ->> 'WATERBODY_KEY_GROUP_CODE_50K') as waterbody_key_group_code_50k,
  (data -> 'properties' ->> 'WATERSHED_CODE_50K') as watershed_code_50k,
  (data -> 'properties' ->> 'FEATURE_CODE') as feature_code,
  st_multi(ST_SetSRID(ST_GeomFromGeoJSON(data -> 'geometry'), 3005)) as geom
from fwapg.fwa_glaciers_poly_load;

create index on fwapg.fwa_glaciers_poly (blue_line_key);
create index on fwapg.fwa_glaciers_poly (watershed_key);
create index on fwapg.fwa_glaciers_poly (waterbody_key);
create index on fwapg.fwa_glaciers_poly (watershed_group_code);
create index on fwapg.fwa_glaciers_poly (gnis_name_1);
create index on fwapg.fwa_glaciers_poly using gist (wscode_ltree);
create index on fwapg.fwa_glaciers_poly using btree (wscode_ltree);
create index on fwapg.fwa_glaciers_poly using gist (localcode_ltree);
create index on fwapg.fwa_glaciers_poly using btree (localcode_ltree);
create index on fwapg.fwa_glaciers_poly using gist (geom);