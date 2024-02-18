-- Record area of lakes/reservoirs/wetlands upstream of every stream line
-- This should be reasonably accurate in most areas - but use with caution in the far NE,
-- areas of extensive wetland will likely have issues, connectivity can be arbitrary

DROP TABLE IF EXISTS fwapg.fwa_waterbodies_upstream_area_:wsg;

CREATE table fwapg.fwa_waterbodies_upstream_area_:wsg (
  linear_feature_id bigint,
  upstream_lake_ha double precision,
  upstream_reservoir_ha double precision,
  upstream_wetland_ha double precision
);

INSERT INTO fwapg.fwa_waterbodies_upstream_area_:wsg
(
  linear_feature_id,
  upstream_lake_ha,
  upstream_reservoir_ha,
  upstream_wetland_ha
)
SELECT DISTINCT
  a.linear_feature_id,
  (SUM(COALESCE(ST_Area(l.geom), 0)) / 10000) AS upstream_lake_ha,
  (SUM(COALESCE(ST_Area(r.geom), 0)) / 10000) AS upstream_reservoir_ha,
  (SUM(COALESCE(ST_Area(w.geom), 0)) / 10000) AS upstream_wetland_ha
FROM whse_basemapping.fwa_stream_networks_sp a
INNER JOIN whse_basemapping.fwa_waterbodies b
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
LEFT OUTER JOIN whse_basemapping.fwa_lakes_poly l
ON b.waterbody_key = l.waterbody_key
LEFT OUTER JOIN whse_basemapping.fwa_wetlands_poly w
ON b.waterbody_key = w.waterbody_key
LEFT OUTER JOIN whse_basemapping.fwa_manmade_waterbodies_poly r
ON b.waterbody_key = r.waterbody_key
WHERE a.watershed_group_code = :'wsg'
AND NOT a.wscode_ltree <@ '999'
AND a.localcode_ltree IS NOT NULL
GROUP BY a.linear_feature_id;
