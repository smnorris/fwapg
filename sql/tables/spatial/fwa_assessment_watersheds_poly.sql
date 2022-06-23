drop table if exists fwapg.fwa_assessment_watersheds_poly;

create table fwapg.fwa_assessment_watersheds_poly (
    watershed_feature_id integer primary key,
    watershed_group_id integer,
    watershed_type character varying(1),
    gnis_id_1 integer,
    gnis_name_1 character varying(80),
    gnis_id_2 integer,
    gnis_name_2 character varying(80),
    gnis_id_3 integer,
    gnis_name_3 character varying(80),
    waterbody_id bigint,
    waterbody_key bigint,
    watershed_key bigint,
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    watershed_group_code character varying(4),
    left_right_tributary character varying(7),
    watershed_order integer,
    watershed_magnitude integer,
    local_watershed_order integer,
    local_watershed_magnitude integer,
    area_ha double precision,
    feature_code character varying(10),
    wscode_ltree public.ltree generated always as ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) stored,
    localcode_ltree public.ltree generated always as ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) stored,
    geom public.geometry(multipolygon, 3005)
);

-- load the data
insert into fwapg.fwa_assessment_watersheds_poly
  (
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
    feature_code,
    geom)
select
    (data -> 'properties' ->> 'WATERSHED_FEATURE_ID')::integer watershed_feature_id,
    (data -> 'properties' ->> 'WATERSHED_GROUP_ID')::integer watershed_group_id,
    (data -> 'properties' ->> 'WATERSHED_TYPE') watershed_type,
    (data -> 'properties' ->> 'GNIS_ID_1')::integer gnis_id_1,
    (data -> 'properties' ->> 'GNIS_NAME_1') gnis_name_1,
    (data -> 'properties' ->> 'GNIS_ID_2')::integer gnis_id_2,
    (data -> 'properties' ->> 'GNIS_NAME_2') gnis_name_2,
    (data -> 'properties' ->> 'GNIS_ID_3')::integer gnis_id_3,
    (data -> 'properties' ->> 'GNIS_NAME_3') gnis_name_3,
    (data -> 'properties' ->> 'WATERBODY_ID')::bigint waterbody_id,
    (data -> 'properties' ->> 'WATERBODY_KEY')::bigint waterbody_key,
    (data -> 'properties' ->> 'WATERSHED_KEY')::integer watershed_key,
    (data -> 'properties' ->> 'FWA_WATERSHED_CODE') fwa_watershed_code,
    (data -> 'properties' ->> 'LOCAL_WATERSHED_CODE') local_watershed_code,
    (data -> 'properties' ->> 'WATERSHED_GROUP_CODE') watershed_group_code,
    (data -> 'properties' ->> 'LEFT_RIGHT_TRIBUTARY') left_right_tributary,
    (data -> 'properties' ->> 'WATERSHED_ORDER')::integer watershed_order,
    (data -> 'properties' ->> 'WATERSHED_MAGNITUDE')::integer watershed_magnitude,
    (data -> 'properties' ->> 'LOCAL_WATERSHED_ORDER')::integer local_watershed_order,
    (data -> 'properties' ->> 'LOCAL_WATERSHED_MAGNITUDE')::integer local_watershed_magnitude,
    (data -> 'properties' ->> 'AREA_HA')::double precision area_ha,
    (data -> 'properties' ->> 'FEATURE_CODE') feature_code,
    st_multi(ST_SetSRID(ST_GeomFromGeoJSON(data -> 'geometry'), 3005)) as geom
from fwapg.fwa_assessment_watersheds_poly_load;

create index on fwapg.fwa_assessment_watersheds_poly (watershed_group_code);
create index on fwapg.fwa_assessment_watersheds_poly (gnis_name_1);
create index on fwapg.fwa_assessment_watersheds_poly (waterbody_id);
create index on fwapg.fwa_assessment_watersheds_poly (waterbody_key);
create index on fwapg.fwa_assessment_watersheds_poly (watershed_key);
create index on fwapg.fwa_assessment_watersheds_poly using gist (wscode_ltree);
create index on fwapg.fwa_assessment_watersheds_poly using btree (wscode_ltree);
create index on fwapg.fwa_assessment_watersheds_poly using gist (localcode_ltree);
create index on fwapg.fwa_assessment_watersheds_poly using btree (localcode_ltree);
create index on fwapg.fwa_assessment_watersheds_poly using gist(geom);