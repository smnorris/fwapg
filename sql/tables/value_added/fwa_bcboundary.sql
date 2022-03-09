-- Create a table defining the boundary of BC, according to FWA
-- This is required to (relatively) quickly cut out areas of hydrosheds watersheds within BC

DROP TABLE IF EXISTS whse_basemapping.fwa_bcboundary;

CREATE TABLE whse_basemapping.fwa_bcboundary
(
  bcboundary_id serial primary key,
  geom geometry(Polygon, 3005)
);

INSERT INTO whse_basemapping.fwa_bcboundary (geom)
SELECT
  (ST_Dump(ST_Union(geom))).geom as geom
FROM whse_basemapping.fwa_watershed_groups_poly;

CREATE INDEX ON whse_basemapping.fwa_bcboundary USING GIST (geom);

COMMENT ON TABLE whse_basemapping.fwa_bcboundary IS 'Boundary of BC as defined by FWA - used by FWA_WatershedAtMeasure()';
COMMENT ON COLUMN whse_basemapping.fwa_bcboundary.bcboundary_id IS 'Boundary polygon id';
COMMENT ON COLUMN whse_basemapping.fwa_bcboundary.geom IS 'Boundary geometry';
