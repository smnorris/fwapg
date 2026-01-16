-- Load mean annual precipitation for each stream segment.
-- Insert the precip on the stream, and the area of the fundamental watershed(s) associated with the stream

INSERT INTO whse_basemapping.fwa_stream_networks_mean_annual_precip (
  wscode_ltree,
  localcode_ltree,
  watershed_group_code,
  area,
  map
) 
SELECT
  b.wscode_ltree,
  b.localcode_ltree,
  b.watershed_group_code,
  greatest(round(sum(ST_Area(b.geom))), 1)::bigint as area, -- prevent rounding by zero errors by replacing 0 area with 1
  avg(a.map)::integer as map
FROM fwapg.mean_annual_precip_load_ply a
INNER JOIN whse_basemapping.fwa_watersheds_poly b
ON a.watershed_feature_id = b.watershed_feature_id
WHERE 
  a.map IS NOT NULL AND 
  b.wscode_ltree IS NOT NULL AND 
  b.localcode_ltree IS NOT NULL AND 
  b.watershed_group_code = :'wsg'
GROUP BY b.wscode_ltree, b.localcode_ltree, b.watershed_group_code
ON CONFLICT DO NOTHING;

INSERT INTO whse_basemapping.fwa_stream_networks_mean_annual_precip (
  wscode_ltree,
  localcode_ltree,
  watershed_group_code,
  area,
  map
) 
SELECT
  b.wscode_ltree,
  b.localcode_ltree,
  b.watershed_group_code,
  greatest(round(sum(ST_Area(b.geom))), 1)::bigint as area, -- prevent rounding by zero errors by replacing 0 area with 1
  avg(a.map)::integer as map
FROM fwapg.mean_annual_precip_load_climr_ply a
INNER JOIN whse_basemapping.fwa_watersheds_poly b
ON a.watershed_feature_id = b.watershed_feature_id
WHERE 
  a.map IS NOT NULL AND 
  b.wscode_ltree IS NOT NULL AND 
  b.localcode_ltree IS NOT NULL AND 
  b.watershed_group_code = :'wsg'
GROUP BY b.wscode_ltree, b.localcode_ltree, b.watershed_group_code
ON CONFLICT DO NOTHING;

INSERT INTO whse_basemapping.fwa_stream_networks_mean_annual_precip (
  wscode_ltree,
  localcode_ltree,
  watershed_group_code,
  area,
  map
) 
SELECT
  wscode_ltree,
  localcode_ltree,
  watershed_group_code,
  1 as area,  -- again, to prevent round by zero errors
  round(map::numeric)::integer as map
FROM fwapg.mean_annual_precip_load_ln
WHERE 
  wscode_ltree IS NOT NULL AND 
  localcode_ltree IS NOT NULL AND
  watershed_group_code = :'wsg'
ON CONFLICT DO NOTHING;