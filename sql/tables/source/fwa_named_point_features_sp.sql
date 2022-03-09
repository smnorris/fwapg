DROP TABLE IF EXISTS whse_basemapping.fwa_named_point_features_sp;

CREATE TABLE whse_basemapping.fwa_named_point_features_sp (
    named_point_feature_id integer PRIMARY KEY,
    gnis_id integer,
    gnis_name character varying(80),
    named_feature_type character varying(6),
    feature_code character varying(10),
    geom geometry(POINT, 3005)
);

CREATE INDEX ON whse_basemapping.fwa_named_point_features_sp (gnis_name);
CREATE INDEX ON whse_basemapping.fwa_named_point_features_sp USING GIST (geom);