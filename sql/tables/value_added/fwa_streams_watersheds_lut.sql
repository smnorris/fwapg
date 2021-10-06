-- There is no existing 1:1 key relating streams and 
-- fundamental watersheds - a spatial query is necessary.
-- Speed future queries by running the spatial query 
-- for every stream, creating a lookup.

-- first, find matches based on watershed code
-- where there is more than one match, match to closest
INSERT INTO whse_basemapping.fwa_streams_watersheds_lut
(
  linear_feature_id,
  watershed_feature_id
)
SELECT DISTINCT ON (linear_feature_id)
  s.linear_feature_id,
  w.watershed_feature_id
FROM whse_basemapping.fwa_stream_networks_sp s
INNER JOIN whse_basemapping.fwa_watersheds_poly w
ON (s.wscode_ltree = w.wscode_ltree AND
    s.localcode_ltree = w.localcode_ltree AND
    s.watershed_group_code = w.watershed_group_code)
WHERE s.watershed_group_code = :'wsg'
AND s.fwa_watershed_code NOT LIKE '999%'
AND s.local_watershed_code IS NOT NULL
ORDER BY s.linear_feature_id, ST_Distance(ST_LineInterpolatePoint(s.geom, .5), ST_Centroid(w.geom));


-- For streams with no matching watershed based on watershed codes,
-- do a spatial join, selecting watershed that intersects the midpoint of the stream,
-- and where more than one watershed intersects, select the one with the closest centroid
INSERT INTO whse_basemapping.fwa_streams_watersheds_lut
(
  linear_feature_id,
  watershed_feature_id
)
SELECT DISTINCT ON (linear_feature_id)
  s.linear_feature_id,
  w.watershed_feature_id
FROM whse_basemapping.fwa_stream_networks_sp s
LEFT JOIN whse_basemapping.fwa_streams_watersheds_lut l
ON s.linear_feature_id = l.linear_feature_id
INNER JOIN whse_basemapping.fwa_watersheds_poly w
ON ST_Intersects(ST_LineInterpolatePoint(s.geom, .5), w.geom)
WHERE l.watershed_feature_id IS NULL -- extract only streams that are not already matched
AND s.watershed_group_code = :'wsg'
AND s.fwa_watershed_code NOT LIKE '999%'
AND s.local_watershed_code IS NOT NULL
ORDER BY s.linear_feature_id, ST_Distance(ST_LineInterpolatePoint(s.geom, .5), ST_Centroid(w.geom));
