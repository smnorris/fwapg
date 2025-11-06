BEGIN;

  TRUNCATE whse_basemapping.fwa_bcboundary;

  INSERT INTO whse_basemapping.fwa_bcboundary (geom)
  SELECT
    (ST_Dump(ST_Union(geom))).geom as geom
  FROM whse_basemapping.fwa_watershed_groups_poly;

COMMIT;