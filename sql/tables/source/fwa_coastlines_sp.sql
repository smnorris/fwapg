drop table if exists fwapg.fwa_coastlines_sp;

create table if not exists fwapg.fwa_coastlines_sp (
    linear_feature_id integer primary key,
    watershed_group_id integer,
    edge_type integer,
    blue_line_key integer,
    watershed_key integer,
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    watershed_group_code character varying(4),
    downstream_route_measure double precision,
    length_metre double precision,
    feature_source character varying(15),
    feature_code character varying(10),
    wscode_ltree public.ltree generated always as ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) stored,
    localcode_ltree public.ltree generated always as ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) stored,
    geom public.geometry(linestring,3005)
);

insert into fwapg.fwa_coastlines_sp (
  linear_feature_id,
  watershed_group_id,
  edge_type,
  blue_line_key,
  watershed_key,
  fwa_watershed_code,
  local_watershed_code,
  watershed_group_code,
  downstream_route_measure,
  length_metre,
  feature_source,
  feature_code,
  geom
)
select
  linear_feature_id,
  watershed_group_id,
  edge_type,
  blue_line_key,
  watershed_key,
  fwa_watershed_code,
  local_watershed_code,
  watershed_group_code,
  downstream_route_measure,
  length_metre,
  feature_source,
  feature_code,
  geom
from fwapg.fwa_coastlines_sp_load;

create index on fwapg.fwa_coastlines_sp (edge_type);
create index on fwapg.fwa_coastlines_sp (blue_line_key);
create index on fwapg.fwa_coastlines_sp (watershed_key);
create index on fwapg.fwa_coastlines_sp (watershed_group_code);
create index on fwapg.fwa_coastlines_sp using gist (wscode_ltree);
create index on fwapg.fwa_coastlines_sp using btree (wscode_ltree);
create index on fwapg.fwa_coastlines_sp using gist (localcode_ltree);
create index on fwapg.fwa_coastlines_sp using btree (localcode_ltree);
create index on fwapg.fwa_coastlines_sp using gist (geom);