-- functions for publication by pg_featureserv / pg_tileserv must be created in postgisftw schema

-- -------------------------------------------------------------------------------------------------------------------------
-- FWA_IndexPoint
-- -------------------------------------------------------------------------------------------------------------------------
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



-- -------------------------------------------------------------------------------------------------------------------------
-- FWA_LocateAlong
-- -------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION postgisftw.FWA_LocateAlong(blue_line_key integer, downstream_route_measure float)

RETURNS TABLE (
    geom                     geometry(Point, 3005)
)

AS

$$

DECLARE
   v_blkey    integer := blue_line_key;
   v_measure  float   := downstream_route_measure;
   v_geom     geometry;

BEGIN

RETURN QUERY
SELECT distinct on (s.blue_line_key)
  (ST_Dump(ST_LocateAlong(s.geom, v_measure))).geom as geom
FROM whse_basemapping.fwa_stream_networks_sp AS s
WHERE s.blue_line_key = v_blkey
AND round(s.downstream_route_measure::numeric, 4) <= round(v_measure::numeric, 4)
AND round(s.upstream_route_measure::numeric, 4) > round(v_measure::numeric, 4)
order by s.blue_line_key, s.downstream_route_measure desc;
END

$$
LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION postgisftw.FWA_LocateAlong IS 'Return a point on the stream network based on the location provided by blue_line_key and downstream_route_measure'




-- -------------------------------------------------------------------------------------------------------------------------
-- FWA_LocateAlongInterval
-- -------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION postgisftw.FWA_LocateAlongInterval(blue_line_key integer, start_measure integer DEFAULT 0, interval_length integer DEFAULT 1000, end_measure integer DEFAULT NULL)

RETURNS TABLE
    (
        index                    integer,
        downstream_route_measure float,
        geom                     geometry(Point, 3005)
    )

AS

$$

DECLARE

   v_blkey          integer := blue_line_key;
   v_interval       integer := interval_length;
   v_measure_start  integer := start_measure;
   v_measure_end    integer := end_measure;
   v_measure_max    numeric;
   v_measure_min    numeric;

BEGIN

-- find min and max measures of the stream
-- (round measures to avoid floating point issues)
SELECT
  min(round(s.downstream_route_measure::numeric, 3)) as min_measure,
  max(round(s.upstream_route_measure::numeric, 3)) as max_measure
FROM whse_basemapping.fwa_stream_networks_sp s
WHERE s.blue_line_key = v_blkey
INTO v_measure_min, v_measure_max;

-- Check that the provided measure actually falls within the min/max measures of stream
-- (if portions of the stream do not exist in the db there will simply be gaps in returned points)
IF v_measure_start < v_measure_min OR v_measure_start > v_measure_max THEN
  RAISE EXCEPTION 'Input start_measure value does not exist in FWA';
END IF;

IF v_measure_end > v_measure_max THEN
  RAISE EXCEPTION 'Input end_measure value does not exist in FWA';
END IF;

IF v_measure_end <= v_measure_start THEN
  RAISE EXCEPTION 'Input end_measure value must be more than input start_measure value';
END IF;

IF (v_measure_end - v_measure_start) < v_interval THEN
  RAISE EXCEPTION 'Distance between start_measure and end_measure is less than input interval_length';
END IF;

-- if no end point provided, process the entire stream
IF v_measure_end IS NULL THEN
  v_measure_end := v_measure_max;
END IF;

RETURN QUERY

WITH intervals AS

(SELECT
  v_blkey as blue_line_key,
  generate_series(0, v_measure_end / v_interval) as n,
  generate_series(v_measure_start, v_measure_end, v_interval) as downstream_route_measure
),

segments AS
(
SELECT
  i.n,
  s.blue_line_key,
  s.linear_feature_id,
  i.downstream_route_measure,
  s.geom
FROM whse_basemapping.fwa_stream_networks_sp AS s
INNER JOIN intervals i
ON s.blue_line_key = i.blue_line_key
AND s.downstream_route_measure <= i.downstream_route_measure
AND s.upstream_route_measure > i.downstream_route_measure
)

