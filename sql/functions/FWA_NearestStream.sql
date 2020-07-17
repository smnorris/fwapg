-- Find the n (default of 1) nearest streams within specified distance (default of 5km) of provided point
-- PLUS,
-- - linear_feature_id        - primary key of the matched stream
-- - gnis_name                - name of the nearest stream
-- - wscode_ltree             - FWA Watershed Code of the nearest stream (as ltree)
-- - localcode_ltree          - Local Watershed Code of the nearest stream (as ltree)
-- - blue_line_key            - blue_line_key of the nearest stream
-- - downstream_route_measure - the measure at closest point of stream to the provided point
-- - distance_to_stream       - the distance from point to closest point on the stream
-- - bc_ind                   - indicates if the stream is in BC
-- - geom                     - geometry of closest point on the stream

CREATE OR REPLACE FUNCTION postgisftw.FWA_NearestStream(x float, y float, srid integer, tolerance float DEFAULT 5000, num_features integer DEFAULT 1)

RETURNS TABLE
    (
        linear_feature_id bigint,
        gnis_name text,
        wscode_ltree text,
        localcode_ltree text,
        blue_line_key integer,
        downstream_route_measure float,
        distance_to_stream float,
        bc_ind boolean,
        geom geometry
    )

AS

$$

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
        SELECT
            ST_Transform(
              ST_SetSRID(
                ST_Makepoint(x, y
                ), srid
              ), 3005
            ) as geom
    ) p
    LEFT OUTER JOIN whse_basemapping.fwa_watershed_groups_subdivided wsg
    ON ST_intersects(p.geom, wsg.geom)
)


SELECT
    linear_feature_id,
    gnis_name,
    wscode_ltree::text,
    localcode_ltree::text,
    blue_line_key,
    (ST_LineLocatePoint(stream_geom,
      ST_ClosestPoint(stream_geom, pt_geom))
      * length_metre
    ) + downstream_route_measure AS downstream_route_measure,
    distance_to_stream,
    bc_ind,
    ST_Transform(ST_ClosestPoint(stream_geom, pt_geom), srid) as geom
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
            WHERE NOT wscode_ltree <@ '999'
            -- do not use 6010 lines, only return nearest stream inside BC
            AND edge_type != 6010
            ORDER BY str.geom <-> (select geom from pt)
            LIMIT 100
        ) AS f
    ORDER BY blue_line_key, distance_to_stream
) b
WHERE distance_to_stream <= tolerance
ORDER BY distance_to_stream asc
LIMIT num_features

$$
language 'sql' immutable parallel safe;