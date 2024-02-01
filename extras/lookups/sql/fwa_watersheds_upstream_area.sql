SET max_parallel_workers_per_gather = 0;

DROP TABLE IF EXISTS temp.fwa_watersheds_upstream_area_:wsg;

CREATE table temp.fwa_watersheds_upstream_area_:wsg
(watershed_feature_id integer, upstream_area double precision);

INSERT INTO temp.fwa_watersheds_upstream_area_:wsg
(watershed_feature_id, upstream_area)

-- find total area of fundamental watersheds upstream
SELECT
    a.watershed_feature_id,
    (SUM(ST_Area(b.geom)) / 10000) as upstream_area_ha
FROM whse_basemapping.fwa_watersheds_poly a
INNER JOIN whse_basemapping.fwa_watersheds_poly b
ON FWA_Upstream(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
WHERE a.watershed_group_code = :'wsg'
GROUP by a.watershed_feature_id;