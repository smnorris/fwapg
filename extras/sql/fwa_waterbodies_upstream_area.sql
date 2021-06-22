WITH lake AS
(
SELECT
  a.watershed_feature_id,
  SUM(ST_Area(b.geom)) as upstream_area
FROM whse_basemapping.fwa_watersheds_poly a
INNER JOIN whse_basemapping.fwa_lakes_poly b
ON FWA_Upstream(
    a.wscode_ltree,
    a.localcode_ltree,
    b.wscode_ltree,
    b.localcode_ltree
   )
WHERE a.watershed_group_code = :'wsg'
GROUP BY a.watershed_feature_id
),

manmade AS
(
SELECT
  a.watershed_feature_id,
  SUM(ST_Area(b.geom)) as upstream_area
FROM whse_basemapping.fwa_watersheds_poly a
INNER JOIN whse_basemapping.fwa_manmade_waterbodies_poly b
ON FWA_Upstream(
    a.wscode_ltree,
    a.localcode_ltree,
    b.wscode_ltree,
    b.localcode_ltree
   )
WHERE a.watershed_group_code = :'wsg'
GROUP BY a.watershed_feature_id
),

wetland AS
(
SELECT
  a.watershed_feature_id,
  SUM(ST_Area(b.geom)) as upstream_area
FROM whse_basemapping.fwa_watersheds_poly a
INNER JOIN whse_basemapping.fwa_wetlands_poly b
ON FWA_Upstream(
    a.wscode_ltree,
    a.localcode_ltree,
    b.wscode_ltree,
    b.localcode_ltree
   )
WHERE a.watershed_group_code = :'wsg'
GROUP BY a.watershed_feature_id
)

INSERT INTO whse_basemapping.fwa_waterbodies_upstream_area
(watershed_feature_id, upstream_area_lake, upstream_area_manmade, upstream_area_wetland)
SELECT
 a.watershed_feature_id,
 ROUND(COALESCE(l.upstream_area, 0)) AS upstream_area_lake,
 ROUND(COALESCE(m.upstream_area, 0)) AS upstream_area_manmade,
 ROUND(COALESCE(w.upstream_area, 0)) AS upstream_area_wetland
FROM whse_basemapping.fwa_watersheds_poly a
LEFT JOIN lake l
ON a.watershed_feature_id = l.watershed_feature_id
LEFT JOIN manmade m
ON a.watershed_feature_id = m.watershed_feature_id
LEFT JOIN wetland w
ON a.watershed_feature_id = w.watershed_feature_id
WHERE a.watershed_group_code = :'wsg';