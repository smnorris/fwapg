drop table if exists fwapg.fwa_stream_networks_sp;

create table fwapg.fwa_stream_networks_sp (
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

insert into fwapg.fwa_stream_networks_sp (linear_feature_id, watershed_group_id,
  edge_type, blue_line_key, watershed_key, fwa_watershed_code, local_watershed_code,
  watershed_group_code, downstream_route_measure, length_metre, feature_source, gnis_id, gnis_name,
  left_right_tributary, stream_order, stream_magnitude, waterbody_key, blue_line_key_50k,
  watershed_code_50k, watershed_key_50k, watershed_group_code_50k, feature_code, geom)
select
  (data -> 'properties' ->> 'LINEAR_FEATURE_ID')::bigint as linear_feature_id,
  (data -> 'properties' ->> 'WATERSHED_GROUP_ID')::integer as watershed_group_id,
  (data -> 'properties' ->> 'EDGE_TYPE')::integer as edge_type,
  (data -> 'properties' ->> 'BLUE_LINE_KEY')::integer as blue_line_key,
  (data -> 'properties' ->> 'WATERSHED_KEY')::integer as watershed_key,
  (data -> 'properties' ->> 'FWA_WATERSHED_CODE') as fwa_watershed_code,
  (data -> 'properties' ->> 'LOCAL_WATERSHED_CODE') as local_watershed_code,
  (data -> 'properties' ->> 'WATERSHED_GROUP_CODE') as watershed_group_code,
  (data -> 'properties' ->> 'DOWNSTREAM_ROUTE_MEASURE')::double precision as downstream_route_measure,
  (data -> 'properties' ->> 'LENGTH_METRE')::double precision as length_metre,
  (data -> 'properties' ->> 'FEATURE_SOURCE') as feature_source,
  (data -> 'properties' ->> 'GNIS_ID')::integer as gnis_id,
  (data -> 'properties' ->> 'GNIS_NAME') as gnis_name,
  (data -> 'properties' ->> 'LEFT_RIGHT_TRIBUTARY') as left_right_tributary,
  (data -> 'properties' ->> 'STREAM_ORDER')::integer as stream_order,
  (data -> 'properties' ->> 'STREAM_MAGNITUDE')::integer as stream_magnitude,
  (data -> 'properties' ->> 'WATERBODY_KEY')::integer as waterbody_key,
  (data -> 'properties' ->> 'BLUE_LINE_KEY_50K')::integer as blue_line_key_50k,
  (data -> 'properties' ->> 'WATERSHED_CODE_50K') as watershed_code_50k,
  (data -> 'properties' ->> 'WATERSHED_KEY_50K')::integer as watershed_key_50k,
  (data -> 'properties' ->> 'WATERSHED_GROUP_CODE_50K') as watershed_group_code_50k,
  (data -> 'properties' ->> 'FEATURE_CODE') as feature_code,
  st_addmeasure((ST_SetSRID(ST_GeomFromGeoJSON(data -> 'geometry'), 3005)), (data -> 'properties' ->> 'DOWNSTREAM_ROUTE_MEASURE')::double precision, (data -> 'properties' ->> 'DOWNSTREAM_ROUTE_MEASURE')::double precision + st_length(ST_SetSRID(ST_GeomFromGeoJSON(data -> 'geometry'), 3005))) as geom
from fwapg.fwa_stream_networks_sp_load
order by random(); --https://blog.crunchydata.com/blog/tricks-for-faster-spatial-indexes

-- create the necessary indices
create index on fwapg.fwa_stream_networks_sp (edge_type);
create index on fwapg.fwa_stream_networks_sp (blue_line_key);
create index on fwapg.fwa_stream_networks_sp (blue_line_key, downstream_route_measure);
create index on fwapg.fwa_stream_networks_sp (watershed_key);
create index on fwapg.fwa_stream_networks_sp (waterbody_key);
create index on fwapg.fwa_stream_networks_sp (watershed_group_code);
create index on fwapg.fwa_stream_networks_sp (gnis_name);
create index fwa_stream_networks_sp_wscode_ltree_gist_idx on fwapg.fwa_stream_networks_sp using gist (wscode_ltree);
create index on fwapg.fwa_stream_networks_sp using btree (wscode_ltree);
create index on fwapg.fwa_stream_networks_sp using gist (localcode_ltree);
create index on fwapg.fwa_stream_networks_sp using btree (localcode_ltree);
create index on fwapg.fwa_stream_networks_sp using gist (geom);