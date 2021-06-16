
INSERT INTO whse_basemapping.fwa_watersheds_upstream_area
(watershed_feature_id, upstream_area)

-- find total area of watershed groups upstream of individual fundamental watersheds
WITH wsg AS
(
SELECT
    a.watershed_feature_id,
    SUM(COALESCE(ST_Area(b.geom), 0)) as area
FROM whse_basemapping.fwa_watersheds_poly a
LEFT JOIN whse_basemapping.fwa_watershed_groups_poly b
ON FWA_Upstream(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
AND a.watershed_group_code != b.watershed_group_code
WHERE a.watershed_group_code = :'wsg'
GROUP BY a.watershed_feature_id
),

-- find total area of fundamental watersheds upstream of individual fund. watersheds, within same wsg
funds AS
(
SELECT
    a.watershed_feature_id,
    SUM(ST_Area(b.geom)) as area
FROM whse_basemapping.fwa_watersheds_poly a
INNER JOIN whse_basemapping.fwa_watersheds_poly b
ON FWA_Upstream(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
AND a.watershed_group_code = b.watershed_group_code
WHERE a.watershed_group_code = :'wsg'
GROUP by a.watershed_feature_id
)

-- add it all together
SELECT
    wsg.watershed_feature_id,
    wsg.area + funds.area as upstream_area
FROM wsg
INNER JOIN funds ON wsg.watershed_feature_id = funds.watershed_feature_id ;
