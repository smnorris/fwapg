drop table if exists whse_basemapping.fwa_named_point_features_sp;

create table whse_basemapping.fwa_named_point_features_sp (
    named_point_feature_id integer primary key,
    gnis_id integer,
    gnis_name character varying(80),
    named_feature_type character varying(6),
    feature_code character varying(10),
    geom public.geometry(point, 3005)
);

insert into whse_basemapping.fwa_named_point_features_sp (
  named_point_feature_id,
  gnis_id,
  gnis_name,
  named_feature_type,
  feature_code,
  geom
)
select
  named_point_feature_id,
  gnis_id::integer,
  gnis_name,
  named_feature_type,
  feature_code,
  geom
from fwapg.fwa_named_point_features_sp;

create index on whse_basemapping.fwa_named_point_features_sp (gnis_name);
create index on whse_basemapping.fwa_named_point_features_sp using gist (geom);