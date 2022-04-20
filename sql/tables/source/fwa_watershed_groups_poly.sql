DROP TABLE IF EXISTS whse_basemapping.fwa_watershed_groups_poly;

CREATE TABLE whse_basemapping.fwa_watershed_groups_poly (
    watershed_group_id integer PRIMARY KEY,
    watershed_group_code character varying(4),
    watershed_group_name character varying(80),
    area_ha double precision,
    feature_code character varying(10),
    geom public.geometry
);

CREATE INDEX ON whse_basemapping.fwa_watershed_groups_poly (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_watershed_groups_poly USING GIST (geom);

-- For faster point in poly queries, ensure big geoms are not compressed
-- http://blog.cleverelephant.ca/2018/09/postgis-external-storage.html
-- (note that with pg14/postgis 3.2 this shouldn't be necessary)
ALTER TABLE whse_basemapping.fwa_watershed_groups_poly
ALTER COLUMN geom SET STORAGE EXTERNAL;

