-- Create a subdivided watershed group table for *much* faster point in poly
-- queries and other spatial join operations.

DROP TABLE IF EXISTS whse_basemapping.fwa_watershed_groups_subdivided;

CREATE TABLE whse_basemapping.fwa_watershed_groups_subdivided
(
  fwa_watershed_groups_subdivided_id SERIAL PRIMARY KEY,
  watershed_group_code text,
  geom geometry(POLYGON, 3005)
);

INSERT INTO whse_basemapping.fwa_watershed_groups_subdivided
(watershed_group_code, geom)
SELECT
  watershed_group_code,
  ST_Subdivide(ST_Force2D(geom)) as geom
FROM whse_basemapping.fwa_watershed_groups_poly;

CREATE INDEX ON whse_basemapping.fwa_watershed_groups_subdivided USING gist (geom);

-- Keep the above table for ultimate speed, but it turns out that we can get
-- most of the performance benefit of subdiving by just de-toasting
-- http://blog.cleverelephant.ca/2018/09/postgis-external-storage.html
ALTER TABLE whse_basemapping.fwa_watershed_groups_poly
ALTER COLUMN geom SET STORAGE EXTERNAL;

-- Force the column to rewrite
UPDATE whse_basemapping.fwa_watershed_groups_poly
SET geom = ST_SetSRID(geom, 3005);