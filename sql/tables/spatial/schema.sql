create table if not exists whse_basemapping.fwa_assessment_watersheds_poly (
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
create index if not exists fwa_assmnt_wshds_watershed_group_code_idx on whse_basemapping.fwa_assessment_watersheds_poly (watershed_group_code);
create index if not exists fwa_assmnt_wshds_gnis_name_1_idx on whse_basemapping.fwa_assessment_watersheds_poly (gnis_name_1);
create index if not exists fwa_assmnt_wshds_waterbody_id_idx on whse_basemapping.fwa_assessment_watersheds_poly (waterbody_id);
create index if not exists fwa_assmnt_wshds_waterbody_key_idx on whse_basemapping.fwa_assessment_watersheds_poly (waterbody_key);
create index if not exists fwa_assmnt_wshds_watershed_key_idx on whse_basemapping.fwa_assessment_watersheds_poly (watershed_key);
create index if not exists fwa_assmnt_wshds_wsc_gist_idx on whse_basemapping.fwa_assessment_watersheds_poly using gist (wscode_ltree);
create index if not exists fwa_assmnt_wshds_wsc_btree_idx on whse_basemapping.fwa_assessment_watersheds_poly using btree (wscode_ltree);
create index if not exists fwa_assmnt_wshds_lc_gist_idx on whse_basemapping.fwa_assessment_watersheds_poly using gist (localcode_ltree);
create index if not exists fwa_assmnt_wshds_lc_btree_idx on whse_basemapping.fwa_assessment_watersheds_poly using btree (localcode_ltree);
create index if not exists fwa_assmnt_wshds_geom_idx on whse_basemapping.fwa_assessment_watersheds_poly using gist(geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table if not exists whse_basemapping.fwa_bays_and_channels_poly (
    bay_and_channel_id integer primary key,
    bay_channel_type character varying(14),
    gnis_id integer,
    gnis_name character varying(80),
    area_ha double precision,
    feature_code character varying(10),
    geom public.geometry(multipolygon,3005)
);
create index if not exists fwa_bays_channels_gnis_name_idx on whse_basemapping.fwa_bays_and_channels_poly (gnis_name);
create index if not exists fwa_bays_channels_geom_idx on whse_basemapping.fwa_bays_and_channels_poly using gist(geom);

-- ---------------------------------------------------------------------------------------------------------------------

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
create index if not exists fwa_coastlines_edge_type_idx on whse_basemapping.fwa_coastlines_sp (edge_type);
create index if not exists fwa_coastlines_blue_line_key_idx on whse_basemapping.fwa_coastlines_sp (blue_line_key);
create index if not exists fwa_coastlines_watershed_key_idx on whse_basemapping.fwa_coastlines_sp (watershed_key);
create index if not exists fwa_coastlines_watershed_group_code_idx on whse_basemapping.fwa_coastlines_sp (watershed_group_code);
create index if not exists fwa_coastlines_geom_idx on whse_basemapping.fwa_coastlines_sp using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table if not exists whse_basemapping.fwa_glaciers_poly (
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
create index if not exists fwa_glaciers_blue_line_key_idx on whse_basemapping.fwa_glaciers_poly (blue_line_key);
create index if not exists fwa_glaciers_watershed_key_idx on whse_basemapping.fwa_glaciers_poly (watershed_key);
create index if not exists fwa_glaciers_waterbody_key_idx on whse_basemapping.fwa_glaciers_poly (waterbody_key);
create index if not exists fwa_glaciers_watershed_group_code_idx on whse_basemapping.fwa_glaciers_poly (watershed_group_code);
create index if not exists fwa_glaciers_gnis_name_1_idx on whse_basemapping.fwa_glaciers_poly (gnis_name_1);
create index if not exists fwa_glaciers_wsc_gist_idx on whse_basemapping.fwa_glaciers_poly using gist (wscode_ltree);
create index if not exists fwa_glaciers_wsc_btree_idx on whse_basemapping.fwa_glaciers_poly using btree (wscode_ltree);
create index if not exists fwa_glaciers_lc_gist_idx on whse_basemapping.fwa_glaciers_poly using gist (localcode_ltree);
create index if not exists fwa_glaciers_lc_btree_ltree_idx on whse_basemapping.fwa_glaciers_poly using btree (localcode_ltree);
create index if not exists fwa_glaciers_geom_idx on whse_basemapping.fwa_glaciers_poly using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

CREATE TABLE if not exists whse_basemapping.fwa_islands_poly (
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
CREATE INDEX if not exists fwa_islands_gnis_name_1_idx ON whse_basemapping.fwa_islands_poly (gnis_name_1);
CREATE INDEX if not exists fwa_islands_gnis_name_2_idx ON whse_basemapping.fwa_islands_poly (gnis_name_2);
CREATE INDEX if not exists fwa_islands_wsc_gist_idx ON whse_basemapping.fwa_islands_poly USING GIST (wscode_ltree);
CREATE INDEX if not exists fwa_islands_wsc_btree_idx ON whse_basemapping.fwa_islands_poly USING BTREE (wscode_ltree);
CREATE INDEX if not exists fwa_islands_lc_gist_idx ON whse_basemapping.fwa_islands_poly USING GIST (localcode_ltree);
CREATE INDEX if not exists fwa_islands_lc_btree_idx ON whse_basemapping.fwa_islands_poly USING BTREE (localcode_ltree);
CREATE INDEX if not exists fwa_islands_geom_idx ON whse_basemapping.fwa_islands_poly USING GIST (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table if not exists whse_basemapping.fwa_lakes_poly (
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
create index if not exists fwa_lakes_blue_line_key_idx on whse_basemapping.fwa_lakes_poly (blue_line_key);
create index if not exists fwa_lakes_watershed_key_idx on whse_basemapping.fwa_lakes_poly (watershed_key);
create index if not exists fwa_lakes_waterbody_key_idx on whse_basemapping.fwa_lakes_poly (waterbody_key);
create index if not exists fwa_lakes_watershed_group_code_idx on whse_basemapping.fwa_lakes_poly (watershed_group_code);
create index if not exists fwa_lakes_gnis_name_1_idx on whse_basemapping.fwa_lakes_poly (gnis_name_1);
create index if not exists fwa_lakes_wsc_gist_idx on whse_basemapping.fwa_lakes_poly using gist (wscode_ltree);
create index if not exists fwa_lakes_wsc_btree_idx on whse_basemapping.fwa_lakes_poly using btree (wscode_ltree);
create index if not exists fwa_lakes_lc_gist_idx on whse_basemapping.fwa_lakes_poly using gist (localcode_ltree);
create index if not exists fwa_lakes_lc_btree_idx on whse_basemapping.fwa_lakes_poly using btree (localcode_ltree);
create index if not exists fwa_lakes_geom_idx on whse_basemapping.fwa_lakes_poly using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table if not exists whse_basemapping.fwa_linear_boundaries_sp (
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
create index if not exists fwa_linear_bnd_edge_type_idx on whse_basemapping.fwa_linear_boundaries_sp (edge_type);
create index if not exists fwa_linear_bnd_blue_line_key_idx on whse_basemapping.fwa_linear_boundaries_sp (blue_line_key);
create index if not exists fwa_linear_bnd_watershed_key_idx on whse_basemapping.fwa_linear_boundaries_sp (watershed_key);
create index if not exists fwa_linear_bnd_waterbody_key_idx on whse_basemapping.fwa_linear_boundaries_sp (waterbody_key);
create index if not exists fwa_linear_bnd_watershed_group_code_idx on whse_basemapping.fwa_linear_boundaries_sp (watershed_group_code);
create index if not exists fwa_linear_bnd_wsc_gist_idx on whse_basemapping.fwa_linear_boundaries_sp using gist (wscode_ltree);
create index if not exists fwa_linear_bnd_wsc_btree_idx on whse_basemapping.fwa_linear_boundaries_sp using btree (wscode_ltree);
create index if not exists fwa_linear_bnd_lc_gist_idx on whse_basemapping.fwa_linear_boundaries_sp using gist (localcode_ltree);
create index if not exists fwa_linear_bnd_lc_btree_idx on whse_basemapping.fwa_linear_boundaries_sp using btree (localcode_ltree);
create index if not exists fwa_linear_bnd_geom_idx on whse_basemapping.fwa_linear_boundaries_sp using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table if not exists whse_basemapping.fwa_manmade_waterbodies_poly (
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
create index if not exists fwa_mmdwbdy_blue_line_key_idx on whse_basemapping.fwa_manmade_waterbodies_poly (blue_line_key);
create index if not exists fwa_mmdwbdy_watershed_key_idx on whse_basemapping.fwa_manmade_waterbodies_poly (watershed_key);
create index if not exists fwa_mmdwbdy_waterbody_key_idx on whse_basemapping.fwa_manmade_waterbodies_poly (waterbody_key);
create index if not exists fwa_mmdwbdy_watershed_group_code_idx on whse_basemapping.fwa_manmade_waterbodies_poly (watershed_group_code);
create index if not exists fwa_mmdwbdy_gnis_name_1_idx on whse_basemapping.fwa_manmade_waterbodies_poly (gnis_name_1);
create index if not exists fwa_mmdwbdy_wsc_gist_idx on whse_basemapping.fwa_manmade_waterbodies_poly using gist (wscode_ltree);
create index if not exists fwa_mmdwbdy_wsc_btree_idx on whse_basemapping.fwa_manmade_waterbodies_poly using btree (wscode_ltree);
create index if not exists fwa_mmdwbdy_lc_gist_idx on whse_basemapping.fwa_manmade_waterbodies_poly using gist (localcode_ltree);
create index if not exists fwa_mmdwbdy_lc_btree_idx on whse_basemapping.fwa_manmade_waterbodies_poly using btree (localcode_ltree);
create index if not exists fwa_mmdwbdy_geom_idx on whse_basemapping.fwa_manmade_waterbodies_poly using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table if not exists whse_basemapping.fwa_named_point_features_sp (
    named_point_feature_id integer primary key,
    gnis_id integer,
    gnis_name character varying(80),
    named_feature_type character varying(6),
    feature_code character varying(10),
    geom public.geometry(point, 3005)
);

create index if not exists fwa_namedpt_gnis_name_idx on whse_basemapping.fwa_named_point_features_sp (gnis_name);
create index if not exists fwa_namedpt_geom_idx on whse_basemapping.fwa_named_point_features_sp using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------


create table if not exists whse_basemapping.fwa_named_watersheds_poly (
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
create index if not exists fwa_named_wsds_gnis_name_idx on whse_basemapping.fwa_named_watersheds_poly (gnis_name);
create index if not exists fwa_named_wsds_blue_line_key_idx on whse_basemapping.fwa_named_watersheds_poly (blue_line_key);
create index if not exists fwa_named_wsds_fwa_watershed_code_idx on whse_basemapping.fwa_named_watersheds_poly (fwa_watershed_code);
create index if not exists fwa_named_wsds_wsc_gist_idx on whse_basemapping.fwa_named_watersheds_poly using gist (wscode_ltree);
create index if not exists fwa_named_wsds_wsc_btree_idx on whse_basemapping.fwa_named_watersheds_poly using btree (wscode_ltree);
create index if not exists fwa_named_wsds_geom_idx on whse_basemapping.fwa_named_watersheds_poly using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table if not exists whse_basemapping.fwa_obstructions_sp (
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
create index if not exists fwa_obstructions_linear_feature_id_idx on whse_basemapping.fwa_obstructions_sp (linear_feature_id);
create index if not exists fwa_obstructions_blue_line_key_idx on whse_basemapping.fwa_obstructions_sp (blue_line_key);
create index if not exists fwa_obstructions_watershed_key_idx on whse_basemapping.fwa_obstructions_sp (watershed_key);
create index if not exists fwa_obstructions_obstruction_type_idx on whse_basemapping.fwa_obstructions_sp (obstruction_type);
create index if not exists fwa_obstructions_watershed_group_code_idx on whse_basemapping.fwa_obstructions_sp (watershed_group_code);
create index if not exists fwa_obstructions_gnis_name_idx on whse_basemapping.fwa_obstructions_sp (gnis_name);
create index if not exists fwa_obstructions_wsc_gist_idx on whse_basemapping.fwa_obstructions_sp using gist (wscode_ltree);
create index if not exists fwa_obstructions_wsc_btree_idx on whse_basemapping.fwa_obstructions_sp using btree (wscode_ltree);
create index if not exists fwa_obstructions_lc_gist_idx on whse_basemapping.fwa_obstructions_sp using gist (localcode_ltree);
create index if not exists fwa_obstructions_lc_btree_idx on whse_basemapping.fwa_obstructions_sp using btree (localcode_ltree);
create index if not exists fwa_obstructions_geom_idx on whse_basemapping.fwa_obstructions_sp using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table if not exists whse_basemapping.fwa_rivers_poly (
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
create index if not exists fwa_rivers_blue_line_key_idx on whse_basemapping.fwa_rivers_poly (blue_line_key);
create index if not exists fwa_rivers_watershed_key_idx on whse_basemapping.fwa_rivers_poly (watershed_key);
create index if not exists fwa_rivers_waterbody_key_idx on whse_basemapping.fwa_rivers_poly (waterbody_key);
create index if not exists fwa_rivers_watershed_group_code_idx on whse_basemapping.fwa_rivers_poly (watershed_group_code);
create index if not exists fwa_rivers_gnis_name_1_idx on whse_basemapping.fwa_rivers_poly (gnis_name_1);
create index if not exists fwa_rivers_wsc_gist_idx on whse_basemapping.fwa_rivers_poly using gist (wscode_ltree);
create index if not exists fwa_rivers_wsc_btree_idx on whse_basemapping.fwa_rivers_poly using btree (wscode_ltree);
create index if not exists fwa_rivers_lc_gist_idx on whse_basemapping.fwa_rivers_poly using gist (localcode_ltree);
create index if not exists fwa_rivers_lc_btree_idx on whse_basemapping.fwa_rivers_poly using btree (localcode_ltree);
create index if not exists fwa_rivers_geom_idx on whse_basemapping.fwa_rivers_poly using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------  

create table if not exists whse_basemapping.fwa_stream_networks_sp (
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
create index if not exists fwa_streamnetworks_edge_type_idx on whse_basemapping.fwa_stream_networks_sp (edge_type);
create index if not exists fwa_streamnetworks_blue_line_key_idx on whse_basemapping.fwa_stream_networks_sp (blue_line_key);
create index if not exists fwa_streamnetworks_blkey_measure_idx on whse_basemapping.fwa_stream_networks_sp (blue_line_key, downstream_route_measure);
create index if not exists fwa_streamnetworks_watershed_key_idx on whse_basemapping.fwa_stream_networks_sp (watershed_key);
create index if not exists fwa_streamnetworks_waterbody_key_idx on whse_basemapping.fwa_stream_networks_sp (waterbody_key);
create index if not exists fwa_streamnetworks_watershed_group_code_idx on whse_basemapping.fwa_stream_networks_sp (watershed_group_code);
create index if not exists fwa_streamnetworks_gnis_name_idx on whse_basemapping.fwa_stream_networks_sp (gnis_name);
create index if not exists fwa_streamnetworks_wsc_gist_idx on whse_basemapping.fwa_stream_networks_sp using gist (wscode_ltree);
create index if not exists fwa_streamnetworks_wsc_btree_idx on whse_basemapping.fwa_stream_networks_sp using btree (wscode_ltree);
create index if not exists fwa_streamnetworks_lc_gist_idx on whse_basemapping.fwa_stream_networks_sp using gist (localcode_ltree);
create index if not exists fwa_streamnetworks_lc_btree_idx on whse_basemapping.fwa_stream_networks_sp using btree (localcode_ltree);
create index if not exists fwa_streamnetworks_geom_idx on whse_basemapping.fwa_stream_networks_sp using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table if not exists whse_basemapping.fwa_watershed_groups_poly (
    watershed_group_id integer primary key,
    watershed_group_code character varying(4),
    watershed_group_name character varying(80),
    area_ha double precision,
    feature_code character varying(10),
    geom public.geometry(multipolygon,3005)
);
create index if not exists fwa_watershed_groups_watershed_group_code_idx on whse_basemapping.fwa_watershed_groups_poly (watershed_group_code);
create index if not exists fwa_watershed_groups_geom_idx on whse_basemapping.fwa_watershed_groups_poly using gist (geom);


-- ---------------------------------------------------------------------------------------------------------------------

create table if not exists whse_basemapping.fwa_watersheds_poly (
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
create index if not exists fwa_watersheds_gnis_name_1_idx on whse_basemapping.fwa_watersheds_poly (gnis_name_1);
create index if not exists fwa_watersheds_waterbody_id_idx on whse_basemapping.fwa_watersheds_poly (waterbody_id);
create index if not exists fwa_watersheds_waterbody_key_idx on whse_basemapping.fwa_watersheds_poly (waterbody_key);
create index if not exists fwa_watersheds_watershed_key_idx on whse_basemapping.fwa_watersheds_poly (watershed_key);
create index if not exists fwa_watersheds_watershed_group_code_idx on whse_basemapping.fwa_watersheds_poly (watershed_group_code);
create index if not exists fwa_watersheds_watershed_group_id_idx on whse_basemapping.fwa_watersheds_poly (watershed_group_id);
create index if not exists fwa_watersheds_wsc_gist_idx on whse_basemapping.fwa_watersheds_poly using gist (wscode_ltree);
create index if not exists fwa_watersheds_wsc_btree_idx on whse_basemapping.fwa_watersheds_poly using btree (wscode_ltree);
create index if not exists fwa_watersheds_lc_gist_idx on whse_basemapping.fwa_watersheds_poly using gist (localcode_ltree);
create index if not exists fwa_watersheds_lc_btree_idx on whse_basemapping.fwa_watersheds_poly using btree (localcode_ltree);
create index if not exists fwa_watersheds_geom_idx on whse_basemapping.fwa_watersheds_poly using gist (geom);

-- ---------------------------------------------------------------------------------------------------------------------

create table if not exists whse_basemapping.fwa_wetlands_poly (
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
create index if not exists fwa_wetlands_blue_line_key_idx on whse_basemapping.fwa_wetlands_poly (blue_line_key);
create index if not exists fwa_wetlands_watershed_key_idx on whse_basemapping.fwa_wetlands_poly (watershed_key);
create index if not exists fwa_wetlands_waterbody_key_idx on whse_basemapping.fwa_wetlands_poly (waterbody_key);
create index if not exists fwa_wetlands_watershed_group_code_idx on whse_basemapping.fwa_wetlands_poly (watershed_group_code);
create index if not exists fwa_wetlands_gnis_name_1_idx on whse_basemapping.fwa_wetlands_poly (gnis_name_1);
create index if not exists fwa_wetlands_wsc_gist_idx on whse_basemapping.fwa_wetlands_poly using gist (wscode_ltree);
create index if not exists fwa_wetlands_wsc_btree_idx on whse_basemapping.fwa_wetlands_poly using btree (wscode_ltree);
create index if not exists fwa_wetlands_lc_gist_idx on whse_basemapping.fwa_wetlands_poly using gist (localcode_ltree);
create index if not exists fwa_wetlands_lc_btree_idx on whse_basemapping.fwa_wetlands_poly using btree (localcode_ltree);
create index if not exists fwa_wetlands_geom_idx on whse_basemapping.fwa_wetlands_poly using gist (geom);