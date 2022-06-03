drop table if exists fwapg.fwa_linear_boundaries_sp;
create table fwapg.fwa_linear_boundaries_sp (
  linear_feature_id        integer primary key       ,
  watershed_group_id       integer not null          ,
  edge_type                integer                   ,
  waterbody_key            integer                   ,
  blue_line_key            integer                   ,
  watershed_key            integer                   ,
  fwa_watershed_code       character varying(143)    ,
  local_watershed_code     character varying(143)    ,
  watershed_group_code     character varying(4)      ,
  downstream_route_measure double precision          ,
  length_metre             double precision          ,
  feature_source           character varying         ,
  feature_code             character varying(10)     ,
  wscode_ltree ltree       generated always as
    (replace(replace(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) stored,
  localcode_ltree ltree    generated always as
    (replace(replace(local_watershed_code, '-000000', ''), '-', '.')::ltree) stored,
  geom                     public.geometry(MultiLineString,3005)
);

insert into fwapg.fwa_linear_boundaries_sp (
  linear_feature_id,
  watershed_group_id,
  edge_type,
  waterbody_key,
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
  linear_feature_id::integer,
  watershed_group_id::integer,
  edge_type,
  waterbody_key::integer,
  blue_line_key::integer,
  watershed_key::integer,
  fwa_watershed_code,
  local_watershed_code,
  watershed_group_code,
  downstream_route_measure::numeric,
  length_metre,
  feature_source,
  feature_code,
  st_multi(geom) as geom
from fwapg.fwa_linear_boundaries_sp_load;

-- index
create index on fwapg.fwa_linear_boundaries_sp (edge_type);
create index on fwapg.fwa_linear_boundaries_sp (blue_line_key);
create index on fwapg.fwa_linear_boundaries_sp (watershed_key);
create index on fwapg.fwa_linear_boundaries_sp (waterbody_key);
create index on fwapg.fwa_linear_boundaries_sp (watershed_group_code);
create index on fwapg.fwa_linear_boundaries_sp using gist (wscode_ltree);
create index on fwapg.fwa_linear_boundaries_sp using btree (wscode_ltree);
create index on fwapg.fwa_linear_boundaries_sp using gist (localcode_ltree);
create index on fwapg.fwa_linear_boundaries_sp using btree (localcode_ltree);
create index on fwapg.fwa_linear_boundaries_sp using gist (geom);