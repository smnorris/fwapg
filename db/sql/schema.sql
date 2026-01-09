-- EXTENSIONS
create extension if not exists postgis with schema public;
create extension if not exists ltree with schema public;
create extension if not exists intarray with schema public;

-- SCHEMAS
create schema fwapg;
create schema if not exists whse_basemapping;
create schema if not exists usgs;
create schema if not exists psf;
create schema if not exists hydrosheds;
create schema if not exists postgisftw;        -- for functions served by pg_featureserv

-- TABLES
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
create index fwa_assmnt_wshds_watershed_group_code_idx on whse_basemapping.fwa_assessment_watersheds_poly (watershed_group_code);
create index fwa_assmnt_wshds_gnis_name_1_idx on whse_basemapping.fwa_assessment_watersheds_poly (gnis_name_1);
create index fwa_assmnt_wshds_waterbody_id_idx on whse_basemapping.fwa_assessment_watersheds_poly (waterbody_id);
create index fwa_assmnt_wshds_waterbody_key_idx on whse_basemapping.fwa_assessment_watersheds_poly (waterbody_key);
create index fwa_assmnt_wshds_watershed_key_idx on whse_basemapping.fwa_assessment_watersheds_poly (watershed_key);
create index fwa_assmnt_wshds_wsc_gist_idx on whse_basemapping.fwa_assessment_watersheds_poly using gist (wscode_ltree);
create index fwa_assmnt_wshds_wsc_btree_idx on whse_basemapping.fwa_assessment_watersheds_poly using btree (wscode_ltree);
create index fwa_assmnt_wshds_lc_gist_idx on whse_basemapping.fwa_assessment_watersheds_poly using gist (localcode_ltree);
create index fwa_assmnt_wshds_lc_btree_idx on whse_basemapping.fwa_assessment_watersheds_poly using btree (localcode_ltree);
create index fwa_assmnt_wshds_geom_idx on whse_basemapping.fwa_assessment_watersheds_poly using gist(geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table whse_basemapping.fwa_bays_and_channels_poly (
    bay_and_channel_id integer primary key,
    bay_channel_type character varying(14),
    gnis_id integer,
    gnis_name character varying(80),
    area_ha double precision,
    feature_code character varying(10),
    geom public.geometry(multipolygon,3005)
);
create index fwa_bays_channels_gnis_name_idx on whse_basemapping.fwa_bays_and_channels_poly (gnis_name);
create index fwa_bays_channels_geom_idx on whse_basemapping.fwa_bays_and_channels_poly using gist(geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table whse_basemapping.fwa_coastlines_sp (
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
create index fwa_coastlines_edge_type_idx on whse_basemapping.fwa_coastlines_sp (edge_type);
create index fwa_coastlines_blue_line_key_idx on whse_basemapping.fwa_coastlines_sp (blue_line_key);
create index fwa_coastlines_watershed_key_idx on whse_basemapping.fwa_coastlines_sp (watershed_key);
create index fwa_coastlines_watershed_group_code_idx on whse_basemapping.fwa_coastlines_sp (watershed_group_code);
create index fwa_coastlines_geom_idx on whse_basemapping.fwa_coastlines_sp using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table whse_basemapping.fwa_glaciers_poly (
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
create index fwa_glaciers_blue_line_key_idx on whse_basemapping.fwa_glaciers_poly (blue_line_key);
create index fwa_glaciers_watershed_key_idx on whse_basemapping.fwa_glaciers_poly (watershed_key);
create index fwa_glaciers_waterbody_key_idx on whse_basemapping.fwa_glaciers_poly (waterbody_key);
create index fwa_glaciers_watershed_group_code_idx on whse_basemapping.fwa_glaciers_poly (watershed_group_code);
create index fwa_glaciers_gnis_name_1_idx on whse_basemapping.fwa_glaciers_poly (gnis_name_1);
create index fwa_glaciers_wsc_gist_idx on whse_basemapping.fwa_glaciers_poly using gist (wscode_ltree);
create index fwa_glaciers_wsc_btree_idx on whse_basemapping.fwa_glaciers_poly using btree (wscode_ltree);
create index fwa_glaciers_lc_gist_idx on whse_basemapping.fwa_glaciers_poly using gist (localcode_ltree);
create index fwa_glaciers_lc_btree_ltree_idx on whse_basemapping.fwa_glaciers_poly using btree (localcode_ltree);
create index fwa_glaciers_geom_idx on whse_basemapping.fwa_glaciers_poly using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

CREATE TABLE whse_basemapping.fwa_islands_poly (
    island_id integer PRIMARY KEY,
    island_type character varying(12),
    gnis_id_1 integer,
    gnis_name_1 character varying(80),
    gnis_id_2 integer,
    gnis_name_2 character varying(80),
    gnis_id_3 integer,
    gnis_name_3 character varying(80),
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    area_ha double precision,
    feature_code character varying(10),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    geom public.geometry(multipolygon,3005)
);
CREATE INDEX fwa_islands_gnis_name_1_idx ON whse_basemapping.fwa_islands_poly (gnis_name_1);
CREATE INDEX fwa_islands_gnis_name_2_idx ON whse_basemapping.fwa_islands_poly (gnis_name_2);
CREATE INDEX fwa_islands_wsc_gist_idx ON whse_basemapping.fwa_islands_poly USING GIST (wscode_ltree);
CREATE INDEX fwa_islands_wsc_btree_idx ON whse_basemapping.fwa_islands_poly USING BTREE (wscode_ltree);
CREATE INDEX fwa_islands_lc_gist_idx ON whse_basemapping.fwa_islands_poly USING GIST (localcode_ltree);
CREATE INDEX fwa_islands_lc_btree_idx ON whse_basemapping.fwa_islands_poly USING BTREE (localcode_ltree);
CREATE INDEX fwa_islands_geom_idx ON whse_basemapping.fwa_islands_poly USING GIST (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table whse_basemapping.fwa_lakes_poly (
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
create index fwa_lakes_blue_line_key_idx on whse_basemapping.fwa_lakes_poly (blue_line_key);
create index fwa_lakes_watershed_key_idx on whse_basemapping.fwa_lakes_poly (watershed_key);
create index fwa_lakes_waterbody_key_idx on whse_basemapping.fwa_lakes_poly (waterbody_key);
create index fwa_lakes_watershed_group_code_idx on whse_basemapping.fwa_lakes_poly (watershed_group_code);
create index fwa_lakes_gnis_name_1_idx on whse_basemapping.fwa_lakes_poly (gnis_name_1);
create index fwa_lakes_wsc_gist_idx on whse_basemapping.fwa_lakes_poly using gist (wscode_ltree);
create index fwa_lakes_wsc_btree_idx on whse_basemapping.fwa_lakes_poly using btree (wscode_ltree);
create index fwa_lakes_lc_gist_idx on whse_basemapping.fwa_lakes_poly using gist (localcode_ltree);
create index fwa_lakes_lc_btree_idx on whse_basemapping.fwa_lakes_poly using btree (localcode_ltree);
create index fwa_lakes_geom_idx on whse_basemapping.fwa_lakes_poly using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table whse_basemapping.fwa_linear_boundaries_sp (
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
create index fwa_linear_bnd_edge_type_idx on whse_basemapping.fwa_linear_boundaries_sp (edge_type);
create index fwa_linear_bnd_blue_line_key_idx on whse_basemapping.fwa_linear_boundaries_sp (blue_line_key);
create index fwa_linear_bnd_watershed_key_idx on whse_basemapping.fwa_linear_boundaries_sp (watershed_key);
create index fwa_linear_bnd_waterbody_key_idx on whse_basemapping.fwa_linear_boundaries_sp (waterbody_key);
create index fwa_linear_bnd_watershed_group_code_idx on whse_basemapping.fwa_linear_boundaries_sp (watershed_group_code);
create index fwa_linear_bnd_wsc_gist_idx on whse_basemapping.fwa_linear_boundaries_sp using gist (wscode_ltree);
create index fwa_linear_bnd_wsc_btree_idx on whse_basemapping.fwa_linear_boundaries_sp using btree (wscode_ltree);
create index fwa_linear_bnd_lc_gist_idx on whse_basemapping.fwa_linear_boundaries_sp using gist (localcode_ltree);
create index fwa_linear_bnd_lc_btree_idx on whse_basemapping.fwa_linear_boundaries_sp using btree (localcode_ltree);
create index fwa_linear_bnd_geom_idx on whse_basemapping.fwa_linear_boundaries_sp using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table whse_basemapping.fwa_manmade_waterbodies_poly (
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
create index fwa_mmdwbdy_blue_line_key_idx on whse_basemapping.fwa_manmade_waterbodies_poly (blue_line_key);
create index fwa_mmdwbdy_watershed_key_idx on whse_basemapping.fwa_manmade_waterbodies_poly (watershed_key);
create index fwa_mmdwbdy_waterbody_key_idx on whse_basemapping.fwa_manmade_waterbodies_poly (waterbody_key);
create index fwa_mmdwbdy_watershed_group_code_idx on whse_basemapping.fwa_manmade_waterbodies_poly (watershed_group_code);
create index fwa_mmdwbdy_gnis_name_1_idx on whse_basemapping.fwa_manmade_waterbodies_poly (gnis_name_1);
create index fwa_mmdwbdy_wsc_gist_idx on whse_basemapping.fwa_manmade_waterbodies_poly using gist (wscode_ltree);
create index fwa_mmdwbdy_wsc_btree_idx on whse_basemapping.fwa_manmade_waterbodies_poly using btree (wscode_ltree);
create index fwa_mmdwbdy_lc_gist_idx on whse_basemapping.fwa_manmade_waterbodies_poly using gist (localcode_ltree);
create index fwa_mmdwbdy_lc_btree_idx on whse_basemapping.fwa_manmade_waterbodies_poly using btree (localcode_ltree);
create index fwa_mmdwbdy_geom_idx on whse_basemapping.fwa_manmade_waterbodies_poly using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table whse_basemapping.fwa_named_point_features_sp (
    named_point_feature_id integer primary key,
    gnis_id integer,
    gnis_name character varying(80),
    named_feature_type character varying(6),
    feature_code character varying(10),
    geom public.geometry(point, 3005)
);

create index fwa_namedpt_gnis_name_idx on whse_basemapping.fwa_named_point_features_sp (gnis_name);
create index fwa_namedpt_geom_idx on whse_basemapping.fwa_named_point_features_sp using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------


create table whse_basemapping.fwa_named_watersheds_poly (
  named_watershed_id integer primary key,
  gnis_id integer,
  gnis_name character varying(80),
  blue_line_key integer,
  watershed_key integer,
  fwa_watershed_code character varying(143),
  stream_order integer,
  stream_magnitude integer,
  area_ha double precision,
  feature_code character varying(10),
  wscode_ltree public.ltree generated always as
    ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) stored,
  geom public.geometry(multipolygon,3005)
);
create index fwa_named_wsds_gnis_name_idx on whse_basemapping.fwa_named_watersheds_poly (gnis_name);
create index fwa_named_wsds_blue_line_key_idx on whse_basemapping.fwa_named_watersheds_poly (blue_line_key);
create index fwa_named_wsds_fwa_watershed_code_idx on whse_basemapping.fwa_named_watersheds_poly (fwa_watershed_code);
create index fwa_named_wsds_wsc_gist_idx on whse_basemapping.fwa_named_watersheds_poly using gist (wscode_ltree);
create index fwa_named_wsds_wsc_btree_idx on whse_basemapping.fwa_named_watersheds_poly using btree (wscode_ltree);
create index fwa_named_wsds_geom_idx on whse_basemapping.fwa_named_watersheds_poly using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table whse_basemapping.fwa_obstructions_sp (
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
create index fwa_obstructions_linear_feature_id_idx on whse_basemapping.fwa_obstructions_sp (linear_feature_id);
create index fwa_obstructions_blue_line_key_idx on whse_basemapping.fwa_obstructions_sp (blue_line_key);
create index fwa_obstructions_watershed_key_idx on whse_basemapping.fwa_obstructions_sp (watershed_key);
create index fwa_obstructions_obstruction_type_idx on whse_basemapping.fwa_obstructions_sp (obstruction_type);
create index fwa_obstructions_watershed_group_code_idx on whse_basemapping.fwa_obstructions_sp (watershed_group_code);
create index fwa_obstructions_gnis_name_idx on whse_basemapping.fwa_obstructions_sp (gnis_name);
create index fwa_obstructions_wsc_gist_idx on whse_basemapping.fwa_obstructions_sp using gist (wscode_ltree);
create index fwa_obstructions_wsc_btree_idx on whse_basemapping.fwa_obstructions_sp using btree (wscode_ltree);
create index fwa_obstructions_lc_gist_idx on whse_basemapping.fwa_obstructions_sp using gist (localcode_ltree);
create index fwa_obstructions_lc_btree_idx on whse_basemapping.fwa_obstructions_sp using btree (localcode_ltree);
create index fwa_obstructions_geom_idx on whse_basemapping.fwa_obstructions_sp using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table whse_basemapping.fwa_rivers_poly (
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
create index fwa_rivers_blue_line_key_idx on whse_basemapping.fwa_rivers_poly (blue_line_key);
create index fwa_rivers_watershed_key_idx on whse_basemapping.fwa_rivers_poly (watershed_key);
create index fwa_rivers_waterbody_key_idx on whse_basemapping.fwa_rivers_poly (waterbody_key);
create index fwa_rivers_watershed_group_code_idx on whse_basemapping.fwa_rivers_poly (watershed_group_code);
create index fwa_rivers_gnis_name_1_idx on whse_basemapping.fwa_rivers_poly (gnis_name_1);
create index fwa_rivers_wsc_gist_idx on whse_basemapping.fwa_rivers_poly using gist (wscode_ltree);
create index fwa_rivers_wsc_btree_idx on whse_basemapping.fwa_rivers_poly using btree (wscode_ltree);
create index fwa_rivers_lc_gist_idx on whse_basemapping.fwa_rivers_poly using gist (localcode_ltree);
create index fwa_rivers_lc_btree_idx on whse_basemapping.fwa_rivers_poly using btree (localcode_ltree);
create index fwa_rivers_geom_idx on whse_basemapping.fwa_rivers_poly using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

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
  --stream_order_parent integer,
  --stream_order_max integer,
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
create index fwa_streamnetworks_edge_type_idx on whse_basemapping.fwa_stream_networks_sp (edge_type);
create index fwa_streamnetworks_blue_line_key_idx on whse_basemapping.fwa_stream_networks_sp (blue_line_key);
create index fwa_streamnetworks_blkey_measure_idx on whse_basemapping.fwa_stream_networks_sp (blue_line_key, downstream_route_measure);
create index fwa_streamnetworks_watershed_key_idx on whse_basemapping.fwa_stream_networks_sp (watershed_key);
create index fwa_streamnetworks_waterbody_key_idx on whse_basemapping.fwa_stream_networks_sp (waterbody_key);
create index fwa_streamnetworks_watershed_group_code_idx on whse_basemapping.fwa_stream_networks_sp (watershed_group_code);
create index fwa_streamnetworks_gnis_name_idx on whse_basemapping.fwa_stream_networks_sp (gnis_name);
create index fwa_streamnetworks_wsc_gist_idx on whse_basemapping.fwa_stream_networks_sp using gist (wscode_ltree);
create index fwa_streamnetworks_wsc_btree_idx on whse_basemapping.fwa_stream_networks_sp using btree (wscode_ltree);
create index fwa_streamnetworks_lc_gist_idx on whse_basemapping.fwa_stream_networks_sp using gist (localcode_ltree);
create index fwa_streamnetworks_lc_btree_idx on whse_basemapping.fwa_stream_networks_sp using btree (localcode_ltree);
create index fwa_streamnetworks_geom_idx on whse_basemapping.fwa_stream_networks_sp using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table whse_basemapping.fwa_watershed_groups_poly (
    watershed_group_id integer primary key,
    watershed_group_code character varying(4),
    watershed_group_name character varying(80),
    area_ha double precision,
    feature_code character varying(10),
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    wscode_ltree ltree generated always as (replace(replace(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) stored,
    localcode_ltree ltree generated always as (replace(replace(local_watershed_code, '-000000', ''), '-', '.')::ltree) stored,
    basin_id integer,
    geom public.geometry(multipolygon,3005)
);
create index fwa_watershed_groups_watershed_group_code_idx on whse_basemapping.fwa_watershed_groups_poly (watershed_group_code);
create index fwa_watershed_groups_geom_idx on whse_basemapping.fwa_watershed_groups_poly using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table whse_basemapping.fwa_watersheds_poly (
  watershed_feature_id       integer primary key     ,
  watershed_group_id         integer not null        ,
  watershed_type             character varying(1)    ,
  gnis_id_1                  integer                 ,
  gnis_name_1                character varying(80)   ,
  gnis_id_2                  integer                 ,
  gnis_name_2                character varying(80)   ,
  gnis_id_3                  integer                 ,
  gnis_name_3                character varying(80)   ,
  waterbody_id               integer                 ,
  waterbody_key              integer                 ,
  watershed_key              integer not null        ,
  fwa_watershed_code         character varying(143) not null,
  local_watershed_code       character varying(143) not null,
  watershed_group_code       character varying(4) not null,
  left_right_tributary       character varying(7)    ,
  watershed_order            integer                 ,
  watershed_magnitude        integer                 ,
  local_watershed_order      integer                 ,
  local_watershed_magnitude  integer                 ,
  area_ha                    double precision        ,
  river_area                 double precision        ,
  lake_area                  double precision        ,
  wetland_area               double precision        ,
  manmade_area               double precision        ,
  glacier_area               double precision        ,
  average_elevation          double precision        ,
  average_slope              double precision        ,
  aspect_north               double precision        ,
  aspect_south               double precision        ,
  aspect_west                double precision        ,
  aspect_east                double precision        ,
  aspect_flat                double precision        ,
  feature_code               character varying(10)   ,
  wscode_ltree ltree generated always as (replace(replace(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) stored,
  localcode_ltree ltree generated always as (replace(replace(local_watershed_code, '-000000', ''), '-', '.')::ltree) stored,
  geom                       public.geometry(multipolygon,3005)
 );
create index fwa_watersheds_gnis_name_1_idx on whse_basemapping.fwa_watersheds_poly (gnis_name_1);
create index fwa_watersheds_waterbody_id_idx on whse_basemapping.fwa_watersheds_poly (waterbody_id);
create index fwa_watersheds_waterbody_key_idx on whse_basemapping.fwa_watersheds_poly (waterbody_key);
create index fwa_watersheds_watershed_key_idx on whse_basemapping.fwa_watersheds_poly (watershed_key);
create index fwa_watersheds_watershed_group_code_idx on whse_basemapping.fwa_watersheds_poly (watershed_group_code);
create index fwa_watersheds_watershed_group_id_idx on whse_basemapping.fwa_watersheds_poly (watershed_group_id);
create index fwa_watersheds_wsc_gist_idx on whse_basemapping.fwa_watersheds_poly using gist (wscode_ltree);
create index fwa_watersheds_wsc_btree_idx on whse_basemapping.fwa_watersheds_poly using btree (wscode_ltree);
create index fwa_watersheds_lc_gist_idx on whse_basemapping.fwa_watersheds_poly using gist (localcode_ltree);
create index fwa_watersheds_lc_btree_idx on whse_basemapping.fwa_watersheds_poly using btree (localcode_ltree);
create index fwa_watersheds_geom_idx on whse_basemapping.fwa_watersheds_poly using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

-- cross border watershed polygons, provided by DFO
create table whse_basemapping.fwa_watersheds_xborder_poly (
  watershed_feature_id       integer primary key     ,
  watershed_group_id         integer not null        ,
  watershed_key              integer not null        ,
  fwa_watershed_code         character varying(143) not null,
  local_watershed_code       character varying(143) not null,
  watershed_group_code       character varying(4) not null,
  watershed_order            integer                 ,
  watershed_magnitude        integer                 ,
  local_watershed_order      integer                 ,
  local_watershed_magnitude  integer                 ,
  feature_code               character varying(10)   ,
  wscode_ltree ltree generated always as (replace(replace(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) stored,
  localcode_ltree ltree generated always as (replace(replace(local_watershed_code, '-000000', ''), '-', '.')::ltree) stored,
  geom                       public.geometry(multipolygon,3005)
 );
create index fwa_wsd_xborder_watershed_key_idx on whse_basemapping.fwa_watersheds_xborder_poly (watershed_key);
create index fwa_wsd_xborder_watershed_group_code_idx on whse_basemapping.fwa_watersheds_xborder_poly (watershed_group_code);
create index fwa_wsd_xborder_watershed_group_id_idx on whse_basemapping.fwa_watersheds_xborder_poly (watershed_group_id);
create index fwa_wsd_xborder_wsc_gist_idx on whse_basemapping.fwa_watersheds_xborder_poly using gist (wscode_ltree);
create index fwa_wsd_xborder_wsc_btree_idx on whse_basemapping.fwa_watersheds_xborder_poly using btree (wscode_ltree);
create index fwa_wsd_xborder_lc_gist_idx on whse_basemapping.fwa_watersheds_xborder_poly using gist (localcode_ltree);
create index fwa_wsd_xborder_lc_btree_idx on whse_basemapping.fwa_watersheds_xborder_poly using btree (localcode_ltree);
create index fwa_wsd_xborder_geom_idx on whse_basemapping.fwa_watersheds_xborder_poly using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table whse_basemapping.fwa_wetlands_poly (
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
create index fwa_wetlands_blue_line_key_idx on whse_basemapping.fwa_wetlands_poly (blue_line_key);
create index fwa_wetlands_watershed_key_idx on whse_basemapping.fwa_wetlands_poly (watershed_key);
create index fwa_wetlands_waterbody_key_idx on whse_basemapping.fwa_wetlands_poly (waterbody_key);
create index fwa_wetlands_watershed_group_code_idx on whse_basemapping.fwa_wetlands_poly (watershed_group_code);
create index fwa_wetlands_gnis_name_1_idx on whse_basemapping.fwa_wetlands_poly (gnis_name_1);
create index fwa_wetlands_wsc_gist_idx on whse_basemapping.fwa_wetlands_poly using gist (wscode_ltree);
create index fwa_wetlands_wsc_btree_idx on whse_basemapping.fwa_wetlands_poly using btree (wscode_ltree);
create index fwa_wetlands_lc_gist_idx on whse_basemapping.fwa_wetlands_poly using gist (localcode_ltree);
create index fwa_wetlands_lc_btree_idx on whse_basemapping.fwa_wetlands_poly using btree (localcode_ltree);
create index fwa_wetlands_geom_idx on whse_basemapping.fwa_wetlands_poly using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------
-- ---------------------------------------------------------------------------------------------------------------------

-- non spatial tables
create table whse_basemapping.fwa_edge_type_codes (
    edge_type bigint,
    edge_description character varying(100)
);

-- ---------------------------------------------------------------------------------------------------------------------

create table whse_basemapping.fwa_streams_20k_50k (
    stream_20k_50k_id bigint primary key,
    watershed_group_id_20k integer,
    linear_feature_id_20k bigint,
    blue_line_key_20k integer,
    watershed_key_20k integer,
    fwa_watershed_code_20k character varying(143),
    watershed_group_code_20k character varying(4),
    blue_line_key_50k integer,
    watershed_key_50k integer,
    watershed_code_50k character varying(45),
    watershed_group_code_50k character varying(4),
    match_type character varying(7)
);
create index fwa_strms_20k50k_watershed_group_id_20k_idx on whse_basemapping.fwa_streams_20k_50k (watershed_group_id_20k);
create index fwa_strms_20k50k_linear_feature_id_20k_idx on whse_basemapping.fwa_streams_20k_50k (linear_feature_id_20k);
create index fwa_strms_20k50k_watershed_code_50k_idx on whse_basemapping.fwa_streams_20k_50k (watershed_code_50k);

-- ---------------------------------------------------------------------------------------------------------------------

create table whse_basemapping.fwa_waterbodies_20k_50k (
    waterbody_20k_50k_id integer primary key,
    watershed_group_id_20k integer,
    waterbody_type_20k character varying(1),
    waterbody_poly_id_20k integer,
    waterbody_key_20k integer,
    fwa_watershed_code_20k character varying(143),
    local_watershed_code_20k character varying(143),
    watershed_group_code_20k character varying(4),
    waterbody_type_50k character varying(1),
    waterbody_key_50k integer,
    watershed_group_code_50k character varying(4),
    watershed_code_50k character varying(45),
    match_type character varying(7)
);
create index fwa_wb_20k50k_waterbody_type_20k_idx on whse_basemapping.fwa_waterbodies_20k_50k (waterbody_type_20k);
create index fwa_wb_20k50k_watershed_group_id_20k_idx on whse_basemapping.fwa_waterbodies_20k_50k (watershed_group_id_20k);
create index fwa_wb_20k50k_waterbody_poly_id_20k_idx on whse_basemapping.fwa_waterbodies_20k_50k (waterbody_poly_id_20k);
create index fwa_wb_20k50k_fwa_watershed_code_20k_idx on whse_basemapping.fwa_waterbodies_20k_50k (fwa_watershed_code_20k);
create index fwa_wb_20k50k_watershed_code_50k_idx on whse_basemapping.fwa_waterbodies_20k_50k (watershed_code_50k);

-- ---------------------------------------------------------------------------------------------------------------------

create table whse_basemapping.fwa_waterbody_type_codes (
    waterbody_type character varying(1),
    waterbody_description character varying(180)
);

-- ---------------------------------------------------------------------------------------------------------------------

create table whse_basemapping.fwa_watershed_type_codes (
    watershed_type character varying(1),
    watershed_description character varying(255)
);


-- ---------------------------------------------------------------------------------------------------------------------
-- ---------------------------------------------------------------------------------------------------------------------
-- value added

create table whse_basemapping.fwa_approx_borders (
    approx_border_id serial primary key,
    border text,
    geom geometry(linestring, 3005)
);

comment on table whse_basemapping.fwa_approx_borders is 'lines of latitude / longitude for 49n, 60n, -120w. these are used by fwapg for finding cross-border streams';
comment on column whse_basemapping.fwa_approx_borders.approx_border_id is 'unique identifer';
comment on column whse_basemapping.fwa_approx_borders.border is 'a code identifying the border (usa49, ytnwt_60, ab_120)';
comment on column whse_basemapping.fwa_approx_borders.geom is 'geometry of the border line';

create table whse_basemapping.fwa_basins_poly (
    basin_id integer primary key,
    basin_name text,
    wscode_ltree ltree,
    localcode_ltree ltree,
    geom geometry(polygon, 3005)
);

create index on whse_basemapping.fwa_basins_poly using gist (geom);
create index on whse_basemapping.fwa_basins_poly using gist (wscode_ltree);
create index on whse_basemapping.fwa_basins_poly using btree (wscode_ltree);
create index on whse_basemapping.fwa_basins_poly using gist (localcode_ltree);
create index on whse_basemapping.fwa_basins_poly using btree (localcode_ltree);

comment on table whse_basemapping.fwa_basins_poly IS 'Large BC waterhseds consisting of at least 2-3 watershed groups, used by fwapg for watershed pre-aggregation';
comment on column whse_basemapping.fwa_basins_poly.basin_id IS 'Basin unique identifier';
comment on column whse_basemapping.fwa_basins_poly.basin_name IS 'Basin name, eg Thompson River';
comment on column whse_basemapping.fwa_basins_poly.wscode_ltree IS 'The watershed code associated with the stream at the outlet of the basin';
comment on column whse_basemapping.fwa_basins_poly.localcode_ltree IS 'The local watershed code associated with the stream at the outlet of the basin';
comment on column whse_basemapping.fwa_basins_poly.geom IS 'Geometry of the basin';


-- Create a table defining the boundary of BC, according to FWA
-- This is required to (relatively) quickly cut out areas of hydrosheds watersheds within BC
create table whse_basemapping.fwa_bcboundary
(
  bcboundary_id serial primary key,
  geom geometry(Polygon, 3005)
);

create index on whse_basemapping.fwa_bcboundary using gist (geom);

comment on table whse_basemapping.fwa_bcboundary IS 'Boundary of BC as defined by FWA - used by FWA_WatershedAtMeasure()';
comment on column whse_basemapping.fwa_bcboundary.bcboundary_id IS 'Boundary polygon id';
comment on column whse_basemapping.fwa_bcboundary.geom IS 'Boundary geometry';

-- named streams (for labelling purposes)
create table whse_basemapping.fwa_named_streams (
    named_streams_id SERIAL PRIMARY KEY,
    gnis_name TEXT,
    blue_line_key BIGINT,
    stream_order INTEGER,
    watershed_group_code TEXT,
    geom GEOMETRY(MULTILINESTRING, 3005)
);

create index on whse_basemapping.fwa_named_streams using gist (geom);

comment on table whse_basemapping.fwa_named_streams IS 'Named streams of BC, aggregated per watershed group and simplified using a 25m tolerance (primarily for mapping use)';
comment on column whse_basemapping.fwa_named_streams.named_streams_id IS 'Named stream unique identifier';
comment on column whse_basemapping.fwa_named_streams.gnis_name IS 'The BCGNIS (BC Geographical Names Information System) name associated with the stream';
comment on column whse_basemapping.fwa_named_streams.blue_line_key IS 'The blue line key of the named stream, see FWA documentation for blue_line_key description';
comment on column whse_basemapping.fwa_named_streams.stream_order IS 'The maximum stream order associated with the stream name';
comment on column whse_basemapping.fwa_named_streams.watershed_group_code IS 'The watershed group code associated with the named stream';
comment on column whse_basemapping.fwa_named_streams.geom IS 'The geometry of the named stream, an aggregation of the source features and simpified by 25m';


-- report on max order of given blue line key, useful for filtering when mapping at various scales
create table whse_basemapping.fwa_stream_networks_order_max (
    blue_line_key integer primary key,
    stream_order_max integer
);

create table whse_basemapping.fwa_stream_networks_order_parent (
    blue_line_key integer primary key,
    stream_order_parent integer
);

-- The source FWA database holds waterbodies in four different tables.
-- We could combine them on demand, but for faster queries a single
-- waterbody table is useful - simpler code when relating to all
-- waterbodies and the table also holds the  wscodes / blue_line key
-- / downstream_route_measure at the outlet of the wb for
-- easier queries of 'how much lake is upstream of this point?'
create table whse_basemapping.fwa_waterbodies (
    waterbody_key integer primary key,
    waterbody_type character varying (1),
    blue_line_key integer,
    downstream_route_measure double precision,
    wscode_ltree ltree,
    localcode_ltree ltree
);

create index on whse_basemapping.fwa_waterbodies (blue_line_key);
create index on whse_basemapping.fwa_waterbodies using gist (wscode_ltree);
create index on whse_basemapping.fwa_waterbodies using btree (wscode_ltree);
create index on whse_basemapping.fwa_waterbodies using gist (localcode_ltree);
create index on whse_basemapping.fwa_waterbodies using btree (localcode_ltree);

comment on table whse_basemapping.fwa_waterbodies IS 'All FWA waterbodies in one table for convenience (lakes, wetlands, rivers, manmade waterbodies, glaciers). See FWA docs for column descriptions.';

-- relate streams and fundamental watersheds
CREATE TABLE whse_basemapping.fwa_streams_watersheds_lut (
    linear_feature_id bigint primary key,
    watershed_feature_id integer
);
create index on whse_basemapping.fwa_streams_watersheds_lut (watershed_feature_id);
comment on table whse_basemapping.fwa_streams_watersheds_lut IS 'A convenience lookup for quickly relating streams and fundamental watersheds';
comment on column whse_basemapping.fwa_streams_watersheds_lut.linear_feature_id IS 'FWA stream segment unique identifier';
comment on column whse_basemapping.fwa_streams_watersheds_lut.watershed_feature_id IS 'FWA fundamental watershed unique identifer';

-- USA watershed boundaries
create table usgs.wbdhu12 (
    tnmid                     character varying(40)                 ,
    metasourceid              character varying(40)                 ,
    sourcedatadesc            character varying(100)                ,
    sourceoriginator          character varying(130)                ,
    sourcefeatureid           character varying(40)                 ,
    loaddate                  timestamp with time zone              ,
    referencegnis_ids         character varying(50)                 ,
    areaacres                 double precision                      ,
    areasqkm                  double precision                      ,
    states                    character varying(50)                 ,
    huc12                     character varying(12) primary key     ,
    name                      character varying(120)                ,
    hutype                    character varying(1)                  ,
    humod                     character varying(30)                 ,
    tohuc                     character varying(16)                 ,
    noncontributingareaacres  double precision                      ,
    noncontributingareasqkm   double precision                      ,
    globalid                  character varying                     ,
    shape_length              double precision                      ,
    shape_area                double precision                      ,
    geom                      geometry(MultiPolygon,3005)
);

create index on usgs.wbdhu12 (tohuc);
comment on table usgs.wbdhu12 IS 'USGS National Watershed Boundary Dataset, HUC12 level. See https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.xml';

-- canada watershed boundaries (via hydrosheds)
create table hydrosheds.hybas_lev12_v1c (
    hybas_id   bigint    primary key       ,
    next_down  numeric(11,0)               ,
    geom       geometry(MultiPolygon,3005)
);
create index on hydrosheds.hybas_lev12_v1c (next_down);
create index on hydrosheds.hybas_lev12_v1c using gist (geom);
comment on table hydrosheds.hybas_lev12_v1c IS 'HydroBasins for North America from https://www.hydrosheds.org. See source for column documentation';


-- ---------------------------------------------------------------------------------------------------------------------
-- ---------------------------------------------------------------------------------------------------------------------
-- extras

create table whse_basemapping.fwa_streams (
  linear_feature_id        bigint  primary key         ,
  edge_type                integer                     ,
  blue_line_key            integer                     ,
  watershed_key            integer                     ,
  wscode                   ltree                       ,
  localcode                ltree                       ,
  watershed_group_code     character varying(4)        ,
  downstream_route_measure double precision            ,
  upstream_route_measure   double precision            ,
  length_metre             double precision            ,
  waterbody_key            integer                     ,
  gnis_name                character varying(80)       ,
  stream_order             integer                     ,
  stream_magnitude         integer                     ,
  feature_code             character varying(10)       ,
  gradient                 double precision            ,
  left_right_tributary     character varying(7)        ,
  stream_order_parent      integer                     ,
  stream_order_max         integer                     ,
  upstream_area_ha         double precision            ,
  map_upstream             integer                     ,
  channel_width            double precision            ,
  channel_width_source     text                        ,
  mad_m3s                  double precision            ,
  geom                     geometry(LineStringZM,3005)
);

create index fwa_streams_edge_type_idx on whse_basemapping.fwa_streams (edge_type);
create index fwa_streams_blue_line_key_idx on whse_basemapping.fwa_streams (blue_line_key);
create index fwa_streams_blkey_measure_idx on whse_basemapping.fwa_streams (blue_line_key, downstream_route_measure);
create index fwa_streams_watershed_key_idx on whse_basemapping.fwa_streams (watershed_key);
create index fwa_streams_waterbody_key_idx on whse_basemapping.fwa_streams (waterbody_key);
create index fwa_streams_watershed_group_code_idx on whse_basemapping.fwa_streams (watershed_group_code);
create index fwa_streams_gnis_name_idx on whse_basemapping.fwa_streams (gnis_name);
create index fwa_streams_wsc_gist_idx on whse_basemapping.fwa_streams using gist (wscode);
create index fwa_streams_wsc_btree_idx on whse_basemapping.fwa_streams using btree (wscode);
create index fwa_streams_lc_gist_idx on whse_basemapping.fwa_streams using gist (localcode);
create index fwa_streams_lc_btree_idx on whse_basemapping.fwa_streams using btree (localcode);
create index fwa_streams_geom_idx on whse_basemapping.fwa_streams using gist (geom);


comment on table whse_basemapping.fwa_streams is 'FWA stream networks and value-added attributes';
comment on column whse_basemapping.fwa_streams.linear_feature_id is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams.edge_type is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams.blue_line_key is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams.watershed_key is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams.wscode is 'FWA watershed code as postgres ltree type, with trailing -000000 strings removed';
comment on column whse_basemapping.fwa_streams.localcode is 'FWA local watershed code as postgres ltree type, with trailing -000000 strings removed';
comment on column whse_basemapping.fwa_streams.watershed_group_code is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams.downstream_route_measure is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams.upstream_route_measure is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams.length_metre is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams.waterbody_key is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams.gnis_name is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams.stream_order is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams.stream_magnitude is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams.feature_code is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams.gradient is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams.left_right_tributary is 'See FWA documentation';
comment on column whse_basemapping.fwa_streams.stream_order_parent is 'Stream order of parent stream at confluence with stream having `blue_line_key` of the stream segment';
comment on column whse_basemapping.fwa_streams.stream_order_max is 'Maxiumum order of the stream with equivalent `blue_line_key` as given segment)';
comment on column whse_basemapping.fwa_streams.upstream_area_ha is 'Area (ha) upstream of the stream segment (including all fundamental watersheds with equivalent watershed code)';
comment on column whse_basemapping.fwa_streams.map_upstream is 'Area weighted average mean annual precipitation upstream of the stream segment, source ClimateBC';
comment on column whse_basemapping.fwa_streams.channel_width is 'Channel width of the stream segment in metres, with source as per channel_width_source';
comment on column whse_basemapping.fwa_streams.channel_width_source is 'Data source for channel_width at given segment, with values (FIELD_MEASURMENT, FWA_RIVERS_POLY, MODELLED). FIELD_MEASUREMENT is derived from PSCIS and FISS data, MODELLED is taken from Thorley et al, 2021';
comment on column whse_basemapping.fwa_streams.mad_m3s is 'Modelled mean annual discharge at the stream segment (Pacific Climate Impacts Consortium, University of Victoria, (January 2020) VIC-GL BCCAQ CMIP5: Gridded Hydrologic Model Output)';


create table whse_basemapping.fwa_waterbodies_upstream_area (
    linear_feature_id bigint primary key,
    upstream_lake_ha double precision,
    upstream_reservoir_ha double precision,
    upstream_wetland_ha double precision
);

create table whse_basemapping.fwa_watersheds_upstream_area (
  watershed_feature_id integer primary key,
  upstream_area_ha double precision
);

create table whse_basemapping.fwa_assessment_watersheds_lut (
  watershed_feature_id integer primary key,
  assmnt_watershed_id integer
);
create index on whse_basemapping.fwa_assessment_watersheds_lut (assmnt_watershed_id);

create table whse_basemapping.fwa_assessment_watersheds_streams_lut (
  linear_feature_id integer primary key,
  assmnt_watershed_id integer
);
create index on whse_basemapping.fwa_assessment_watersheds_streams_lut (assmnt_watershed_id);

create table whse_basemapping.fwa_stream_networks_discharge (
    linear_feature_id integer primary key,
    watershed_group_code text,
    mad_mm double precision,
    mad_m3s double precision
);

create table whse_basemapping.fwa_stream_networks_mean_annual_precip (
  id serial primary key,
  wscode_ltree ltree,
  localcode_ltree ltree,
  watershed_group_code text,
  area bigint,
  map integer,
  map_upstream integer,
  unique (wscode_ltree, localcode_ltree) -- There can be some remenant duplication in the source data,
                                         -- this constraint ensures it is removed
);

create table whse_basemapping.fwa_stream_networks_channel_width (
    linear_feature_id bigint primary key,
    channel_width_source text,
    channel_width double precision
);

create table whse_basemapping.fwa_streams_pse_conservation_units_lut (
    linear_feature_id bigint,
    cuid integer
);

create index on whse_basemapping.fwa_streams_pse_conservation_units_lut (linear_feature_id);
create index on whse_basemapping.fwa_streams_pse_conservation_units_lut (cuid);