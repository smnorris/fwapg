drop table if exists fwapg.fwa_named_point_features_sp;

create table fwapg.fwa_named_point_features_sp (
    named_point_feature_id integer primary key,
    gnis_id integer,
    gnis_name character varying(80),
    named_feature_type character varying(6),
    feature_code character varying(10),
    geom public.geometry(point, 3005)
);

insert into fwapg.fwa_named_point_features_sp (
  named_point_feature_id,
  gnis_id,
  gnis_name,
  named_feature_type,
  feature_code,
  geom
)
select
  (data -> 'properties' ->> 'NAMED_POINT_FEATURE_ID')::integer as named_point_feature_id,
  (data -> 'properties' ->> 'GNIS_ID')::integer as gnis_id,
  data -> 'properties' ->> 'GNIS_NAME' as gnis_name,
  data -> 'properties' ->> 'NAMED_FEATURE_TYPE' as named_feature_type,
  data -> 'properties' ->> 'FEATURE_CODE' as feature_code,
  ST_SetSRID(ST_GeomFromGeoJSON(data -> 'geometry'), 3005) as geom
from fwapg.fwa_named_point_features_sp_load;

create index on fwapg.fwa_named_point_features_sp (gnis_name);
create index on fwapg.fwa_named_point_features_sp using gist (geom);