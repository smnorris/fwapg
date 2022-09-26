drop table if exists whse_basemapping.fwa_assessment_watersheds_poly;

create table whse_basemapping.fwa_assessment_watersheds_poly (
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

create index on whse_basemapping.fwa_assessment_watersheds_poly (watershed_group_code);
create index on whse_basemapping.fwa_assessment_watersheds_poly (gnis_name_1);
create index on whse_basemapping.fwa_assessment_watersheds_poly (waterbody_id);
create index on whse_basemapping.fwa_assessment_watersheds_poly (waterbody_key);
create index on whse_basemapping.fwa_assessment_watersheds_poly (watershed_key);
create index on whse_basemapping.fwa_assessment_watersheds_poly using gist (wscode_ltree);
create index on whse_basemapping.fwa_assessment_watersheds_poly using btree (wscode_ltree);
create index on whse_basemapping.fwa_assessment_watersheds_poly using gist (localcode_ltree);
create index on whse_basemapping.fwa_assessment_watersheds_poly using btree (localcode_ltree);
create index on whse_basemapping.fwa_assessment_watersheds_poly using gist(geom);


drop table if exists whse_basemapping.fwa_coastlines_sp;

create table if not exists whse_basemapping.fwa_coastlines_sp (
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

create index on whse_basemapping.fwa_coastlines_sp (edge_type);
create index on whse_basemapping.fwa_coastlines_sp (blue_line_key);
create index on whse_basemapping.fwa_coastlines_sp (watershed_key);
create index on whse_basemapping.fwa_coastlines_sp (watershed_group_code);
create index on whse_basemapping.fwa_coastlines_sp using gist (wscode_ltree);
create index on whse_basemapping.fwa_coastlines_sp using btree (wscode_ltree);
create index on whse_basemapping.fwa_coastlines_sp using gist (localcode_ltree);
create index on whse_basemapping.fwa_coastlines_sp using btree (localcode_ltree);
create index on whse_basemapping.fwa_coastlines_sp using gist (geom);


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