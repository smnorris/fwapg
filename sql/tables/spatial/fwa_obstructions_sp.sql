drop table if exists fwapg.fwa_obstructions_sp;

create table fwapg.fwa_obstructions_sp (
    obstruction_id integer primary key,
    watershed_group_id integer,
    linear_feature_id integer,
    gnis_id integer,
    gnis_name character varying(80),
    obstruction_type character varying(20),
    blue_line_key integer,
    watershed_key integer,
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    watershed_group_code character varying(4),
    route_measure double precision,
    feature_source character varying(15),
    feature_code character varying(10),
    wscode_ltree public.ltree generated always as ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) stored,
    localcode_ltree public.ltree generated always as ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) stored,
    geom public.geometry(point,3005)
);

insert into fwapg.fwa_obstructions_sp (
  obstruction_id,
  watershed_group_id,
  linear_feature_id,
  gnis_id,
  gnis_name,
  obstruction_type,
  blue_line_key,
  watershed_key,
  fwa_watershed_code,
  local_watershed_code,
  watershed_group_code,
  route_measure,
  feature_source,
  feature_code,
  geom
)
select
  (data -> 'properties' ->> 'OBSTRUCTION_ID')::integer as obstruction_id,
  (data -> 'properties' ->> 'WATERSHED_GROUP_ID')::integer as watershed_group_id,
  (data -> 'properties' ->> 'LINEAR_FEATURE_ID')::integer as linear_feature_id,
  (data -> 'properties' ->> 'GNIS_ID')::integer as gnis_id,
  (data -> 'properties' ->> 'GNIS_NAME') as gnis_name,
  (data -> 'properties' ->> 'OBSTRUCTION_TYPE') as obstruction_type,
  (data -> 'properties' ->> 'BLUE_LINE_KEY')::integer as blue_line_key,
  (data -> 'properties' ->> 'WATERSHED_KEY')::integer as watershed_key,
  (data -> 'properties' ->> 'FWA_WATERSHED_CODE') as fwa_watershed_code,
  (data -> 'properties' ->> 'LOCAL_WATERSHED_CODE') as local_watershed_code,
  (data -> 'properties' ->> 'WATERSHED_GROUP_CODE') as watershed_group_code,
  (data -> 'properties' ->> 'ROUTE_MEASURE')::double precision as route_measure,
  (data -> 'properties' ->> 'FEATURE_SOURCE') as feature_source,
  (data -> 'properties' ->> 'FEATURE_CODE') as feature_code,
  ST_SetSRID(ST_GeomFromGeoJSON(data -> 'geometry'), 3005) as geom
from fwapg.fwa_obstructions_sp_load;

create index on fwapg.fwa_obstructions_sp (linear_feature_id);
create index on fwapg.fwa_obstructions_sp (blue_line_key);
create index on fwapg.fwa_obstructions_sp (watershed_key);
create index on fwapg.fwa_obstructions_sp (obstruction_type);
create index on fwapg.fwa_obstructions_sp (watershed_group_code);
create index on fwapg.fwa_obstructions_sp (gnis_name);
create index on fwapg.fwa_obstructions_sp using gist (wscode_ltree);
create index on fwapg.fwa_obstructions_sp using btree (wscode_ltree);
create index on fwapg.fwa_obstructions_sp using gist (localcode_ltree);
create index on fwapg.fwa_obstructions_sp using btree (localcode_ltree);
create index on fwapg.fwa_obstructions_sp using gist (geom);