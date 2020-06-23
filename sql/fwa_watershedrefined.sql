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



CREATE OR REPLACE FUNCTION fwa_watershedrefined(blkey integer, meas float)

RETURNS TABLE
 (wscode_ltree ltree,
  localcode_ltree ltree,
  area_ha numeric,
  refine_method text,
  geom geometry)
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
          (ST_Dump(
             ST_LocateAlong(s.geom, meas)
             )
          ).geom::geometry(PointZM, 3005) AS geom_pt,
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
          ON FWA_UpstreamWSC(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
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
          ON FWA_UpstreamWSC(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
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
          ON FWA_UpstreamWSC(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
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
          ON FWA_UpstreamWSC(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
          LEFT OUTER JOIN whse_basemapping.fwa_assessment_watersheds_lut l
          ON b.watershed_feature_id = l.watershed_feature_id
          LEFT OUTER JOIN wsdassmnt c ON l.assmnt_watershed_id = c.assmnt_watershed_id
          LEFT OUTER JOIN wsdgroups d ON b.watershed_group_id = d.watershed_group_id
          LEFT OUTER JOIN whse_basemapping.fwa_watershed_groups_poly g
          ON b.watershed_group_id = g.watershed_group_id
          WHERE c.assmnt_watershed_id IS NULL
          AND d.watershed_group_id IS NULL
          AND g.basin_id IS NULL
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
        FROM FWA_SliceWatershedAtPoint(blkey, meas) slice
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

        UNION ALL

          -- add watersheds outside of BC
          SELECT exbc.geom
          FROM fwa_watershedexbc(blkey, meas) exbc

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
        agg.wscode_ltree,
        agg.localcode_ltree,
        ROUND((st_area(agg.geom) / 10000)::numeric, 2)  as area_ha,
        agg.refine_method,
        agg.geom
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

        wsdbasins AS
        (
          SELECT
            b.basin_id,
            ST_Force2D(b.geom) as geom
          FROM outlet a
          INNER JOIN whse_basemapping.fwa_basins_poly b
          ON FWA_UpstreamWSC(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
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
          ON FWA_UpstreamWSC(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
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
          ON FWA_UpstreamWSC(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
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
          ON FWA_UpstreamWSC(a.wscode_ltree, a.localcode_ltree, b.wscode_ltree, b.localcode_ltree)
          LEFT OUTER JOIN whse_basemapping.fwa_assessment_watersheds_lut l
          ON b.watershed_feature_id = l.watershed_feature_id
          LEFT OUTER JOIN wsdassmnt c ON l.assmnt_watershed_id = c.assmnt_watershed_id
          LEFT OUTER JOIN wsdgroups d ON b.watershed_group_id = d.watershed_group_id
          LEFT OUTER JOIN whse_basemapping.fwa_watershed_groups_poly g
          ON b.watershed_group_id = g.watershed_group_id
          WHERE c.assmnt_watershed_id IS NULL
          AND d.watershed_group_id IS NULL
          AND g.basin_id IS NULL
        ),

        exbc AS
        (SELECT
          s.wscode_ltree,
          s.localcode_ltree,
          0 as watershed_feature_id,
          ex.geom
         FROM outlet s,
         fwa_watershedexbc(blkey, meas) ex
        )
        -- aggregate the result
        SELECT
            o.wscode_ltree,
            o.localcode_ltree,
            ROUND((sum(st_area(w.geom)) / 10000)::numeric, 2)  as area_ha,
            'LAKE' AS refine_method,
            ST_Buffer(
                ST_Collect(w.geom), 0.001) AS geom
        FROM
        outlet o,
        (
          SELECT geom FROM wsdbasins
          UNION ALL
          SELECT geom FROM wsdgroups
          UNION ALL
          SELECT geom FROM wsdassmnt
          UNION ALL
          SELECT p.geom FROM prelim p
          UNION ALL
          SELECT e.geom from exbc e
        ) w
        GROUP BY o.wscode_ltree, o.localcode_ltree, refine_method;

    end if;

end
$$
language 'plpgsql' immutable strict parallel safe;