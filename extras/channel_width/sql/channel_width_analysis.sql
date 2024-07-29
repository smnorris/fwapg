-- Create table for channel width analysis/modelling, holding all measured values 
-- (measured in field and as mapped in FWA)
-- Output is used to derive formula for estimating channel width


DROP TABLE IF EXISTS fwapg.channel_width_analysis;

CREATE TABLE fwapg.channel_width_analysis
(
  channel_width_id serial primary key,
  stream_sample_site_id integer,
  stream_crossing_id integer,
  source text,
  linear_feature_id bigint,
  blue_line_key integer,
  downstream_route_measure double precision,
  wscode_ltree ltree,
  localcode_ltree ltree,
  watershed_group_code text,
  channel_width double precision,
  cw_stddev double precision,
  stream_order integer,
  stream_magnitude integer,
  gradient double precision,
  length_metre double precision,
  elevation double precision,
  upstream_area double precision,
  upstream_area_lake double precision,
  upstream_area_manmade double precision,
  upstream_area_wetland double precision,
  --ecoregion_code text,
  --ecosection_code text,
  --zone text,
  map integer,
  map_upstream integer,
  lon double precision,
  lat double precision,
  geom geometry(Point, 3005)
);

-- combine the three sources
WITH measurements AS
(
SELECT
  e.stream_sample_site_id,
  NULL as stream_crossing_id,
  'FISS' as source,
  e.linear_feature_id,
  e.blue_line_key,
  e.downstream_route_measure,
  0 as cw_stddev,
  p.channel_width,
  (st_dump(p.geom)).geom as geom
FROM fwapg.fiss_stream_sample_sites_events_sp e
INNER JOIN fwapg.fiss_stream_sample_sites_sp p
ON e.stream_sample_site_id = p.stream_sample_site_id
WHERE p.channel_width IS NOT NULL
UNION ALL
SELECT
  NULL as stream_sample_site_id,
  e.stream_crossing_id,
  'PSCIS' as source,
  e.linear_feature_id,
  e.blue_line_key,
  e.downstream_route_measure,
  0 as cw_stddev,
  a.downstream_channel_width as channel_width,
  (st_dump(e.geom)).geom as geom
FROM fwapg.pscis_crossings e
LEFT OUTER JOIN fwapg.pscis_assessment_svw a
ON e.stream_crossing_id = a.stream_crossing_id
WHERE a.downstream_channel_width IS NOT NULL
UNION ALL
SELECT
  NULL as stream_sample_site_id,
  NULL as stream_crossing_id,
  'FWA' as source,
  c.linear_feature_id,
  s.blue_line_key,
  s.downstream_route_measure,
  c.cw_stddev,
  c.channel_width_mapped as channel_width,
  (st_dump(st_pointonsurface(s.geom))).geom as geom
FROM fwapg.channel_width_mapped c
INNER JOIN whse_basemapping.fwa_stream_networks_sp s
ON c.linear_feature_id = s.linear_feature_id
)

INSERT INTO fwapg.channel_width_analysis
( stream_sample_site_id,
  stream_crossing_id,
  source,
  linear_feature_id,
  blue_line_key,
  downstream_route_measure,
  wscode_ltree,
  localcode_ltree,
  watershed_group_code,
  channel_width,
  cw_stddev,
  stream_order,
  stream_magnitude,
  gradient,
  length_metre,
  elevation,
  upstream_area,
  upstream_area_lake,
  upstream_area_manmade,
  upstream_area_wetland,
  --ecoregion_code,
  --ecosection_code,
  --zone,
  map,
  map_upstream,
  lon,
  lat,
  geom
)

SELECT DISTINCT ON (blue_line_key, downstream_route_measure)
  m.stream_sample_site_id,
  m.stream_crossing_id,
  m.source,
  m.linear_feature_id,
  m.blue_line_key,
  m.downstream_route_measure,
  s.wscode_ltree,
  s.localcode_ltree,
  s.watershed_group_code,
  m.channel_width,
  m.cw_stddev,
  s.stream_order,
  s.stream_magnitude,
  s.gradient,
  s.length_metre,
  ROUND((ST_Z(ST_PointN(s.geom, - 1)))::numeric) as elevation,
  -- get upstream areas
  coalesce(ua.upstream_area_ha, 0) as upstream_area_ha,
  coalesce(uwb.upstream_lake_ha, 0) as upstream_lake_ha,
  coalesce(uwb.upstream_reservoir_ha, 0) as upstream_reservoir_ha,
  coalesce(uwb.upstream_wetland_ha, 0) as upstream_wetland_ha,
  --es.parent_ecoregion_code as ecoregion_code,
  --es.ecosection_code,
  --bec.zone,
  map.map,
  map.map_upstream,
  st_x(st_transform(m.geom, 4326)) as lon,
  st_y(st_transform(m.geom, 4326)) as lat,
  ST_Force2d(m.geom) as geom
FROM measurements m
INNER JOIN whse_basemapping.fwa_stream_networks_sp s
ON m.linear_feature_id = s.linear_feature_id
INNER JOIN whse_basemapping.fwa_watersheds_poly w
ON ST_Intersects(m.geom, w.geom)  -- joining rivers to watersheds is problematic, do it spatially and keep just one result (points on centerline will generally intersect 2 watersheds)
INNER JOIN whse_basemapping.fwa_watersheds_upstream_area ua
ON w.watershed_feature_id = ua.watershed_feature_id
INNER JOIN whse_basemapping.fwa_waterbodies_upstream_area uwb
ON s.linear_feature_id = uwb.linear_feature_id
--LEFT OUTER JOIN whse_terrestrial_ecology.erc_ecosections_subdivided es
--ON ST_Intersects(m.geom, es.geom)
--LEFT OUTER JOIN whse_forest_vegetation.bec_biogeoclimatic_poly_subdivided bec
--ON ST_Intersects(m.geom, bec.geom)
LEFT OUTER JOIN whse_basemapping.fwa_stream_networks_mean_annual_precip map
ON s.wscode_ltree = map.wscode_ltree AND s.localcode_ltree = map.localcode_ltree
ORDER BY blue_line_key, downstream_route_measure, stream_sample_site_id, stream_crossing_id;

CREATE INDEX ON fwapg.channel_width_analysis USING GIST (geom);