SELECT
  s.n::integer as index,
  s.downstream_route_measure::float,
  postgisftw.FWA_LocateAlong(s.blue_line_key, s.downstream_route_measure::float) as geom
FROM segments s;

END;

$$
LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION postgisftw.FWA_LocateAlongInterval IS 'Return a table (index, measure, geom), representing points along a stream between specified locations at specified interval'



-- -------------------------------------------------------------------------------------------------------------------------
-- FWA_StreamsAsMVT
-- for pg_tileserv, scale dependent stream display
-- -------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION whse_basemapping.fwa_streamsasmvt(
            z integer, x integer, y integer)
RETURNS bytea
AS $$
DECLARE
    result bytea;
BEGIN
    WITH

    bounds AS (
      SELECT ST_TileEnvelope(z, x, y) AS geom
    ),

    mvtgeom AS (
      SELECT
        blue_line_key,
        gnis_name,
        stream_order_max,
        ST_AsMVTGeom(ST_Transform(ST_Force2D(s.geom), 3857), bounds.geom)
      FROM whse_basemapping.fwa_stream_networks_sp s, bounds
      WHERE ST_Intersects(s.geom, ST_Transform((select geom from bounds), 3005))
      AND s.edge_type != 6010
      AND wscode_ltree is not null
      AND stream_order_max >= (-z + 13)
     )

    SELECT ST_AsMVT(mvtgeom, 'default')
    INTO result
    FROM mvtgeom;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

COMMENT ON FUNCTION whse_basemapping.fwa_streamsasmvt IS 'Zoom-level dependent FWA streams';



-- -------------------------------------------------------------------------------------------------------------------------
-- FWA_WatershedAtMeasure
-- -------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION postgisftw.FWA_WatershedAtMeasure(blue_line_key integer, downstream_route_measure float)

RETURNS TABLE
 (wscode_ltree text,
  localcode_ltree text,
  area_ha numeric,
  refine_method text,
  geom geometry)
AS


$$

declare
   v_blkey    integer := blue_line_key;
   v_measure  float := downstream_route_measure;

