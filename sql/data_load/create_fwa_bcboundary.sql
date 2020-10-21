-- Create a table defining the boundary of BC, according to FWA
-- This is required to (relatively) quickly cut out areas of hydrosheds watersheds within BC
DROP TABLE IF EXISTS whse_basemapping.fwa_bc_boundary;

CREATE TABLE whse_basemapping.fwa_bc_boundary
(fwa_bc_boundary_id serial primary key,
geom geometry(Polygon, 3005));

INSERT INTO whse_basemapping.fwa_bc_boundary (geom)
SELECT
  (ST_Dump(ST_Union(geom))).geom as geom
FROM whse_basemapping.fwa_watershed_groups_poly;

CREATE INDEX ON whse_basemapping.fwa_bc_boundary USING GIST (geom);