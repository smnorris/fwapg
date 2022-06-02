drop table if exists whse_basemapping.fwa_stream_networks_sp;

create table whse_basemapping.fwa_stream_networks_sp (
  linear_feature_id bigint primary key,
  watershed_group_id integer not null,
  edge_type integer not null,
  blue_line_key integer not null,
  watershed_key integer not null,
  fwa_watershed_code character varying(143) not null,
  local_watershed_code character varying(143),
  watershed_group_code character varying(4) not null,
  downstream_route_measure double precision not null,
  length_metre double precision not null,
  feature_source character varying(15),
  gnis_id integer,
  gnis_name character varying(80),
  left_right_tributary character varying(7),
  stream_order integer,
  stream_magnitude integer,
  waterbody_key integer,
  blue_line_key_50k integer,
  watershed_code_50k character varying(45),
  watershed_key_50k integer,
  watershed_group_code_50k character varying(4),
  gradient double precision generated always as (round((((st_z (st_pointn (geom, - 1)) - st_z
    (st_pointn (geom, 1))) / st_length (geom))::numeric), 4)) stored,
  feature_code character varying(10),
  wscode_ltree ltree generated always as (replace(replace(fwa_watershed_code,
    '-000000', ''), '-', '.')::ltree) stored,
  localcode_ltree ltree generated always as
    (replace(replace(local_watershed_code, '-000000', ''), '-', '.')::ltree) stored,
  upstream_route_measure double precision generated always as (downstream_route_measure +
    st_length (geom)) stored,
  geom public.geometry(linestringzm, 3005)
);

insert into whse_basemapping.fwa_stream_networks_sp (linear_feature_id, watershed_group_id,
  edge_type, blue_line_key, watershed_key, fwa_watershed_code, local_watershed_code,
  watershed_group_code, downstream_route_measure, length_metre, feature_source, gnis_id, gnis_name,
  left_right_tributary, stream_order, stream_magnitude, waterbody_key, blue_line_key_50k,
  watershed_code_50k, watershed_key_50k, watershed_group_code_50k, feature_code, geom)
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
  gnis_id,
  gnis_name,
  left_right_tributary,
  stream_order,
  stream_magnitude,
  waterbody_key,
  blue_line_key_50k,
  watershed_code_50k,
  watershed_key_50k,
  watershed_group_code_50k,
  feature_code,
  st_addmeasure (geom, downstream_route_measure, downstream_route_measure + st_length (geom)) as geom
from fwapg.fwa_stream_networks_sp
order by random(); --https://blog.crunchydata.com/blog/tricks-for-faster-spatial-indexes

-- create the necessary indices
create index on whse_basemapping.fwa_stream_networks_sp (edge_type);
create index on whse_basemapping.fwa_stream_networks_sp (blue_line_key);
create index on whse_basemapping.fwa_stream_networks_sp (blue_line_key, downstream_route_measure);
create index on whse_basemapping.fwa_stream_networks_sp (watershed_key);
create index on whse_basemapping.fwa_stream_networks_sp (waterbody_key);
create index on whse_basemapping.fwa_stream_networks_sp (watershed_group_code);
create index on whse_basemapping.fwa_stream_networks_sp (gnis_name);
create index fwa_stream_networks_sp_wscode_ltree_gist_idx on whse_basemapping.fwa_stream_networks_sp using gist (wscode_ltree);
create index on whse_basemapping.fwa_stream_networks_sp using btree (wscode_ltree);
create index on whse_basemapping.fwa_stream_networks_sp using gist (localcode_ltree);
create index on whse_basemapping.fwa_stream_networks_sp using btree (localcode_ltree);
create index on whse_basemapping.fwa_stream_networks_sp using gist (geom);