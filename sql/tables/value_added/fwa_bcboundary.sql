-- Create a table defining the boundary of BC, according to FWA
-- This is required to (relatively) quickly cut out areas of hydrosheds watersheds within BC

DROP TABLE IF EXISTS fwapg.fwa_bcboundary;

CREATE TABLE fwapg.fwa_bcboundary
(
  bcboundary_id serial primary key,
  geom geometry(Polygon, 3005)
);

INSERT INTO fwapg.fwa_bcboundary (geom)
SELECT
  (ST_Dump(ST_Union(geom))).geom as geom
FROM whse_basemapping.fwa_watershed_groups_poly;

CREATE INDEX ON fwapg.fwa_bcboundary USING GIST (geom);

COMMENT ON TABLE fwapg.fwa_bcboundary IS 'Boundary of BC as defined by FWA - used by FWA_WatershedAtMeasure()';
COMMENT ON COLUMN fwapg.fwa_bcboundary.bcboundary_id IS 'Boundary polygon id';
COMMENT ON COLUMN fwapg.fwa_bcboundary.geom IS 'Boundary geometry';
