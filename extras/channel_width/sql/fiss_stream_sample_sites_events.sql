-- Join fiss sample sites to nearest streams within 100m,
-- then finalize match by preferring the stream with matching watershed codes

BEGIN;

  DROP TABLE IF EXISTS fwapg.fiss_stream_sample_sites_events_sp;

  CREATE TABLE fwapg.fiss_stream_sample_sites_events_sp AS

  WITH pts AS
  (
    SELECT pt.stream_sample_site_id, pt.geom
    FROM fwapg.fiss_stream_sample_sites_sp as pt
    INNER JOIN whse_basemapping.fwa_watershed_groups_poly wsd
    ON ST_Intersects(pt.geom, wsd.geom)
  ),

  -- match pts to the nearest point on each of the closest 10 streams within 150m,
  -- skipping disconnected (999) streams and streams with no local code
  indexed AS
  (SELECT
    pts.stream_sample_site_id,
    nn.linear_feature_id,
    (REPLACE(REPLACE(lut.fwa_watershed_code_20k, '-000000', ''), '-', '.')::ltree) as wscode_ltree_lookup,
    nn.wscode_ltree,
    nn.localcode_ltree,
    s.waterbody_key,
    nn.blue_line_key,
    nn.downstream_route_measure,
    nn.distance_to_stream,
    nn.geom::geometry(PointZM, 3005) as geom,
    nn.ordinality
  FROM pts
  CROSS JOIN LATERAL whse_basemapping.fwa_indexpoint(pts.geom, 150, 10, false, false) WITH ORDINALITY AS nn
  INNER JOIN fwapg.fiss_stream_sample_sites_sp site
  ON pts.stream_sample_site_id = site.stream_sample_site_id
  INNER JOIN whse_basemapping.fwa_stream_networks_sp s
  ON nn.linear_feature_id = s.linear_feature_id
  LEFT OUTER JOIN whse_basemapping.fwa_streams_20k_50k lut
  ON REPLACE(site.new_watershed_code,'-','') = lut.watershed_code_50k
  )

  -- grab closest with a matched code (fwa_indexpoint returns streams nearest first)
  SELECT DISTINCT ON (stream_sample_site_id)
    stream_sample_site_id,
    linear_feature_id,
    wscode_ltree_lookup,
    wscode_ltree,
    localcode_ltree,
    waterbody_key,
    blue_line_key,
    downstream_route_measure,
    distance_to_stream,
    geom
  FROM indexed
  WHERE wscode_ltree_lookup = wscode_ltree
  ORDER BY indexed.stream_sample_site_id, indexed.ordinality;

  -- There are a lot of records very close to FWA streams that do not get matched.
  -- Lets add them too if they are within 50m of the stream
  WITH pts AS
  (
    SELECT
      pt.stream_sample_site_id,
      pt.geom
    FROM fwapg.fiss_stream_sample_sites_sp as pt
    INNER JOIN whse_basemapping.fwa_watershed_groups_poly wsd
    ON ST_Intersects(pt.geom, wsd.geom)
    LEFT OUTER JOIN fwapg.fiss_stream_sample_sites_events_sp e
    ON pt.stream_sample_site_id = e.stream_sample_site_id
    WHERE e.stream_sample_site_id IS NULL
  ),

  -- match pts to the nearest point on the closest stream within 100m
  indexed AS
  (SELECT
    pts.stream_sample_site_id,
    nn.linear_feature_id,
    nn.wscode_ltree,
    nn.localcode_ltree,
    s.waterbody_key,
    nn.blue_line_key,
    nn.downstream_route_measure,
    nn.distance_to_stream,
    nn.geom::geometry(PointZM, 3005) as geom
  FROM pts
  CROSS JOIN LATERAL whse_basemapping.fwa_indexpoint(pts.geom, 100, 1, false, false) AS nn
  INNER JOIN whse_basemapping.fwa_stream_networks_sp s
  ON nn.linear_feature_id = s.linear_feature_id
  )

  INSERT INTO fwapg.fiss_stream_sample_sites_events_sp
  (
    stream_sample_site_id,
    blue_line_key,
    linear_feature_id,
    wscode_ltree,
    localcode_ltree,
    waterbody_key,
    downstream_route_measure,
    distance_to_stream,
    geom
  )
  SELECT
    stream_sample_site_id,
    blue_line_key,
    linear_feature_id,
    wscode_ltree,
    localcode_ltree,
    waterbody_key,
    downstream_route_measure,
    distance_to_stream,
    geom
  FROM indexed;

COMMIT;