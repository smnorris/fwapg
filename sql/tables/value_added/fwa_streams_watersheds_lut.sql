-- There is no existing 1:1 key relating streams and 
-- fundamental watersheds - a spatial query is necessary.
-- Speed future queries by running the spatial query 
-- for every stream, creating a lookup.

-- Because even using ST_PointOnSurface does not create
-- a 1:1 relationship (network connectors etc), find 
-- distinct by choosing the match with highest stream order.
-- (where the result is ambiguous it doesn't really matter
-- which watershed is chosen anyway)

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
ON ST_Intersects(ST_pointonsurface(s.geom), w.geom)
WHERE s.watershed_group_code = :'wsg'
ORDER BY s.linear_feature_id, s.stream_order;

COMMENT ON TABLE whse_basemapping.fwa_streams_watersheds_lut IS 'A convenience lookup for quickly relating streams and fundamental watersheds';
COMMENT ON COLUMN whse_basemapping.fwa_streams_watersheds_lut.linear_feature_id IS 'FWA stream segment unique identifier';
COMMENT ON COLUMN whse_basemapping.fwa_streams_watersheds_lut.watershed_feature_id IS 'FWA fundamental watershed unique identifer';
