-- Returns:
-- - linear_feature_id        - primary key of the matched stream
-- - gnis_name                - name of the nearest stream
-- - wscode_ltree             - FWA Watershed Code of the nearest stream (as ltree)
-- - localcode_ltree          - Local Watershed Code of the nearest stream (as ltree)
-- - blue_line_key            - blue_line_key of the nearest stream
-- - downstream_route_measure - the measure at closest point of stream to the provided point
-- - distance_to_stream       - the distance from point to closest point on the stream
-- - bc_ind                   - indicates if the stream is in BC
-- - geom                     - point geometry of closest location on the stream (at downstream_route_measure)

CREATE OR REPLACE FUNCTION FWA_IndexPoint(
    point geometry(Point, 3005),
    tolerance float DEFAULT 5000,
    num_features integer DEFAULT 1
)

RETURNS TABLE
    (
        linear_feature_id bigint,
        gnis_name text,
        wscode_ltree ltree,
        localcode_ltree ltree,
        blue_line_key integer,
        downstream_route_measure float,
        distance_to_stream float,
        bc_ind boolean,
        geom geometry(Point, 3005)
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
        SELECT $1 as geom
    ) p
    LEFT OUTER JOIN whse_basemapping.fwa_watershed_groups wsg
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
            WHERE NOT wscode_ltree <@ '999'
            -- do not use 6010 lines, only return nearest stream inside BC
            AND edge_type != 6010
            ORDER BY str.geom <-> (select geom from pt)
            LIMIT 100
        ) AS f
    ORDER BY blue_line_key, distance_to_stream
) b
WHERE distance_to_stream <= $2
ORDER BY distance_to_stream asc
LIMIT $3

$$
language 'sql' immutable parallel safe;

COMMENT ON FUNCTION FWA_IndexPoint(geometry(Point, 3005), float, integer) IS 'Provided a BC Albers point geometry, return the point indexed (snapped) to nearest stream(s) within specified tolerance (m)';



CREATE OR REPLACE FUNCTION postgisftw.FWA_IndexPoint(
    x float,
    y float,
    srid integer,
    tolerance float DEFAULT 5000,
    num_features integer DEFAULT 1
)

RETURNS TABLE
    (
        linear_feature_id bigint,
        gnis_name text,
        wscode_ltree ltree,
        localcode_ltree ltree,
        blue_line_key integer,
        downstream_route_measure float,
        distance_to_stream float,
        bc_ind boolean,
        geom geometry(Point, 3005)
    )

AS

$$

WITH pt AS

(
  SELECT ST_Transform(ST_SetSRID(ST_Makepoint($1, $2), $3), 3005) as geom
)

SELECT FWA_IndexPoint(pt.geom, $4, $5)
FROM pt

$$
language 'sql' immutable parallel safe;

COMMENT ON FUNCTION postgisftw.FWA_IndexPoint(float, float, integer, float, integer) IS 'Provided a point (as x,y coordinates and EPSG code), return the point indexed (snapped) to nearest stream(s) within specified tolerance (m)';
