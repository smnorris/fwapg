-- this takes ages and could probably be more efficent, but just needs to be run 1x
INSERT INTO whse_basemapping.fwa_assessment_watersheds_lut
(watershed_feature_id, assmnt_watershed_id, watershed_group_code, watershed_group_id)
SELECT
  a.watershed_feature_id,
  b.watershed_feature_id as assmnt_watershed_id,
  a.watershed_group_code,
  a.watershed_group_id
FROM whse_basemapping.fwa_watersheds_poly a
INNER JOIN whse_basemapping.fwa_assessment_watersheds_poly b
ON a.watershed_group_code = b.watershed_group_code
AND ST_CoveredBy(a.geom, ST_Buffer(b.geom, 0.1))
WHERE a.watershed_group_code = :wsg