BEGIN;

  INSERT INTO whse_basemapping.fwa_watersheds_poly (
    watershed_feature_id,
    watershed_group_id,
    watershed_key,
    fwa_watershed_code,
    local_watershed_code,
    watershed_group_code,
    watershed_order,
    watershed_magnitude,
    local_watershed_order,
    local_watershed_magnitude,
    feature_code,
    geom
  )
  SELECT
    watershed_feature_id,
    watershed_group_id,
    watershed_key,
    fwa_watershed_code,
    local_watershed_code,
    watershed_group_code,
    watershed_order,
    watershed_magnitude,
    local_watershed_order,
    local_watershed_magnitude,
    feature_code,
    geom
  FROM whse_basemapping.fwa_watersheds_xborder_poly;

  DROP TABLE whse_basemapping.fwa_watersheds_xborder_poly;

COMMIT; 