begin
    if (
        -- is provided location in a lake or a non-canal reservoir?
        SELECT
          CASE
           WHEN (r.feature_code != 'GA03950000' OR r.feature_code IS NULL) AND wb.waterbody_type in ('L', 'X') THEN True
           ELSE False
          END as lake_check
        FROM whse_basemapping.fwa_stream_networks_sp s
        LEFT OUTER JOIN whse_basemapping.fwa_waterbodies wb
        ON s.waterbody_key = wb.waterbody_key
        LEFT OUTER JOIN whse_basemapping.fwa_manmade_waterbodies_poly r
        ON s.waterbody_key = r.waterbody_key
        WHERE s.blue_line_key = v_blkey
        AND s.downstream_route_measure <= v_measure
        ORDER BY s.downstream_route_measure desc
        LIMIT 1
    ) is false

    then return query
        -- non-lake/reservoir based watershed
        WITH ref_point_a AS
        (SELECT
          s.linear_feature_id,
          s.blue_line_key,
          s.downstream_route_measure as measure_str,
          v_measure as measure_pt,
          s.wscode_ltree,
          s.localcode_ltree,
          s.waterbody_key,
          -- identify canals as waterbody type 'C'
          CASE
           WHEN r.feature_code = 'GA03950000' THEN 'C'
           ELSE wb.waterbody_type
          END as waterbody_type,
          (ST_Dump(
             ST_LocateAlong(s.geom, v_measure)
             )
          ).geom::geometry(PointZM, 3005) AS geom_pt,
          s.geom as geom_str
        FROM whse_basemapping.fwa_stream_networks_sp s
        LEFT OUTER JOIN whse_basemapping.fwa_waterbodies wb
        ON s.waterbody_key = wb.waterbody_key
        LEFT OUTER JOIN whse_basemapping.fwa_manmade_waterbodies_poly r
        ON s.waterbody_key = r.waterbody_key
        WHERE s.blue_line_key = v_blkey
        AND s.downstream_route_measure <= v_measure
        ORDER BY s.downstream_route_measure desc
        LIMIT 1),

        -- also get the waterbody key of the watershed in which the point lies,
        -- *it is not always equivalent to the wbkey of the stream*
        -- (for example, on a river that is mapped as a stretch of pools and lines,
        -- the lines will also have a waterbody key value)
        ref_point AS (
        SELECT
          r.*,
          p.waterbody_key as waterbody_key_poly
        FROM ref_point_a r
        INNER JOIN whse_basemapping.fwa_watersheds_poly p
        ON ST_Intersects(r.geom_pt, p.geom)
        LIMIT 1 -- just in case the point intersects 2 polys (although hopefully this doesn't occur,
                -- this merely avoids the issue rather than choosing the best match)
        ),

        -- find all watershed polygons within 5m of the point
        wsd AS
        (SELECT
          array_agg(watershed_feature_id) as wsds,
          ST_Union(wsd.geom) as geom
         FROM whse_basemapping.fwa_watersheds_poly wsd
         INNER JOIN ref_point pt
         ON ST_DWithin(wsd.geom, pt.geom_pt, 5)
        ),

        -- find distance from point to top of watershed poly(s)
        length_to_top AS
        (SELECT
          (str.downstream_route_measure + str.length_metre) - refpt.measure_pt AS measure
        FROM whse_basemapping.fwa_stream_networks_sp str
        INNER JOIN ref_point refpt
          ON str.blue_line_key = refpt.blue_line_key
          AND str.wscode_ltree = refpt.wscode_ltree
        INNER JOIN wsd ON
        -- due to line imprecisions, we can't rely on joining stream lines to
        -- wsd using ST_CoveredBy() - shrink the stream line by 1cm first
        ST_CoveredBy(
            ST_LineSubstring(
              str.geom,
              .004 / ST_Length(str.geom),
              (ST_Length(str.geom) - .004) / ST_Length(str.geom)
            ),
          wsd.geom
        )
        ORDER BY str.downstream_route_measure desc
        LIMIT 1),

        -- find distance from point to bottom of watershed poly(s)
        length_to_bottom AS
        (SELECT
          refpt.measure_pt - str.downstream_route_measure AS measure
        FROM whse_basemapping.fwa_stream_networks_sp str
        INNER JOIN ref_point refpt
          ON str.blue_line_key = refpt.blue_line_key
          AND str.wscode_ltree = refpt.wscode_ltree
        INNER JOIN wsd ON

        -- due to line imprecisions, we can't rely on joining stream lines to
        -- wsd using ST_CoveredBy() - shrink the stream line by 1cm first
        ST_CoveredBy(
            ST_LineSubstring(
              str.geom,
              .004 / ST_Length(str.geom),
              (ST_Length(str.geom) - .004) / ST_Length(str.geom)
            ),
          wsd.geom
        )
        ORDER BY str.downstream_route_measure asc
        LIMIT 1),

        -- determine what needs to be done to watershed in which point lies
        method AS
        (
        SELECT
          r.*,
          t.measure as len_to_top,
          b.measure as len_to_bottom,
          CASE
-- when dealing with a river/canal, always try the cut method, there
-- are generally >1 polygons within the waterbody at the location of
-- interest and they start/end at different tribs, so some kind of
-- aggregation and split is usually needed
-- ** todo: a notable exception would be at the mouth of a river, where
-- r.measure_str=0 and b.measure <=50. This isn't a major issue as cutting
-- is computationally cheap and seems to work fine, even if point is at 0**
            WHEN r.waterbody_type IN ('C', 'R')
            AND r.waterbody_key_poly != 0 -- make sure point is actually in a waterbody when trying to cut
            THEN 'CUT'
-- if the location of interest is < 100m from the top of the local stream,
-- just drop the watershed in which it falls
            WHEN (r.waterbody_key IS NULL OR r.waterbody_type = 'W') AND t.measure <= 100 THEN 'DROP'
-- if the location of interest is <50m from the bottom of the local stream,
-- keep the watershed in which it falls with no modifications
            WHEN (r.waterbody_key IS NULL OR r.waterbody_type = 'W') AND b.measure <= 50 THEN 'KEEP'
-- otherwise, if location is on on single line stream and outside of above
-- endpoint tolerances, note that the watershed should be post-processed
-- with the DEM
            WHEN (r.waterbody_key is NULL OR r.waterbody_type = 'W' OR r.waterbody_key_poly = 0)
              AND t.measure > 100
              AND b.measure > 50 THEN 'DEM'
            END as refine_method

        FROM ref_point r, length_to_top t, length_to_bottom b
        ),

        -- get any upstream basins/groups/assessment wsds
        -- (to minimize features that need to be aggregated)
        -- first, the basins
        wsdbasins AS
        (
          SELECT
            b.basin_id,
            ST_Force2D(b.geom) as geom
          FROM ref_point a
          INNER JOIN whse_basemapping.fwa_basins_poly b
          ON FWA_Upstream(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
        ),

        -- similarly, get any upstream watershed groups
        -- (that are not covered by the pre-aggregated watersheds)
        wsdgroups AS (
          SELECT
            b.watershed_group_id,
            b.basin_id,
            ST_Force2D(b.geom) as geom
          FROM ref_point a
          INNER JOIN whse_basemapping.fwa_watershed_groups_poly b
          ON FWA_Upstream(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
          LEFT OUTER JOIN wsdbasins ON b.basin_id = wsdbasins.basin_id
          WHERE wsdbasins.basin_id IS NULL
        ),

        -- next, assessment watersheds
        wsdassmnt AS (
          SELECT
            b.watershed_feature_id as assmnt_watershed_id,
            g.watershed_group_id,
            g.basin_id,
            ST_Force2D(b.geom) as geom
          FROM ref_point a
          INNER JOIN whse_basemapping.fwa_assessment_watersheds_poly b
          ON FWA_Upstream(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
          -- do not include the assmnt watershed with equivalent codes
          AND NOT (a.wscode_ltree = b.wscode_ltree AND a.localcode_ltree = b.localcode_ltree)
          LEFT OUTER JOIN wsdgroups c ON b.watershed_group_id = c.watershed_group_id
          LEFT OUTER JOIN whse_basemapping.fwa_watershed_groups_poly g
          ON b.watershed_group_id = g.watershed_group_id
          WHERE c.watershed_group_id IS NULL AND g.basin_id IS NULL

        ),

        -- finally, fundamental watersheds
        prelim AS (
          SELECT
            b.watershed_feature_id,
            ST_Force2d(b.geom) as geom
          FROM ref_point a
          INNER JOIN whse_basemapping.fwa_watersheds_poly b
          ON FWA_Upstream(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
          LEFT OUTER JOIN whse_basemapping.fwa_assessment_watersheds_lut l
          ON b.watershed_feature_id = l.watershed_feature_id
          LEFT OUTER JOIN wsdassmnt c ON l.assmnt_watershed_id = c.assmnt_watershed_id
          LEFT OUTER JOIN wsdgroups d ON b.watershed_group_id = d.watershed_group_id
          LEFT OUTER JOIN whse_basemapping.fwa_watershed_groups_poly g
          ON b.watershed_group_id = g.watershed_group_id
          WHERE c.assmnt_watershed_id IS NULL
          AND d.watershed_group_id IS NULL
          AND g.basin_id NOT IN (SELECT basin_id FROM wsdbasins)
          -- don't include the fundamental watershed(s) in which the point lies
          AND b.watershed_feature_id NOT IN (SELECT unnest(wsds) from wsd)


        UNION

        -- add watersheds from adjacent lakes/reservoirs with equivalent watershed
        -- codes, in which the point does not lie. This is a bit of a quirk
        SELECT
          w.watershed_feature_id,
          ST_Force2D(w.geom) as geom
        FROM ref_point s
        INNER JOIN whse_basemapping.fwa_watersheds_poly w
        ON (s.wscode_ltree = w.wscode_ltree AND
           s.localcode_ltree = w.localcode_ltree)
        AND NOT ST_Intersects(w.geom, s.geom_pt)
        INNER JOIN whse_basemapping.fwa_waterbodies wb
        ON w.waterbody_key = wb.waterbody_key
        WHERE wb.waterbody_type IN ('L', 'X')
        ),

        -- Get the cut watershed
        -- (this returns nothing if the point is not on a river/canal)
        cut AS
        (SELECT
          slice.wsds, ST_Force2D(slice.geom) as geom
        FROM FWA_SliceWatershedAtPoint(v_blkey, v_measure) slice
        ),

        -- find any upstream contributing area outside of BC (but not including Alaska panhandle)
        exbc AS
         (
          SELECT hydrosheds.hydroshed(h.hybas_id) AS geom
          FROM ref_point s
          INNER JOIN hydrosheds.hybas_lev12_v1c h
          ON ST_Intersects(h.geom, s.geom_pt)
          WHERE FWA_UpstreamBorderCrossings(s.blue_line_key, s.measure_pt) IN ('AB_120','YTNWT_60')
          UNION ALL
          SELECT FWA_Huc12(h.huc12) AS geom
          FROM ref_point s
          INNER JOIN usgs.wbdhu12 h
          ON ST_intersects(h.geom, s.geom_pt)
          WHERE FWA_UpstreamBorderCrossings(s.blue_line_key, s.measure_pt) = 'USA_49'
        ),

        -- aggregate the result and dump to singlepart
        agg as
        (
        SELECT
          m.wscode_ltree,
          m.localcode_ltree,
          m.refine_method,
          (ST_Dump(ST_Buffer(
            ST_Collect(to_agg.geom), 0.001)
            )).geom AS geom
        FROM
        (
          SELECT wsdbasins.geom FROM wsdbasins

          UNION ALL
          SELECT wsdgroups.geom FROM wsdgroups

          UNION ALL
          SELECT wsdassmnt.geom FROM wsdassmnt

          UNION ALL
          SELECT
           p.geom
          FROM prelim p
          WHERE watershed_feature_id NOT IN (SELECT unnest(wsds) from cut)

        UNION ALL
          SELECT
            CASE
              WHEN m.refine_method = 'CUT' THEN (SELECT c.geom FROM cut c)
              WHEN m.refine_method = 'KEEP' THEN
               (SELECT
                  ST_Force2D(ST_Multi(wsd.geom)) as geom
                FROM whse_basemapping.fwa_watersheds_poly wsd
                INNER JOIN ref_point pt
                ON ST_Intersects(wsd.geom, pt.geom_pt)
               )
               END as geom
          FROM method m

        -- add watersheds outside of BC
        UNION ALL
          SELECT
            ST_Difference(exbc.geom, bc.geom) as geom
          FROM exbc
          INNER JOIN whse_basemapping.fwa_bcboundary bc
          ON ST_Intersects(exbc.geom, bc.geom)

        ) as to_agg,
        method m
        GROUP BY m.wscode_ltree, m.localcode_ltree, m.refine_method)

        -- dump to singlepart and extract largest result -
        -- sometimes there can be extra polygons leftover.
        -- for example, at Fort Steel bridge over Kootenay R,
        -- (blue_line_key=356570348, downstream_route_measure=520327.8)
        -- the watershed gets cut, but two non-contiguous polys adjacent to
        -- river have the same local code and get included after the cut
        SELECT
          agg.wscode_ltree::text,
          agg.localcode_ltree::text,
          ROUND((st_area(agg.geom) / 10000)::numeric, 2)  as area_ha,
          agg.refine_method,
          ST_Safe_Repair(agg.geom) as geom
        FROM agg
        ORDER BY st_area(agg.geom) desc
        LIMIT 1;

    else

        -- if in lake, shift point to outlet of lake and do a simple upstream
        -- selection with no further modifications necessary
        return query

        -- find waterbody_key of source point
        WITH src_pt AS
        (SELECT
          s.waterbody_key,
          s.geom
        FROM whse_basemapping.fwa_stream_networks_sp s
        WHERE s.blue_line_key = v_blkey
        AND s.downstream_route_measure <= v_measure
        ORDER BY s.downstream_route_measure desc
        LIMIT 1),

        -- find watershed code / measure / geom at outlet of lake/reservoir
        -- (minumum code / measure)
        outlet AS (
        SELECT DISTINCT ON (waterbody_key)
        s.waterbody_key,
        s.wscode_ltree,
        s.localcode_ltree,
        s.downstream_route_measure + .01 as downstream_route_measure, -- nudge up just a bit to prevent precision errors
        s.blue_line_key,
        ST_PointN(s.geom, 1) as geom
        FROM whse_basemapping.fwa_stream_networks_sp s
        INNER JOIN src_pt
        ON s.waterbody_key = src_pt.waterbody_key
        WHERE s.fwa_watershed_code NOT LIKE '999-999999%'
        AND s.localcode_ltree IS NOT NULL
        ORDER BY s.waterbody_key, s.wscode_ltree, s.localcode_ltree, s.downstream_route_measure
        ),

        wsdbasins AS
        (
          SELECT
            b.basin_id,
            ST_Force2D(b.geom) as geom
          FROM outlet a
          INNER JOIN whse_basemapping.fwa_basins_poly b
          ON FWA_Upstream(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
        ),

        -- similarly, get any upstream watershed groups
        -- (that are not covered by the pre-aggregated watersheds)
        wsdgroups AS (
          SELECT
            b.watershed_group_id,
            b.basin_id,
            ST_Force2D(b.geom) as geom
          FROM outlet a
          INNER JOIN whse_basemapping.fwa_watershed_groups_poly b
          ON FWA_Upstream(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
          LEFT OUTER JOIN wsdbasins ON b.basin_id = wsdbasins.basin_id
          WHERE wsdbasins.basin_id IS NULL
        ),

        -- next, assessment watersheds
        wsdassmnt AS (
          SELECT
            b.watershed_feature_id as assmnt_watershed_id,
            g.watershed_group_id,
            g.basin_id,
            ST_Force2D(b.geom) as geom
          FROM outlet a
          INNER JOIN whse_basemapping.fwa_assessment_watersheds_poly b
          ON FWA_Upstream(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
          -- do not include the assmnt watershed with equivalent codes
          AND NOT (a.wscode_ltree = b.wscode_ltree AND a.localcode_ltree = b.localcode_ltree)
          LEFT OUTER JOIN wsdgroups c ON b.watershed_group_id = c.watershed_group_id
          LEFT OUTER JOIN whse_basemapping.fwa_watershed_groups_poly g
          ON b.watershed_group_id = g.watershed_group_id
          WHERE c.watershed_group_id IS NULL AND g.basin_id IS NULL

        ),

        -- get upstream watersheds
        prelim AS (
          SELECT
            b.watershed_feature_id,
            b.geom
          FROM outlet a
          INNER JOIN whse_basemapping.fwa_watersheds_poly b
          ON FWA_Upstream(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
          LEFT OUTER JOIN whse_basemapping.fwa_assessment_watersheds_lut l
          ON b.watershed_feature_id = l.watershed_feature_id
          LEFT OUTER JOIN wsdassmnt c ON l.assmnt_watershed_id = c.assmnt_watershed_id
          LEFT OUTER JOIN wsdgroups d ON b.watershed_group_id = d.watershed_group_id
          LEFT OUTER JOIN whse_basemapping.fwa_watershed_groups_poly g
          ON b.watershed_group_id = g.watershed_group_id
          WHERE c.assmnt_watershed_id IS NULL
          AND d.watershed_group_id IS NULL
          AND g.basin_id NOT IN (SELECT basin_id FROM wsdbasins)
        ),

        -- find any upstream contributing area outside of BC (but not including Alaska panhandle)
        exbc AS
         (
          SELECT
            hydrosheds.hydroshed(h.hybas_id) AS geom
          FROM outlet s
          INNER JOIN hydrosheds.hybas_lev12_v1c h
          ON ST_Intersects(h.geom, s.geom)
          WHERE FWA_UpstreamBorderCrossings(s.blue_line_key, s.downstream_route_measure) IN ('AB_120','YTNWT_60')
          UNION ALL
          SELECT
            FWA_Huc12(h.huc12) AS geom
          FROM outlet s
          INNER JOIN usgs.wbdhu12 h
          ON ST_intersects(h.geom, s.geom)
          WHERE FWA_UpstreamBorderCrossings(s.blue_line_key, s.downstream_route_measure) = 'USA_49'
        )

        -- aggregate the result
        SELECT
            o.wscode_ltree::text,
            o.localcode_ltree::text,
            ROUND((sum(st_area(w.geom)) / 10000)::numeric, 2)  as area_ha,
            'LAKE' AS refine_method,
            ST_Safe_Repair(
              ST_Buffer(
                ST_Collect(w.geom), 0.001)
                ) AS geom
        FROM
        outlet o,
        (
          SELECT b.geom FROM wsdbasins b
          UNION ALL
          SELECT g.geom FROM wsdgroups g
          UNION ALL
          SELECT a.geom FROM wsdassmnt a
          UNION ALL
          SELECT p.geom FROM prelim p
          UNION ALL
          SELECT
            ST_Difference(exbc.geom, bc.geom) as geom
          FROM exbc
          INNER JOIN whse_basemapping.fwa_bcboundary bc
          ON ST_Intersects(exbc.geom, bc.geom)
        ) w
        GROUP BY o.wscode_ltree, o.localcode_ltree, refine_method;

    end if;

end
$$
language 'plpgsql' immutable strict parallel safe;


COMMENT ON FUNCTION postgisftw.fwa_watershedatmeasure IS 'Provided a location as blue_line_key and downstream_route_measure, return the entire watershed boundary upstream of the location';



-- -------------------------------------------------------------------------------------------------------------------------
-- FWA_WatershedHex
-- -------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION postgisftw.FWA_WatershedHex(blue_line_key integer, downstream_route_measure float)

RETURNS TABLE(hex_id bigint, geom geometry)
AS


$$

declare
   v_blkey    integer := blue_line_key;
   v_measure  float := downstream_route_measure;


begin

return query

-- interpolate point on stream
WITH pt AS (
  SELECT
    s.linear_feature_id,
    s.blue_line_key,
    s.downstream_route_measure,
    ST_LocateAlong(s.geom, v_measure) AS geom
  FROM whse_basemapping.fwa_stream_networks_sp s
  WHERE s.blue_line_key = v_blkey
  AND s.downstream_route_measure <= v_measure
  AND s.upstream_route_measure > v_measure
),

-- find the watershed in which the point falls
wsd AS (
  SELECT w.watershed_feature_id, w.geom
  FROM pt
  INNER JOIN whse_basemapping.fwa_watersheds_poly w
  ON ST_Intersects(pt.geom, w.geom)
),

-- generate a hex grid (with 25m sides) covering the entire watershed polygon
hex AS (
  SELECT ST_ForceRHR(ST_Force2D(CDB_HexagonGrid(ST_Buffer(wsd.geom, 25), 25))) as geom
  FROM wsd
)

-- cut the hex watersheds with the watershed polygon
SELECT
  row_number() over() as hex_id,
  CASE
    WHEN ST_Within(a.geom, b.geom) THEN ST_Multi(a.geom)
    ELSE ST_ForceRHR(ST_Multi(ST_Force2D(ST_Intersection(a.geom, b.geom))))
  END as geom
 FROM hex a
INNER JOIN wsd b ON ST_Intersects(a.geom, b.geom);

end
$$
language 'plpgsql' immutable parallel safe;

COMMENT ON FUNCTION postgisftw.fwa_watershedhex IS 'Provided a location as blue_line_key and downstream_route_measure, return a 25m hexagon grid covering first order watershed in which location lies';



-- -------------------------------------------------------------------------------------------------------------------------
-- FWA_WatershedStream
-- -------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION postgisftw.FWA_WatershedStream(blue_line_key integer, downstream_route_measure float)

RETURNS TABLE(linear_feature_id bigint, geom geometry)
AS


$$

declare
   v_blkey    integer := blue_line_key;
   v_measure  float := downstream_route_measure;


begin

return query

WITH local_segment AS
(SELECT
  s.linear_feature_id,
  s.blue_line_key,
  v_measure as measure,
  s.wscode_ltree,
  s.localcode_ltree,
  ST_Force2D(
    ST_Multi(
      ST_LocateBetween(s.geom, v_measure, s.upstream_route_measure)
    )
  ) AS geom,
  ST_LocateAlong(s.geom, v_measure) as geom_pt
FROM whse_basemapping.fwa_stream_networks_sp s
WHERE s.blue_line_key = v_blkey
AND s.downstream_route_measure <= v_measure
AND s.upstream_route_measure > v_measure
),

wsd AS
(SELECT
  w.watershed_feature_id,
  w.geom
 FROM whse_basemapping.fwa_watersheds_poly w
 INNER JOIN local_segment ls ON ST_Intersects(w.geom, ls.geom_pt)
)

SELECT
  ls.linear_feature_id,
  ST_Multi(ls.geom) as geom
from local_segment ls
UNION ALL
SELECT
  b.linear_feature_id,
  ST_Multi(b.geom) as geom
FROM local_segment a
INNER JOIN whse_basemapping.fwa_stream_networks_sp b
ON
-- upstream, but not same blue_line_key
(
FWA_Upstream(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
-- not the same line or blue_line_key
AND b.linear_feature_id != a.linear_feature_id
AND b.blue_line_key != a.blue_line_key
-- same watershed code
AND a.wscode_ltree = b.wscode_ltree
-- not a side channel that may be downstream
AND b.localcode_ltree IS NOT NULL
)
-- or upstream on the same blueline
OR (b.blue_line_key = a.blue_line_key AND
b.downstream_route_measure > a.measure)

-- within same first order watershed as input location
INNER JOIN wsd
ON ST_Within(b.geom, ST_Buffer(wsd.geom, .1));

end

$$
language 'plpgsql' immutable parallel safe;

COMMENT ON FUNCTION postgisftw.fwa_watershedstream IS 'Provided a location as blue_line_key and downstream_route_measure, return stream segments upstream, within the same first order watershed.';


-- -------------------------------------------------------------------------------------------------------------------------
-- hydroshed
-- note that this is slightly different from the hydrosheds.hydroshed function
-- -------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION postgisftw.hydroshed(x float, y float, srid integer)

RETURNS table

    (
        geom geometry
    )

AS

$$

WITH RECURSIVE walkup (hybas_id, geom) AS
        (
            SELECT hybas_id, wsd.geom
            FROM hydrosheds.hybas_lev12_v1c wsd
            INNER JOIN (SELECT ST_Transform(ST_SetSRID(ST_MakePoint(x, y), srid), 3005) as geom)  as pt
            ON ST_Intersects(wsd.geom, pt.geom)

            UNION ALL

            SELECT b.hybas_id, b.geom
            FROM hydrosheds.hybas_lev12_v1c b,
            walkup w
            WHERE b.next_down = w.hybas_id
        )
    SELECT
      ST_Union(w.geom) as geom
    FROM walkup w;

$$
language 'sql' immutable parallel safe;


COMMENT ON FUNCTION postgisftw.hydroshed IS 'Return aggregated boundary of all hydroshed polygons upstream of the provided location';