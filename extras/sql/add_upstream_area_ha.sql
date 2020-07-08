WITH
-- query only the watershed group of interest
wsg AS
(
  SELECT *
  FROM whse_basemapping.fwa_watershed_groups_poly a
  WHERE watershed_group_code = %s
),

-- extract streams within watershed group
streams AS
(
  SELECT s.*
  FROM whse_basemapping.fwa_stream_networks_sp s
  INNER JOIN wsg
  ON s.watershed_group_code = wsg.watershed_group_code
),

-- find any upstream watershed groups upstream of the group
groups AS
(
  SELECT
    b.watershed_group_id,
    b.wscode_ltree,
    b.localcode_ltree,
    ST_Area(b.geom) as area
  FROM wsg a
  INNER JOIN whse_basemapping.fwa_watershed_groups_poly b
  ON FWA_Upstream(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
  AND a.localcode_ltree != b.localcode_ltree
),

-- find fundamental watersheds upstream of each stream segment
-- (not covered by upstream assessment wsds and within the same watershed group,
-- and not with the same local code)
fund AS
(
SELECT
  a.linear_feature_id,
  a.wscode_ltree,
  a.localcode_ltree,
  ST_Area(b.geom) as area
FROM streams a
INNER JOIN whse_basemapping.fwa_watersheds_poly b
ON a.watershed_group_code = b.watershed_group_code
AND FWA_Upstream(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
AND a.localcode_ltree != b.localcode_ltree

),

-- find watersheds upstream of each single line stream flow segment
-- that are in lakes/reservoirs (they get missed by above query
-- because they have equivalent watershed codes)
wb AS
(SELECT
  a.linear_feature_id,
  a.wscode_ltree,
  a.localcode_ltree,
  ST_Area(w.geom) as area
FROM streams a
INNER JOIN whse_basemapping.fwa_watersheds_poly w
ON a.wscode_ltree = w.wscode_ltree AND
   a.localcode_ltree = w.localcode_ltree AND
   a.watershed_group_code = w.watershed_group_code
INNER JOIN whse_basemapping.fwa_waterbodies wb
ON w.waterbody_key = wb.waterbody_key
WHERE wb.waterbody_type IN ('L', 'X')
AND a.edge_type in (1000, 1050, 1100, 2000, 2300)
)

-- add things up and put it all together
INSERT INTO whse_basemapping.fwa_stream_networks_sp_upstr_area
(linear_feature_id, upstream_area_ha)

  SELECT
    a.linear_feature_id,
    round(((a.area_f + coalesce(b.area_wb, 0) + coalesce(g.area_groups, 0)) / 10000)::numeric, 4) as upstream_area_ha
  FROM
  (
    SELECT
      linear_feature_id,
      wscode_ltree,
      localcode_ltree,
      SUM(area) as area_f
    FROM fund
    GROUP BY linear_feature_id, wscode_ltree, localcode_ltree
  ) a
  LEFT OUTER JOIN
  (
    SELECT
      linear_feature_id,
      SUM(area) as area_wb
    FROM wb
    GROUP BY linear_feature_id
  ) b
  ON a.linear_feature_id = b.linear_feature_id
  LEFT OUTER JOIN
  (
    SELECT
      min(wscode_ltree::text) as wscode_ltree,
      min(localcode_ltree::text) as localcode_ltree,
      SUM(area) as area_groups
    FROM groups
  ) g
  ON FWA_Upstream(a.wscode_ltree, a.localcode_ltree, g.wscode_ltree::ltree, g.localcode_ltree::ltree);