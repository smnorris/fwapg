CREATE TABLE whse_basemapping.fwa_waterbodies_20k_50k (
    waterbody_20k_50k_id integer PRIMARY KEY,
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

CREATE INDEX ON whse_basemapping.fwa_waterbodies_20k_50k (waterbody_type_20k);
CREATE INDEX ON whse_basemapping.fwa_waterbodies_20k_50k (watershed_group_id_20k);
CREATE INDEX ON whse_basemapping.fwa_waterbodies_20k_50k (waterbody_poly_id_20k);
CREATE INDEX ON whse_basemapping.fwa_waterbodies_20k_50k (fwa_watershed_code_20k);
CREATE INDEX ON whse_basemapping.fwa_waterbodies_20k_50k (watershed_code_50k);