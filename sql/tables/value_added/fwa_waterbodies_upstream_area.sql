-- Record area of lakes/reservoirs/wetlands upstream of every stream line
-- This should be reasonably accurate in most areas - but use with caution in the far NE,
-- areas of extensive wetland will likely have issues, connectivity can be arbitrary

WITH upstr_wb AS
(SELECT DISTINCT
  a.linear_feature_id,
  ST_Area(lake.geom) as area_lake,
  ST_Area(manmade.geom) as area_manmade,
  ST_Area(wetland.geom) as area_wetland
FROM whse_basemapping.fwa_stream_networks_sp a
INNER JOIN whse_basemapping.fwa_stream_networks_sp b
ON FWA_Upstream(
    a.blue_line_key,
    a.downstream_route_measure,
    a.wscode_ltree,
    a.localcode_ltree,
    b.blue_line_key,
    b.downstream_route_measure,
    b.wscode_ltree,
    b.localcode_ltree,
    True,
    .02
   )
LEFT OUTER JOIN whse_basemapping.fwa_lakes_poly lake
ON b.waterbody_key = lake.waterbody_key
LEFT OUTER JOIN whse_basemapping.fwa_manmade_waterbodies_poly manmade
ON b.waterbody_key = manmade.waterbody_key
LEFT OUTER JOIN whse_basemapping.fwa_wetlands_poly wetland
ON b.waterbody_key = wetland.waterbody_key
WHERE b.waterbody_key IS NOT NULL
AND a.watershed_group_code = :'wsg'
ORDER BY a.linear_feature_id
)

INSERT INTO whse_basemapping.fwa_waterbodies_upstream_area
SELECT
  linear_feature_id,
  ROUND((SUM(COALESCE(uwb.area_lake, 0)) / 10000)::numeric, 2) AS upstream_lake_ha,
  ROUND((SUM(COALESCE(uwb.area_manmade, 0)) / 10000)::numeric, 2) AS upstream_reservoir_ha,
  ROUND((SUM(COALESCE(uwb.area_wetland, 0)) / 10000)::numeric, 2) AS upstream_wetland_ha
FROM upstr_wb uwb
GROUP BY linear_feature_id;