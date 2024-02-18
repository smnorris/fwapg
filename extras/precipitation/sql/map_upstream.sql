-- calculate the area weighted mean of precip contributing to a stream
WITH areas AS
(SELECT
  a.id,
  b.map,
  b.area
FROM whse_basemapping.fwa_stream_networks_mean_annual_precip a
INNER JOIN whse_basemapping.fwa_stream_networks_mean_annual_precip b
ON FWA_Upstream(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
WHERE a.watershed_group_code = :'wsg'
),

totals AS
(
  SELECT
  a.id,
  SUM(area) as area
  FROM areas a
  GROUP BY a.id
),

weighting AS
(
SELECT
 a.id,
 a.area,
 b.area as area_total,
 a.area / b.area as pct,
 a.map,
 (a.area / b.area) * a.map as weighted_map
FROM areas a
INNER JOIN totals b ON a.id = b.id
),

weighted_mean AS
(
SELECT
  id,
  round(sum(weighted_map)) as map_upstream
FROM weighting
GROUP BY id
)

UPDATE whse_basemapping.fwa_stream_networks_mean_annual_precip s
SET map_upstream = w.map_upstream
FROM weighted_mean w
WHERE s.id = w.id;
