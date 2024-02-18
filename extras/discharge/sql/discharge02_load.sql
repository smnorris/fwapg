-- Either my syntax is bad or using st_transform() to reproject the vector geometry directly in the overlay query does not work.
-- Avoid the issue by just creating a temp table of watershed centroids in 4326.
CREATE TEMPORARY TABLE temp_wsd_pts AS
SELECT
  watershed_feature_id,
  watershed_group_code,
  st_transform(st_centroid(geom), 4326) as geom
FROM whse_basemapping.fwa_watersheds_poly
WHERE watershed_group_code = :'wsg';

INSERT INTO fwapg.discharge02_load
(watershed_feature_id, watershed_group_code, discharge_mm)
SELECT 
  p.watershed_feature_id,
  p.watershed_group_code,
  ST_Value(rast, p.geom) as discharge_mm
FROM temp_wsd_pts p
INNER JOIN fwapg.discharge01_raster
ON ST_intersects(p.geom, st_convexhull(rast));