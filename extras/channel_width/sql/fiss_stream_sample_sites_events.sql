-- Join fiss sample sites to nearest streams within 100m,
-- then finalize match by preferring the stream with matching watershed codes

DROP TABLE IF EXISTS fwapg.fiss_stream_sample_sites_events_sp;

CREATE TABLE fwapg.fiss_stream_sample_sites_events_sp AS

WITH pts AS
(
  SELECT pt.stream_sample_site_id, pt.geom
  FROM whse_fish.fiss_stream_sample_sites_sp as pt
  INNER JOIN whse_basemapping.fwa_watershed_groups_poly wsd
  ON ST_Intersects(pt.geom, wsd.geom)
),

-- match pts to closest 10 streams within 150m
candidates AS
 ( SELECT
    pts.stream_sample_site_id,
    nn.linear_feature_id,
    nn.wscode_ltree,
    nn.localcode_ltree,
    nn.blue_line_key,
    nn.waterbody_key,
    nn.length_metre,
    nn.downstream_route_measure,
    nn.distance_to_stream,
    ST_LineMerge(nn.geom) AS geom
  FROM pts
  CROSS JOIN LATERAL
  (SELECT
     str.linear_feature_id,
     str.wscode_ltree,
     str.localcode_ltree,
     str.blue_line_key,
     str.waterbody_key,
     str.length_metre,
     str.downstream_route_measure,
     str.geom,
     ST_Distance(str.geom, pts.geom) as distance_to_stream
    FROM whse_basemapping.fwa_stream_networks_sp AS str
    WHERE str.localcode_ltree IS NOT NULL
    AND NOT str.wscode_ltree <@ '999'
    ORDER BY str.geom <-> pts.geom
    LIMIT 10) as nn
  WHERE nn.distance_to_stream < 150  -- the data seems suspect in some areas, tighten this up from 250 to 150 to avoid what appears to be bad matches
),

-- find just the closest point for distinct blue_line_keys -
-- we don't want to match to all individual stream segments
bluelines AS
(SELECT * FROM
    (SELECT
      stream_sample_site_id,
      blue_line_key,
      min(distance_to_stream) AS distance_to_stream
    FROM candidates
    GROUP BY stream_sample_site_id, blue_line_key) as f
  ORDER BY distance_to_stream
),

-- from the selected blue lines, generate downstream_route_measure
indexed AS
(SELECT
  bluelines.stream_sample_site_id,
  candidates.linear_feature_id,
  (REPLACE(REPLACE(lut.fwa_watershed_code_20k, '-000000', ''), '-', '.')::ltree) as wscode_ltree_lookup,
  candidates.wscode_ltree,
  candidates.localcode_ltree,
  candidates.waterbody_key,
  bluelines.blue_line_key,
  (ST_LineLocatePoint(candidates.geom,
                       ST_ClosestPoint(candidates.geom, pts.geom))
     * candidates.length_metre) + candidates.downstream_route_measure
    AS downstream_route_measure,
  candidates.distance_to_stream,
  (ST_Dump(ST_LocateAlong(
    s.geom,
    (ST_LineLocatePoint(candidates.geom,
                       ST_ClosestPoint(candidates.geom, pts.geom))
     * candidates.length_metre) + candidates.downstream_route_measure
    )
  )).geom::geometry(PointZM, 3005) as geom
FROM bluelines
INNER JOIN candidates ON bluelines.stream_sample_site_id = candidates.stream_sample_site_id
AND bluelines.blue_line_key = candidates.blue_line_key
AND bluelines.distance_to_stream = candidates.distance_to_stream
INNER JOIN whse_fish.fiss_stream_sample_sites_sp pts
ON bluelines.stream_sample_site_id = pts.stream_sample_site_id
INNER JOIN whse_basemapping.fwa_stream_networks_sp s
ON candidates.linear_feature_id = s.linear_feature_id
LEFT OUTER JOIN whse_basemapping.fwa_streams_20k_50k lut
ON REPLACE(pts.new_watershed_code,'-','') = lut.watershed_code_50k
)

-- grab closest with a matched code
SELECT DISTINCT ON (stream_sample_site_id) *
FROM indexed
WHERE wscode_ltree_lookup = wscode_ltree
ORDER BY indexed.stream_sample_site_id, indexed.distance_to_stream asc;


-- There are a lot of records very close to FWA streams that do not get matched.
-- Lets add them too if they are within 50m of the stream
WITH pts AS
(
  SELECT
    pt.stream_sample_site_id,
    pt.geom
  FROM whse_fish.fiss_stream_sample_sites_sp as pt
  INNER JOIN whse_basemapping.fwa_watershed_groups_poly wsd
  ON ST_Intersects(pt.geom, wsd.geom)
  LEFT OUTER JOIN fwapg.fiss_stream_sample_sites_events_sp e
  ON pt.stream_sample_site_id = e.stream_sample_site_id
  WHERE e.stream_sample_site_id IS NULL
),

-- match pts to closest 10 streams within 150m
candidates AS
(
  SELECT
    pts.stream_sample_site_id,
    nn.linear_feature_id,
    nn.wscode_ltree,
    nn.localcode_ltree,
    nn.blue_line_key,
    nn.waterbody_key,
    nn.length_metre,
    nn.downstream_route_measure,
    nn.distance_to_stream,
    ST_LineMerge(nn.geom) AS geom
  FROM pts
  CROSS JOIN LATERAL
  (SELECT
     str.linear_feature_id,
     str.wscode_ltree,
     str.localcode_ltree,
     str.blue_line_key,
     str.waterbody_key,
     str.length_metre,
     str.downstream_route_measure,
     str.geom,
     ST_Distance(str.geom, pts.geom) as distance_to_stream
    FROM whse_basemapping.fwa_stream_networks_sp AS str
    WHERE str.localcode_ltree IS NOT NULL
    AND NOT str.wscode_ltree <@ '999'
    ORDER BY str.geom <-> pts.geom
    LIMIT 1) as nn
  WHERE nn.distance_to_stream < 100
),

-- from the selected blue lines, generate downstream_route_measure
indexed AS
(SELECT
  c.stream_sample_site_id,
  c.linear_feature_id,
  c.wscode_ltree,
  c.localcode_ltree,
  c.waterbody_key,
  c.blue_line_key,
  (ST_LineLocatePoint(c.geom,
                       ST_ClosestPoint(c.geom, pts.geom))
     * c.length_metre) + c.downstream_route_measure
    AS downstream_route_measure,
  c.distance_to_stream,
  (ST_Dump(ST_LocateAlong(
    s.geom,
    (ST_LineLocatePoint(c.geom,
                       ST_ClosestPoint(c.geom, pts.geom))
     * c.length_metre) + c.downstream_route_measure
    )
  )).geom::geometry(PointZM, 3005) as geom
FROM candidates c
INNER JOIN whse_fish.fiss_stream_sample_sites_sp pts
ON c.stream_sample_site_id = pts.stream_sample_site_id
INNER JOIN whse_basemapping.fwa_stream_networks_sp s
ON c.linear_feature_id = s.linear_feature_id
)

INSERT INTO fwapg.fiss_stream_sample_sites_events_sp
(
  stream_sample_site_id,
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
  linear_feature_id,
  wscode_ltree,
  localcode_ltree,
  waterbody_key,
  downstream_route_measure,
  distance_to_stream,
  geom
FROM indexed;
