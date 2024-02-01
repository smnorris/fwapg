-- Create measured channel width table

DROP TABLE IF EXISTS bcfishpass.channel_width_measured;

CREATE TABLE bcfishpass.channel_width_measured
(
  channel_width_id serial primary key,
  stream_sample_site_ids integer[],
  stream_crossing_ids integer[],
  wscode_ltree ltree,
  localcode_ltree ltree,
  watershed_group_code text,
  channel_width_measured double precision,
  UNIQUE (wscode_ltree, localcode_ltree)
);



-- Measurement values are distinct for watershed code / local code combinations (stream segments between tribs),
-- where more than one measurement exists on a segment, the average is calculated
WITH fiss_measurements AS
(SELECT
  e.stream_sample_site_id,
  e.wscode_ltree,
  e.localcode_ltree,
  w.watershed_group_code,
  p.channel_width as channel_width_fiss
FROM bcfishpass.fiss_stream_sample_sites_events_sp e
INNER JOIN whse_fish.fiss_stream_sample_sites_sp p
ON e.stream_sample_site_id = p.stream_sample_site_id
LEFT OUTER JOIN whse_basemapping.fwa_watersheds_poly w
ON ST_Intersects(p.geom, w.geom)
INNER JOIN whse_basemapping.fwa_stream_networks_sp s
ON e.blue_line_key = s.blue_line_key
AND e.downstream_route_measure > s.downstream_route_measure
AND e.downstream_route_measure <= s.upstream_route_measure
WHERE p.channel_width IS NOT NULL
-- exclude these records due to errors in measurement and/or linking to streams
AND p.stream_sample_site_id NOT IN (44813,44815,10997,8518,37509,37510,53526,15603,98,8644,117,8627,142,8486,8609,15609,10356)
),

pscis_measurements AS
(
SELECT
  e.stream_crossing_id,
  e.wscode_ltree,
  e.localcode_ltree,
  s.watershed_group_code,
  a.downstream_channel_width as channel_width_pscis
FROM bcfishpass.pscis e
LEFT OUTER JOIN whse_fish.pscis_assessment_svw a
ON e.stream_crossing_id = a.stream_crossing_id
LEFT OUTER JOIN whse_basemapping.fwa_watersheds_poly w
ON ST_Intersects(e.geom, w.geom)
INNER JOIN whse_basemapping.fwa_stream_networks_sp s
ON e.blue_line_key = s.blue_line_key
AND e.downstream_route_measure > s.downstream_route_measure
AND e.downstream_route_measure <= s.upstream_route_measure
WHERE a.downstream_channel_width is not null
-- exclude these records due to errors in measurement and/or linking to streams
AND e.stream_crossing_id NOT IN (57592,123894,57408,124137)
),

combined AS
(SELECT
  f.stream_sample_site_id,
  p.stream_crossing_id,
  coalesce(f.wscode_ltree, p.wscode_ltree) as wscode_ltree,
  coalesce(f.localcode_ltree, p.localcode_ltree) as localcode_ltree,
  coalesce(f.watershed_group_code, p.watershed_group_code) as watershed_group_code,
  coalesce(f.channel_width_fiss, p.channel_width_pscis) as channel_width
FROM fiss_measurements f
FULL OUTER JOIN pscis_measurements p
ON f.wscode_ltree = p.wscode_ltree
AND f.localcode_ltree = p.localcode_ltree)

INSERT INTO bcfishpass.channel_width_measured
(
  stream_sample_site_ids,
  stream_crossing_ids,
  wscode_ltree,
  localcode_ltree,
  watershed_group_code,
  channel_width_measured
)
SELECT
 array_agg(stream_sample_site_id) filter (where stream_sample_site_id is not null) as stream_sample_site_ids,
 array_agg(stream_crossing_id) filter (where stream_crossing_id is not null) AS stream_crossing_ids,
 wscode_ltree,
 localcode_ltree,
 watershed_group_code,
 round(avg(channel_width)::numeric, 2) as channel_width_measured  -- average PSCIS/FISS values on the same stream
FROM combined
GROUP BY
 wscode_ltree,
 localcode_ltree,
 watershed_group_code;

CREATE INDEX ON bcfishpass.channel_width_measured USING GIST (wscode_ltree);
CREATE INDEX ON bcfishpass.channel_width_measured USING BTREE (wscode_ltree);
CREATE INDEX ON bcfishpass.channel_width_measured USING GIST (localcode_ltree);
CREATE INDEX ON bcfishpass.channel_width_measured USING BTREE (localcode_ltree);