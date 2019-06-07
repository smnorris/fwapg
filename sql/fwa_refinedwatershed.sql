-- Given blue_line_key and downstream_route_measure, return a (potentially
-- modified) FWA watershed with:
-- - wscode_ltree
-- - localcode_ltree
-- - area_ha
-- - refine_method - for the 1st order watershed in which the point lies:
--     CUT  - point is on a river/canal, cut the input watersheds at point
--     DEM  - point is on a single line stream,further DEM refinement needed
--     DROP - point is on single line stream and close enough to top of the
--            first order watershed that retaining the first order watershed
--            is not necessary
--     KEEP - point is on single line stream and close enough to bottom of the
--            first order watershed that the entire first order watershed is
--            retained  (no further refining necessary)
--     LAKE - point is in a lake/non-canal reservoir, simply return watershed
--            upstream of the outlet
-- - geom


-- TODO - what happens if cut returns an invalid geometry?
--      - speed things up with pre-aggregated assessment wsds or using the
--        st_intersect trick



CREATE OR REPLACE FUNCTION fwa_refinedwatershed(blkey integer, meas float)

RETURNS TABLE(wscode_ltree ltree, localcode_ltree ltree, area_ha numeric, refine_method text, geom geometry)
AS


$$
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
        WHERE s.blue_line_key = blkey
        AND s.downstream_route_measure <= meas
        ORDER BY s.downstream_route_measure desc
        LIMIT 1
    ) is false

    then return query
        -- non-lake/reservoir based watershed
        WITH ref_point AS
        (SELECT
          s.linear_feature_id,
          s.blue_line_key,
          s.downstream_route_measure as measure_str,
          meas as measure_pt,
          s.wscode_ltree,
          s.localcode_ltree,
          s.waterbody_key,
          -- identify canals as waterbody type 'C'
          CASE
           WHEN r.feature_code = 'GA03950000' THEN 'C'
           ELSE wb.waterbody_type
          END as waterbody_type,
          ST_LineInterpolatePoint(
            (ST_Dump(s.geom)).geom,
            ROUND(CAST((meas - s.downstream_route_measure) / s.length_metre AS NUMERIC), 5)
                ) as geom_pt,
          s.geom as geom_str
        FROM whse_basemapping.fwa_stream_networks_sp s
        LEFT OUTER JOIN whse_basemapping.fwa_waterbodies wb
        ON s.waterbody_key = wb.waterbody_key
        LEFT OUTER JOIN whse_basemapping.fwa_manmade_waterbodies_poly r
        ON s.waterbody_key = r.waterbody_key
        WHERE s.blue_line_key = blkey
        AND s.downstream_route_measure <= meas
        ORDER BY s.downstream_route_measure desc
        LIMIT 1),

        -- find watershed polygons within 5m of the point
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
              .1 / ST_Length(str.geom),
              (ST_Length(str.geom) - .1) / ST_Length(str.geom)
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
              .1 / ST_Length(str.geom),
              (ST_Length(str.geom) - .1) / ST_Length(str.geom)
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
            WHEN r.waterbody_type IN ('C', 'R') THEN 'CUT'
-- if the location of interest is < 100m from the top of the local stream,
-- just drop the watershed in which it falls
            WHEN (r.waterbody_key IS NULL OR r.waterbody_type = 'W') AND t.measure <= 100 THEN 'DROP'
-- if the location of interest is <50m from the bottom of the local stream,
-- keep the watershed in which it falls with no modifications
            WHEN (r.waterbody_key IS NULL OR r.waterbody_type = 'W') AND b.measure <= 50 THEN 'KEEP'
