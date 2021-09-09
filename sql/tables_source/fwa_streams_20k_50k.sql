CREATE TABLE whse_basemapping.fwa_streams_20k_50k (
    stream_20k_50k_id bigint PRIMARY KEY,
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

CREATE INDEX ON whse_basemapping.fwa_streams_20k_50k (watershed_group_id_20k);
CREATE INDEX ON whse_basemapping.fwa_streams_20k_50k (linear_feature_id_20k);
CREATE INDEX ON whse_basemapping.fwa_streams_20k_50k (watershed_code_50k);