-- return stream(s) nearest to point, within specified tolerance

CREATE OR REPLACE FUNCTION postgisftw.FWA_NearestStream(blkey integer, meas float)

RETURNS TABLE
 (wscode_ltree text,
  localcode_ltree text,
  area_ha numeric,
  refine_method text,
  geom geometry)
AS


$$
begin


WITH pt AS

(SELECT
  p.geom,
  CASE
    WHEN wsg.watershed_group_code is NULL then 'NOTBC'
    ELSE 'BC'
  END as bc_ind
FROM
(
    SELECT
        ST_Transform(
          ST_SetSRID(
            ST_Makepoint(-115.96917, 48.56194
                ), 4326
            ), 3005
          ) as geom
) p
LEFT OUTER JOIN whse_basemapping.fwa_watershed_groups_subdivided wsg
ON ST_intersects(p.geom, wsg.geom)
)


SELECT
    linear_feature_id,
    gnis_name,
    wscode_ltree,
    localcode_ltree,
    blue_line_key,
    distance_to_stream,
    (ST_LineLocatePoint(geom,
      ST_ClosestPoint(geom, pt_geom))
      * length_metre
    ) + downstream_route_measure AS downstream_route_measure,
    bc_ind,
    ST_Transform(ST_ClosestPoint(geom, pt_geom), 4326) as geom
FROM
(
SELECT DISTINCT ON (blue_line_key)
    linear_feature_id,
    gnis_name,
    wscode_ltree::text,
    localcode_ltree::text,
    blue_line_key,
    length_metre,
    downstream_route_measure,
    geom,
    pt_geom,
    bc_ind,
    distance_to_stream
FROM
(
    SELECT
        linear_feature_id,
        gnis_name,
        wscode_ltree::text,
        localcode_ltree::text,
        blue_line_key,
        length_metre,
        downstream_route_measure,
        ST_LineMerge(str.geom) as geom,
        pt.geom as pt_geom,
        ST_Distance(str.geom, pt.geom) as distance_to_stream,
        pt.bc_ind
    FROM whse_basemapping.fwa_stream_networks_sp AS str,
    pt
    WHERE NOT wscode_ltree <@ '999'
    -- do not use 6010 lines, only return nearest stream inside BC
    AND edge_type != 6010
    ORDER BY str.geom <-> (select geom from pt)
    LIMIT 100
    )
 as f
ORDER BY blue_line_key, distance_to_stream
) b
ORDER BY distance_to_stream