BEGIN;

-- fixes:

-- 1. ensure points equidistant to two segments on the same blkey are always matched to the same segment
--   (geom length and measure inconsistencies make this important, a measure output from this func previously
--   may not have actually been on the returned segment's geom)

-- 2. order results by unrounded distance, plus by id for consistency with equidistant matches

CREATE OR REPLACE FUNCTION whse_basemapping.fwa_indexpoint(point public.geometry, tolerance double precision DEFAULT 5000, num_features integer DEFAULT 1) RETURNS TABLE(linear_feature_id bigint, gnis_name text, wscode_ltree public.ltree, localcode_ltree public.ltree, blue_line_key integer, downstream_route_measure double precision, distance_to_stream double precision, bc_ind boolean, geom public.geometry)
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $_$

WITH pt AS

(
    SELECT
      p.geom,
      CASE
        WHEN wsg.watershed_group_code is NULL THEN False
        ELSE True
      END as bc_ind
    FROM
    (
        SELECT $1 as geom
    ) p
    LEFT OUTER JOIN whse_basemapping.fwa_watershed_groups_poly wsg
    ON ST_intersects(p.geom, wsg.geom)
)

SELECT
    linear_feature_id,
    gnis_name,
    wscode_ltree,
    localcode_ltree,
    blue_line_key,
    (ST_LineLocatePoint(stream_geom,
      ST_ClosestPoint(stream_geom, pt_geom))
      * length_metre
    ) + downstream_route_measure AS downstream_route_measure,
    ROUND(distance_to_stream::numeric, 3) AS distance_to_stream,
    bc_ind,
    ST_ClosestPoint(stream_geom, pt_geom) as geom
FROM
(
    SELECT DISTINCT ON (blue_line_key)
        linear_feature_id,
        gnis_name,
        wscode_ltree,
        localcode_ltree,
        blue_line_key,
        length_metre,
        downstream_route_measure,
        stream_geom,
        pt_geom,
        bc_ind,
        distance_to_stream
    FROM
        (
            SELECT
                linear_feature_id,
                gnis_name,
                wscode_ltree,
                localcode_ltree,
                blue_line_key,
                length_metre,
                downstream_route_measure,
                ST_LineMerge(str.geom) as stream_geom,
                pt.geom as pt_geom,
                ST_Distance(str.geom, pt.geom) as distance_to_stream,
                pt.bc_ind
            FROM whse_basemapping.fwa_stream_networks_sp AS str,
            pt
            -- do not use 6010 lines, only return nearest stream inside BC
            WHERE edge_type != 6010
            ORDER BY str.geom <-> (select geom from pt)
            LIMIT 100
        ) AS f
    -- when two segments of the same stream are equidistant, order by measure in descending order to always return upper segment
    ORDER BY blue_line_key, distance_to_stream, downstream_route_measure DESC
) b
WHERE distance_to_stream <= $2
ORDER BY b.distance_to_stream asc, linear_feature_id  -- order by unrounded distance, plus by id (so equidistant records are always in the same order)
LIMIT $3

$_$;

COMMIT;
