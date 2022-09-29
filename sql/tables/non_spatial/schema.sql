create table if not exists whse_basemapping.fwa_edge_type_codes (
    edge_type bigint,
    edge_description character varying(100)
);

-- ---------------------------------------------------------------------------------------------------------------------

create table if not exists whse_basemapping.fwa_streams_20k_50k (
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
create index if not exists fwa_strms_20k50k_watershed_group_id_20k_idx on whse_basemapping.fwa_streams_20k_50k (watershed_group_id_20k);
create index if not exists fwa_strms_20k50k_linear_feature_id_20k_idx on whse_basemapping.fwa_streams_20k_50k (linear_feature_id_20k);
create index if not exists fwa_strms_20k50k_watershed_code_50k_idx on whse_basemapping.fwa_streams_20k_50k (watershed_code_50k);

-- ---------------------------------------------------------------------------------------------------------------------

create table if not exists whse_basemapping.fwa_waterbodies_20k_50k (
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
create index if not exists fwa_wb_20k50k_waterbody_type_20k_idx on whse_basemapping.fwa_waterbodies_20k_50k (waterbody_type_20k);
create index if not exists fwa_wb_20k50k_watershed_group_id_20k_idx on whse_basemapping.fwa_waterbodies_20k_50k (watershed_group_id_20k);
create index if not exists fwa_wb_20k50k_waterbody_poly_id_20k_idx on whse_basemapping.fwa_waterbodies_20k_50k (waterbody_poly_id_20k);
create index if not exists fwa_wb_20k50k_fwa_watershed_code_20k_idx on whse_basemapping.fwa_waterbodies_20k_50k (fwa_watershed_code_20k);
create index if not exists fwa_wb_20k50k_watershed_code_50k_idx on whse_basemapping.fwa_waterbodies_20k_50k (watershed_code_50k);

-- ---------------------------------------------------------------------------------------------------------------------

create table if not exists whse_basemapping.fwa_waterbody_type_codes (
    waterbody_type character varying(1),
    waterbody_description character varying(180)
);

-- ---------------------------------------------------------------------------------------------------------------------

create table if not exists whse_basemapping.fwa_watershed_type_codes (
    watershed_type character varying(1),
    watershed_description character varying(255)
);