-- otherwise, if location is on on single line stream and outside of above
-- endpoint tolerances, note that the watershed should be post-processed
-- with the DEM
            WHEN (r.waterbody_key is NULL OR r.waterbody_type = 'W')
              AND t.measure > 100
              AND b.measure > 50 THEN 'DEM'
            END as refine_method

        FROM ref_point r, length_to_top t, length_to_bottom b
        ),

        prelim AS (

        -- get upstream watersheds
          SELECT
          s.wscode_ltree,
          s.localcode_ltree,
          w.watershed_feature_id,
          ST_Force2D(w.geom) as geom
        FROM ref_point s
        INNER JOIN whse_basemapping.fwa_watersheds_poly w
        ON
          (s.wscode_ltree = s.localcode_ltree AND
            w.wscode_ltree <@ s.wscode_ltree
          )
        OR
          (s.wscode_ltree != s.localcode_ltree AND
           w.wscode_ltree <@ s.wscode_ltree AND
            (
                (w.wscode_ltree > s.localcode_ltree AND NOT
                 w.wscode_ltree <@ s.localcode_ltree)
                OR
                (w.wscode_ltree = s.wscode_ltree AND
                 w.localcode_ltree >= s.localcode_ltree)
            )
          )
        WHERE watershed_feature_id NOT IN (SELECT unnest(wsds) from wsd)

        UNION

        -- add watersheds from adjacent lakes/reservoirs with equivalent watershed
        -- codes, in which the point does not lie. This is a bit of a quirk
        SELECT
          s.wscode_ltree,
          s.localcode_ltree,
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
        FROM FWA_SliceWatershedAtPoint(blkey, meas) slice
        )

        SELECT
          to_agg.wscode_ltree,
          to_agg.localcode_ltree,
          ROUND((sum(st_area(to_agg.geom)) / 10000)::numeric, 2)  as area_ha,
          m.refine_method,
          ST_Buffer(
            ST_Collect(to_agg.geom), 0.001) AS geom
        FROM
        (SELECT
         p.wscode_ltree,
         p.localcode_ltree,
         p.geom
        FROM prelim p
        WHERE watershed_feature_id NOT IN (SELECT unnest(wsds) from cut)
        UNION ALL
        SELECT
          m.wscode_ltree,
          m.localcode_ltree,
          CASE
            WHEN m.refine_method = 'CUT' THEN (SELECT c.geom FROM cut c)
            WHEN m.refine_method = 'KEEP' THEN
             (SELECT
                ST_Force2D(ST_Multi(wsd.geom)) as geom
              FROM whse_basemapping.fwa_watersheds_poly wsd
              INNER JOIN ref_point pt
              ON ST_DWithin(wsd.geom, pt.geom_pt, 5)
             )
             END as geom
        FROM method m) as to_agg,
        method m

        GROUP BY to_agg.wscode_ltree, to_agg.localcode_ltree, m.refine_method;

    else

        -- if in lake, shift point to outlet of lake and do a simple upstream
        -- selection with no further modifications necessary
        return query

        -- find waterbody_key of source point
        WITH src_pt AS
        (SELECT
          s.waterbody_key
        FROM whse_basemapping.fwa_stream_networks_sp s
        WHERE s.blue_line_key = blkey
        AND s.downstream_route_measure <= meas
        ORDER BY s.downstream_route_measure desc
        LIMIT 1),

        -- find watershed code / measure at outlet of lake/reservoir
        -- (minumum code / measure)
        outlet AS (
        SELECT DISTINCT ON (waterbody_key)
        s.waterbody_key,
        s.wscode_ltree,
        s.localcode_ltree,
        s.downstream_route_measure,
        s.blue_line_key
        FROM whse_basemapping.fwa_stream_networks_sp s
        INNER JOIN src_pt
        ON s.waterbody_key = src_pt.waterbody_key
        WHERE s.fwa_watershed_code NOT LIKE '999-999999%'
        AND s.localcode_ltree IS NOT NULL
        ORDER BY waterbody_key, wscode_ltree, localcode_ltree, downstream_route_measure
        ),

        -- get upstream watersheds
        wsd AS (SELECT
        s.wscode_ltree,
        s.localcode_ltree,
        w.watershed_feature_id,
        ST_Force2D(w.geom) as geom
        FROM outlet s
        INNER JOIN whse_basemapping.fwa_watersheds_poly w
        ON
          (s.wscode_ltree = s.localcode_ltree AND
            w.wscode_ltree <@ s.wscode_ltree
          )
        OR
          (s.wscode_ltree != s.localcode_ltree AND
           w.wscode_ltree <@ s.wscode_ltree AND
            (
                (w.wscode_ltree > s.localcode_ltree AND NOT
                 w.wscode_ltree <@ s.localcode_ltree)
                OR
                (w.wscode_ltree = s.wscode_ltree AND
                 w.localcode_ltree >= s.localcode_ltree)
            )
          )
        )

        -- aggregate the result
        SELECT
            w.wscode_ltree,
            w.localcode_ltree,
            ROUND((sum(st_area(w.geom)) / 10000)::numeric, 2)  as area_ha,
            'LAKE' AS refine_method,
            ST_Buffer(
                ST_Collect(w.geom), 0.001) AS geom
        FROM wsd w
        GROUP BY w.wscode_ltree, w.localcode_ltree, refine_method;

    end if;

end
$$
language 'plpgsql' immutable strict parallel safe;