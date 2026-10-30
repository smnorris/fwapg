BEGIN;

-- FWA_IndexPoint: break exact distance ties, return the measure and point the
-- stream geometry carries, and optionally filter streams before the pick.
--
-- Ties. A point nearest the vertex two segments of one stream share is equally
-- far from both, and DISTINCT ON (blue_line_key) ... ORDER BY blue_line_key,
-- distance_to_stream returned whichever row the plan reached first. When that
-- was the segment below the vertex, the measure returned fell short of the next
-- segment's start, and FWA_LocateAlong returned no point for it. The tie now
-- goes to the segment starting at the vertex: measures run [downstream,
-- upstream), so it is the segment a measure there falls on. Then to
-- linear_feature_id. A tie between segments that do not share a vertex (a
-- meander) also goes to the upper one, which is only a fixed choice.
--
-- Measure and point (#161). The point was ST_ClosestPoint on ST_LineMerge(geom),
-- and both drop the line's m (the merge goes through GEOS), so the measure was
-- downstream_route_measure + fraction * length_metre. That can differ from the
-- geometry's own m by a few mm, and near a segment's top it can pass
-- upstream_route_measure, where FWA_LocateAlong finds nothing. The point is now
-- ST_LineInterpolatePoint on the segment, at the fraction of its closest point
-- to the input (which keeps a MultiPoint input working, as ST_LineLocatePoint
-- alone would not), and it keeps z and m. The measure is its m: the value FWA_LocateAlong, FWA_WatershedAtMeasure and ST_LocateAlong
-- read. The returned geom is a PointZM.
--
-- Filters (#86). include_disconnected => false excludes 999 streams, and
-- include_null_localcodes => false excludes segments with no local code. Both
-- apply before the nearest segment of each stream is chosen, so a stream whose
-- nearest segment is excluded is still returned on its nearest usable one.
-- Both default to true, which keeps the previous result.
--
-- Stream head. With the measure taken from m, a point snapped to the top of a
-- blue line has a measure equal to the top segment's upstream_route_measure (at
-- about 91% of heads), and every function that required
-- upstream_route_measure > measure found no segment for it. FWA_LocateAlong,
-- FWA_UpstreamTrace, FWA_DownstreamTrace, FWA_WatershedHex and
-- FWA_WatershedStream (both schemas) now take the highest segment whose range,
-- closed at the top, holds the measure (the top compared to 4 decimal places,
-- the start as each function already compared it).
-- At a junction that is still the segment starting there, as in
-- FWA_WatershedAtMeasure; at the head it is the top segment; a measure in a gap
-- between segments, or past the head, still finds none. FWA_UpstreamBorderCrossings keeps its own
-- selection (which takes both segments within 1 cm below a junction) and accepts
-- the top segment at the head; its slice fraction is kept in [0, 1], since a
-- measure from m can run past length_metre near a segment's top. So is
-- FWA_SliceWatershedAtPoint's, which FWA_WatershedAtMeasure calls on rivers.
--
-- A point on the boundary between two watershed groups failed with "more than
-- one row returned by a subquery"; the in-BC flag is now an EXISTS.
--
-- The new parameters change the signature, so both FWA_IndexPoint functions are
-- dropped and recreated.

DROP FUNCTION postgisftw.fwa_indexpoint(double precision, double precision, integer, double precision, integer);
DROP FUNCTION whse_basemapping.fwa_indexpoint(public.geometry, double precision, integer);

CREATE FUNCTION whse_basemapping.fwa_indexpoint(point public.geometry, tolerance double precision DEFAULT 5000, num_features integer DEFAULT 1, include_disconnected boolean DEFAULT true, include_null_localcodes boolean DEFAULT true) RETURNS TABLE(linear_feature_id bigint, gnis_name text, wscode_ltree public.ltree, localcode_ltree public.ltree, blue_line_key integer, downstream_route_measure double precision, distance_to_stream double precision, bc_ind boolean, geom public.geometry)
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $_$

WITH pt AS

(
    -- one row whatever the number of watershed groups the point touches: a
    -- point on the boundary between two used to give two rows, and the
    -- scalar subquery in the ORDER BY below then failed
    SELECT
      $1 as geom,
      EXISTS (
        SELECT 1
        FROM whse_basemapping.fwa_watershed_groups_poly wsg
        WHERE ST_intersects($1, wsg.geom)
      ) as bc_ind
)

SELECT
    linear_feature_id,
    gnis_name,
    wscode_ltree,
    localcode_ltree,
    blue_line_key,
    ST_M(ST_LineInterpolatePoint(stream_geom,
      ST_LineLocatePoint(stream_geom, ST_ClosestPoint(stream_geom, pt_geom)))
    ) AS downstream_route_measure,
    ROUND(distance_to_stream::numeric, 3) AS distance_to_stream,
    bc_ind,
    ST_LineInterpolatePoint(stream_geom,
      ST_LineLocatePoint(stream_geom, ST_ClosestPoint(stream_geom, pt_geom))
    ) as geom
FROM
(
    SELECT DISTINCT ON (blue_line_key)
        linear_feature_id,
        gnis_name,
        wscode_ltree,
        localcode_ltree,
        blue_line_key,
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
                downstream_route_measure,
                str.geom as stream_geom,
                pt.geom as pt_geom,
                ST_Distance(str.geom, pt.geom) as distance_to_stream,
                pt.bc_ind
            FROM whse_basemapping.fwa_stream_networks_sp AS str,
            pt
            -- do not use 6010 lines, only return nearest stream inside BC
            WHERE edge_type != 6010
            -- filter before the per-stream pick, so a stream whose nearest
            -- segment is excluded is kept on its nearest usable one
            AND ($4 OR NOT str.wscode_ltree <@ '999'::public.ltree)
            AND ($5 OR str.localcode_ltree IS NOT NULL)
            ORDER BY str.geom <-> (select geom from pt)
            LIMIT 100
        ) AS f
    -- a point nearest the vertex two segments share is equally near both: take
    -- the one starting there, the segment its measure falls on
    ORDER BY blue_line_key, distance_to_stream, downstream_route_measure DESC, linear_feature_id
) b
WHERE distance_to_stream <= $2
-- b. is the unrounded distance; the bare name is the rounded output column
ORDER BY b.distance_to_stream asc, linear_feature_id
LIMIT $3

$_$;

COMMENT ON FUNCTION whse_basemapping.fwa_indexpoint(point public.geometry, tolerance double precision, num_features integer, include_disconnected boolean, include_null_localcodes boolean) IS 'Provided a BC Albers point geometry, return the point indexed (snapped) to nearest stream(s) within specified tolerance (m). Optionally exclude disconnected (999) streams and streams without a local code before the nearest segment of each stream is chosen.';

CREATE FUNCTION postgisftw.fwa_indexpoint(x double precision, y double precision, srid integer, tolerance double precision DEFAULT 5000, num_features integer DEFAULT 1, include_disconnected boolean DEFAULT true, include_null_localcodes boolean DEFAULT true) RETURNS TABLE(linear_feature_id bigint, gnis_name text, wscode_ltree public.ltree, localcode_ltree public.ltree, blue_line_key integer, downstream_route_measure double precision, distance_to_stream double precision, bc_ind boolean, geom public.geometry)
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $_$

WITH pt AS

(
  SELECT ST_Transform(ST_SetSRID(ST_Makepoint($1, $2), $3), 3005) as geom
)

SELECT whse_basemapping.FWA_IndexPoint(pt.geom, $4, $5, $6, $7)
FROM pt

$_$;

COMMENT ON FUNCTION postgisftw.fwa_indexpoint(x double precision, y double precision, srid integer, tolerance double precision, num_features integer, include_disconnected boolean, include_null_localcodes boolean) IS 'Provided a point (as x,y coordinates and EPSG code), return the point indexed (snapped) to nearest stream(s) within specified tolerance (m). Optionally exclude disconnected (999) streams and streams without a local code before the nearest segment of each stream is chosen.';

CREATE OR REPLACE FUNCTION whse_basemapping.fwa_locatealong(blue_line_key integer, downstream_route_measure double precision) RETURNS TABLE(geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
    AS $$

DECLARE
   v_blkey    integer := blue_line_key;
   v_measure  float   := downstream_route_measure;
   v_geom     geometry;

BEGIN

RETURN QUERY
SELECT
  (ST_Dump(ST_LocateAlong(seg.geom, v_measure))).geom as geom
FROM
(
  -- the highest segment whose range, closed at the top, holds the measure: at a
  -- junction the one starting there, at the stream's head its top segment
  SELECT s.geom
  FROM whse_basemapping.fwa_stream_networks_sp AS s
  WHERE s.blue_line_key = v_blkey
  AND round(s.downstream_route_measure::numeric, 4) <= round(v_measure::numeric, 4)
  AND round(s.upstream_route_measure::numeric, 4) >= round(v_measure::numeric, 4)
  ORDER BY s.downstream_route_measure desc
  LIMIT 1
) AS seg
LIMIT 1;
END

$$;

CREATE OR REPLACE FUNCTION postgisftw.fwa_locatealong(blue_line_key integer, downstream_route_measure double precision) RETURNS TABLE(geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
    AS $$

DECLARE
   v_blkey    integer := blue_line_key;
   v_measure  float   := downstream_route_measure;
   v_geom     geometry;

BEGIN

RETURN QUERY
SELECT
  (ST_Dump(ST_LocateAlong(seg.geom, v_measure))).geom as geom
FROM
(
  -- the highest segment whose range, closed at the top, holds the measure: at a
  -- junction the one starting there, at the stream's head its top segment
  SELECT s.geom
  FROM whse_basemapping.fwa_stream_networks_sp AS s
  WHERE s.blue_line_key = v_blkey
  AND round(s.downstream_route_measure::numeric, 4) <= round(v_measure::numeric, 4)
  AND round(s.upstream_route_measure::numeric, 4) >= round(v_measure::numeric, 4)
  ORDER BY s.downstream_route_measure desc
  LIMIT 1
) AS seg
LIMIT 1;
END

$$;

CREATE OR REPLACE FUNCTION whse_basemapping.fwa_upstreamtrace(start_blue_line_key integer, start_measure double precision, tolerance double precision DEFAULT 1)
 RETURNS TABLE(linear_feature_id bigint, edge_type integer, blue_line_key integer, watershed_key integer, wscode ltree, localcode ltree, watershed_group_code character varying, downstream_route_measure double precision, upstream_route_measure double precision, length_metre double precision, waterbody_key integer, gnis_name character varying, stream_order integer, stream_magnitude integer, feature_code character varying, gradient double precision, left_right_tributary character varying, stream_order_parent integer, stream_order_max integer, upstream_area_ha double precision, map_upstream integer, channel_width double precision, channel_width_source text, mad_m3s double precision, geom geometry)
 LANGUAGE plpgsql
 IMMUTABLE PARALLEL SAFE STRICT
AS $function$

DECLARE
   v_blue_line_key  integer := start_blue_line_key;
   v_measure        float   := start_measure;
   v_tolerance      float   := tolerance;

BEGIN

RETURN QUERY

-- find segment on which point lies
with segment as (
  select
    s.linear_feature_id,
    s.blue_line_key,
    v_measure AS measure,
    s.downstream_route_measure,
    s.upstream_route_measure,
    s.wscode_ltree as wscode,
    s.localcode_ltree as localcode,
    s.geom
  FROM whse_basemapping.fwa_stream_networks_sp AS s
  WHERE s.blue_line_key = v_blue_line_key
  AND round(s.downstream_route_measure::numeric, 4) <= round(v_measure::numeric, 4)
  AND round(s.upstream_route_measure::numeric, 4) >= round(v_measure::numeric, 4)
  -- the highest segment whose range, closed at the top, holds the measure: at a
  -- junction the one starting there, at the stream's head its top segment
  ORDER BY s.downstream_route_measure DESC
  LIMIT 1
),

-- cut segment if required
cut as (
  SELECT
    s.linear_feature_id,
    s.blue_line_key,
    s.measure as downstream_route_measure,
    s.upstream_route_measure,
    s.wscode,
    s.localcode,
    (st_dump(
      case
        when (v_measure - s.downstream_route_measure) > v_tolerance  -- split geom if not within tolerance m of dnstr measure
        then ST_LocateBetween(s.geom, v_measure, s.upstream_route_measure)
        else s.geom                                                  -- otherwise return source geom
      end
    )).geom AS geom
  FROM segment s
  WHERE (s.upstream_route_measure - v_measure) > v_tolerance -- only return data if more than tolerance m from upstream measure
),

-- find everything upstream
upstr as (
  select
    a.linear_feature_id
  from whse_basemapping.fwa_stream_networks_sp a
  inner join segment b on fwa_upstream(
    b.blue_line_key,
    b.downstream_route_measure,
    b.wscode,
    b.localcode,
    a.blue_line_key,
    a.downstream_route_measure,
    a.wscode_ltree,
    a.localcode_ltree
    )
)

select
  s.linear_feature_id,
  s.edge_type,
  s.blue_line_key,
  s.watershed_key,
  s.wscode_ltree as wscode,
  s.localcode_ltree as localcode,
  s.watershed_group_code,
  c.downstream_route_measure,
  s.upstream_route_measure,
  st_length(c.geom) as length_metre,
  s.waterbody_key,
  s.gnis_name,
  s.stream_order,
  s.stream_magnitude,
  s.feature_code,
  (round(((st_z(st_pointn(c.geom, '-1'::integer)) - st_z(st_pointn(c.geom, 1))) / st_length(c.geom))::numeric, 4)) as gradient,
  s.left_right_tributary,
  op.stream_order_parent,
  om.stream_order_max,
  ua.upstream_area_ha,
  p.map_upstream,
  cw.channel_width,
  cw.channel_width_source,
  d.mad_m3s,
  c.geom as geom
from cut c
inner join whse_basemapping.fwa_stream_networks_sp s on c.linear_feature_id = s.linear_feature_id
left outer join whse_basemapping.fwa_streams_watersheds_lut l on s.linear_feature_id = l.linear_feature_id
inner join whse_basemapping.fwa_watersheds_upstream_area ua on l.watershed_feature_id = ua.watershed_feature_id
left outer join whse_basemapping.fwa_stream_networks_channel_width cw on c.linear_feature_id = cw.linear_feature_id
left outer join whse_basemapping.fwa_stream_networks_discharge d on c.linear_feature_id = d.linear_feature_id
left outer join whse_basemapping.fwa_stream_networks_mean_annual_precip p on s.wscode_ltree = p.wscode_ltree and s.localcode_ltree = p.localcode_ltree
left outer join whse_basemapping.fwa_stream_networks_order_max om on s.blue_line_key = om.blue_line_key
left outer join whse_basemapping.fwa_stream_networks_order_parent op on s.blue_line_key = op.blue_line_key
union all
select
  u.linear_feature_id,
  s.edge_type,
  s.blue_line_key,
  s.watershed_key,
  s.wscode_ltree as wscode,
  s.localcode_ltree as localcode,
  s.watershed_group_code,
  s.downstream_route_measure,
  s.upstream_route_measure,
  s.length_metre,
  s.waterbody_key,
  s.gnis_name,
  s.stream_order,
  s.stream_magnitude,
  s.feature_code,
  s.gradient,
  s.left_right_tributary,
  op.stream_order_parent,
  om.stream_order_max,
  ua.upstream_area_ha,
  p.map_upstream,
  cw.channel_width,
  cw.channel_width_source,
  d.mad_m3s,
  s.geom as geom
from upstr u
inner join whse_basemapping.fwa_stream_networks_sp s on u.linear_feature_id = s.linear_feature_id
left outer join whse_basemapping.fwa_streams_watersheds_lut l on s.linear_feature_id = l.linear_feature_id
inner join whse_basemapping.fwa_watersheds_upstream_area ua ON l.watershed_feature_id = ua.watershed_feature_id
left outer join whse_basemapping.fwa_stream_networks_channel_width cw on u.linear_feature_id = cw.linear_feature_id
left outer join whse_basemapping.fwa_stream_networks_discharge d on u.linear_feature_id = d.linear_feature_id
left outer join whse_basemapping.fwa_stream_networks_mean_annual_precip p ON s.wscode_ltree = p.wscode_ltree AND s.localcode_ltree = p.localcode_ltree
left outer join whse_basemapping.fwa_stream_networks_order_max om on s.blue_line_key = om.blue_line_key
left outer join whse_basemapping.fwa_stream_networks_order_parent op on s.blue_line_key = op.blue_line_key
order by wscode, localcode, downstream_route_measure;


END

$function$;

CREATE OR REPLACE FUNCTION postgisftw.fwa_upstreamtrace(start_blue_line_key integer, start_measure double precision, tolerance double precision DEFAULT 1)
 RETURNS TABLE(linear_feature_id bigint, edge_type integer, blue_line_key integer, watershed_key integer, wscode ltree, localcode ltree, watershed_group_code character varying, downstream_route_measure double precision, upstream_route_measure double precision, length_metre double precision, waterbody_key integer, gnis_name character varying, stream_order integer, stream_magnitude integer, feature_code character varying, gradient double precision, left_right_tributary character varying, stream_order_parent integer, stream_order_max integer, upstream_area_ha double precision, map_upstream integer, channel_width double precision, channel_width_source text, mad_m3s double precision, geom geometry)
 LANGUAGE plpgsql
 IMMUTABLE PARALLEL SAFE STRICT
AS $function$

DECLARE
   v_blue_line_key  integer := start_blue_line_key;
   v_measure        float   := start_measure;
   v_tolerance      float   := tolerance;

BEGIN

RETURN QUERY

-- find segment on which point lies
with segment as (
  select
    s.linear_feature_id,
    s.blue_line_key,
    v_measure AS measure,
    s.downstream_route_measure,
    s.upstream_route_measure,
    s.wscode_ltree as wscode,
    s.localcode_ltree as localcode,
    s.geom
  FROM whse_basemapping.fwa_stream_networks_sp AS s
  WHERE s.blue_line_key = v_blue_line_key
  AND round(s.downstream_route_measure::numeric, 4) <= round(v_measure::numeric, 4)
  AND round(s.upstream_route_measure::numeric, 4) >= round(v_measure::numeric, 4)
  -- the highest segment whose range, closed at the top, holds the measure: at a
  -- junction the one starting there, at the stream's head its top segment
  ORDER BY s.downstream_route_measure DESC
  LIMIT 1
),

-- cut segment if required
cut as (
  SELECT
    s.linear_feature_id,
    s.blue_line_key,
    s.measure as downstream_route_measure,
    s.upstream_route_measure,
    s.wscode,
    s.localcode,
    (st_dump(
      case
        when (v_measure - s.downstream_route_measure) > v_tolerance  -- split geom if not within tolerance m of dnstr measure
        then ST_LocateBetween(s.geom, v_measure, s.upstream_route_measure)
        else s.geom                                                  -- otherwise return source geom
      end
    )).geom AS geom
  FROM segment s
  WHERE (s.upstream_route_measure - v_measure) > v_tolerance -- only return data if more than tolerance m from upstream measure
),

-- find everything upstream
upstr as (
  select
    a.linear_feature_id
  from whse_basemapping.fwa_stream_networks_sp a
  inner join segment b on fwa_upstream(
    b.blue_line_key,
    b.downstream_route_measure,
    b.wscode,
    b.localcode,
    a.blue_line_key,
    a.downstream_route_measure,
    a.wscode_ltree,
    a.localcode_ltree
    )
)

select
  s.linear_feature_id,
  s.edge_type,
  s.blue_line_key,
  s.watershed_key,
  s.wscode_ltree as wscode,
  s.localcode_ltree as localcode,
  s.watershed_group_code,
  c.downstream_route_measure,
  s.upstream_route_measure,
  st_length(c.geom) as length_metre,
  s.waterbody_key,
  s.gnis_name,
  s.stream_order,
  s.stream_magnitude,
  s.feature_code,
  (round(((st_z(st_pointn(c.geom, '-1'::integer)) - st_z(st_pointn(c.geom, 1))) / st_length(c.geom))::numeric, 4)) as gradient,
  s.left_right_tributary,
  op.stream_order_parent,
  om.stream_order_max,
  ua.upstream_area_ha,
  p.map_upstream,
  cw.channel_width,
  cw.channel_width_source,
  d.mad_m3s,
  c.geom as geom
from cut c
inner join whse_basemapping.fwa_stream_networks_sp s on c.linear_feature_id = s.linear_feature_id
left outer join whse_basemapping.fwa_streams_watersheds_lut l on s.linear_feature_id = l.linear_feature_id
inner join whse_basemapping.fwa_watersheds_upstream_area ua on l.watershed_feature_id = ua.watershed_feature_id
left outer join whse_basemapping.fwa_stream_networks_channel_width cw on c.linear_feature_id = cw.linear_feature_id
left outer join whse_basemapping.fwa_stream_networks_discharge d on c.linear_feature_id = d.linear_feature_id
left outer join whse_basemapping.fwa_stream_networks_mean_annual_precip p on s.wscode_ltree = p.wscode_ltree and s.localcode_ltree = p.localcode_ltree
left outer join whse_basemapping.fwa_stream_networks_order_max om on s.blue_line_key = om.blue_line_key
left outer join whse_basemapping.fwa_stream_networks_order_parent op on s.blue_line_key = op.blue_line_key
union all
select
  u.linear_feature_id,
  s.edge_type,
  s.blue_line_key,
  s.watershed_key,
  s.wscode_ltree as wscode,
  s.localcode_ltree as localcode,
  s.watershed_group_code,
  s.downstream_route_measure,
  s.upstream_route_measure,
  s.length_metre,
  s.waterbody_key,
  s.gnis_name,
  s.stream_order,
  s.stream_magnitude,
  s.feature_code,
  s.gradient,
  s.left_right_tributary,
  op.stream_order_parent,
  om.stream_order_max,
  ua.upstream_area_ha,
  p.map_upstream,
  cw.channel_width,
  cw.channel_width_source,
  d.mad_m3s,
  s.geom as geom
from upstr u
inner join whse_basemapping.fwa_stream_networks_sp s on u.linear_feature_id = s.linear_feature_id
left outer join whse_basemapping.fwa_streams_watersheds_lut l on s.linear_feature_id = l.linear_feature_id
inner join whse_basemapping.fwa_watersheds_upstream_area ua ON l.watershed_feature_id = ua.watershed_feature_id
left outer join whse_basemapping.fwa_stream_networks_channel_width cw on u.linear_feature_id = cw.linear_feature_id
left outer join whse_basemapping.fwa_stream_networks_discharge d on u.linear_feature_id = d.linear_feature_id
left outer join whse_basemapping.fwa_stream_networks_mean_annual_precip p ON s.wscode_ltree = p.wscode_ltree AND s.localcode_ltree = p.localcode_ltree
left outer join whse_basemapping.fwa_stream_networks_order_max om on s.blue_line_key = om.blue_line_key
left outer join whse_basemapping.fwa_stream_networks_order_parent op on s.blue_line_key = op.blue_line_key
order by wscode, localcode, downstream_route_measure;


END

$function$;

CREATE OR REPLACE FUNCTION whse_basemapping.fwa_downstreamtrace(start_blue_line_key integer, start_measure double precision, tolerance double precision DEFAULT 1)
 RETURNS TABLE(linear_feature_id bigint, edge_type integer, blue_line_key integer, watershed_key integer, wscode ltree, localcode ltree, watershed_group_code character varying, downstream_route_measure double precision, upstream_route_measure double precision, length_metre double precision, waterbody_key integer, gnis_name character varying, stream_order integer, stream_magnitude integer, feature_code character varying, gradient double precision, left_right_tributary character varying, stream_order_parent integer, stream_order_max integer, upstream_area_ha double precision, map_upstream integer, channel_width double precision, channel_width_source text, mad_m3s double precision, geom geometry)
 LANGUAGE plpgsql
 IMMUTABLE PARALLEL SAFE STRICT
AS $function$

DECLARE
   v_blue_line_key  integer := start_blue_line_key;
   v_measure        float   := start_measure;
   v_tolerance      float   := tolerance;

BEGIN

RETURN QUERY

-- find segment on which point lies
with segment as (
  select
    s.linear_feature_id,
    s.blue_line_key,
    v_measure AS measure,
    s.downstream_route_measure,
    s.upstream_route_measure,
    s.wscode,
    s.localcode,
    s.geom
  FROM whse_basemapping.fwa_streams AS s
  WHERE s.blue_line_key = v_blue_line_key
  AND round(s.downstream_route_measure::numeric, 4) <= round(v_measure::numeric, 4)
  AND round(s.upstream_route_measure::numeric, 4) >= round(v_measure::numeric, 4)
  -- the highest segment whose range, closed at the top, holds the measure: at a
  -- junction the one starting there, at the stream's head its top segment
  ORDER BY s.downstream_route_measure DESC
  LIMIT 1
),

-- cut segment if required
cut as (
  SELECT
    s.linear_feature_id,
    s.blue_line_key,
    case
      when (s.upstream_route_measure - v_measure) > v_tolerance then s.measure
      else s.upstream_route_measure
    end as upstream_route_measure,
    s.wscode,
    s.localcode,
    (st_dump(
      case
        when (s.upstream_route_measure - v_measure) > v_tolerance  -- split geom if not within tolerance m of upstr measure
        then ST_LocateBetween(s.geom, s.downstream_route_measure, v_measure)
        else s.geom                                                  -- otherwise return source geom
      end
    )).geom AS geom
  FROM segment s
  WHERE (v_measure - s.downstream_route_measure) > v_tolerance -- only return data if more than tolerance m from dnstr measure
),

-- find everything downstream
dnstr as (
  select a.*
  from whse_basemapping.fwa_streams a
  inner join segment b on fwa_downstream(
    b.blue_line_key,
    b.downstream_route_measure,
    b.wscode,
    b.localcode,
    a.blue_line_key,
    a.downstream_route_measure,
    a.wscode,
    a.localcode
    )
)

select
  s.linear_feature_id,
  s.edge_type,
  s.blue_line_key,
  s.watershed_key,
  s.wscode_ltree as wscode,
  s.localcode_ltree as localcode,
  s.watershed_group_code,
  s.downstream_route_measure,
  c.upstream_route_measure,
  round(st_length(c.geom)::numeric, 7) as length_metre,
  s.waterbody_key,
  s.gnis_name,
  s.stream_order,
  s.stream_magnitude,
  s.feature_code,
  (round(((st_z(st_pointn(c.geom, '-1'::integer)) - st_z(st_pointn(c.geom, 1))) / st_length(c.geom))::numeric, 4)) as gradient,
  s.left_right_tributary,
  op.stream_order_parent,
  om.stream_order_max,
  ua.upstream_area_ha,
  p.map_upstream,
  cw.channel_width,
  cw.channel_width_source,
  d.mad_m3s,
  c.geom as geom
from cut c
inner join whse_basemapping.fwa_stream_networks_sp s on c.linear_feature_id = s.linear_feature_id
left outer join whse_basemapping.fwa_streams_watersheds_lut l on s.linear_feature_id = l.linear_feature_id
inner join whse_basemapping.fwa_watersheds_upstream_area ua on l.watershed_feature_id = ua.watershed_feature_id
left outer join whse_basemapping.fwa_stream_networks_channel_width cw on c.linear_feature_id = cw.linear_feature_id
left outer join whse_basemapping.fwa_stream_networks_discharge d on c.linear_feature_id = d.linear_feature_id
left outer join whse_basemapping.fwa_stream_networks_mean_annual_precip p ON s.wscode_ltree = p.wscode_ltree AND s.localcode_ltree = p.localcode_ltree
left outer join whse_basemapping.fwa_stream_networks_order_max om on s.blue_line_key = om.blue_line_key
left outer join whse_basemapping.fwa_stream_networks_order_parent op on s.blue_line_key = op.blue_line_key
union all
select *
from dnstr dn
order by wscode desc, localcode desc, downstream_route_measure desc;


END

$function$;

CREATE OR REPLACE FUNCTION postgisftw.fwa_downstreamtrace(start_blue_line_key integer, start_measure double precision, tolerance double precision DEFAULT 1)
 RETURNS TABLE(linear_feature_id bigint, edge_type integer, blue_line_key integer, watershed_key integer, wscode ltree, localcode ltree, watershed_group_code character varying, downstream_route_measure double precision, upstream_route_measure double precision, length_metre double precision, waterbody_key integer, gnis_name character varying, stream_order integer, stream_magnitude integer, feature_code character varying, gradient double precision, left_right_tributary character varying, stream_order_parent integer, stream_order_max integer, upstream_area_ha double precision, map_upstream integer, channel_width double precision, channel_width_source text, mad_m3s double precision, geom geometry)
 LANGUAGE plpgsql
 IMMUTABLE PARALLEL SAFE STRICT
AS $function$

DECLARE
   v_blue_line_key  integer := start_blue_line_key;
   v_measure        float   := start_measure;
   v_tolerance      float   := tolerance;

BEGIN

RETURN QUERY

-- find segment on which point lies
with segment as (
  select
    s.linear_feature_id,
    s.blue_line_key,
    v_measure AS measure,
    s.downstream_route_measure,
    s.upstream_route_measure,
    s.wscode_ltree as wscode,
    s.localcode_ltree as localcode,
    s.geom
  FROM whse_basemapping.fwa_stream_networks_sp AS s
  WHERE s.blue_line_key = v_blue_line_key
  AND round(s.downstream_route_measure::numeric, 4) <= round(v_measure::numeric, 4)
  AND round(s.upstream_route_measure::numeric, 4) >= round(v_measure::numeric, 4)
  -- the highest segment whose range, closed at the top, holds the measure: at a
  -- junction the one starting there, at the stream's head its top segment
  ORDER BY s.downstream_route_measure DESC
  LIMIT 1
),

-- cut segment if required
cut as (
  SELECT
    s.linear_feature_id,
    s.blue_line_key,
    case
      when (s.upstream_route_measure - v_measure) > v_tolerance then s.measure
      else s.upstream_route_measure
    end as upstream_route_measure,
    s.wscode,
    s.localcode,
    (st_dump(
      case
        when (s.upstream_route_measure - v_measure) > v_tolerance  -- split geom if not within tolerance m of upstr measure
        then ST_LocateBetween(s.geom, s.downstream_route_measure, v_measure)
        else s.geom                                                  -- otherwise return source geom
      end
    )).geom AS geom
  FROM segment s
  WHERE (v_measure - s.downstream_route_measure) > v_tolerance -- only return data if more than tolerance m from dnstr measure
),

-- find everything downstream
dnstr as (
  select a.*
  from whse_basemapping.fwa_stream_networks_sp a
  inner join segment b on fwa_downstream(
    b.blue_line_key,
    b.downstream_route_measure,
    b.wscode,
    b.localcode,
    a.blue_line_key,
    a.downstream_route_measure,
    a.wscode_ltree,
    a.localcode_ltree
    )
)

select
  s.linear_feature_id,
  s.edge_type,
  s.blue_line_key,
  s.watershed_key,
  s.wscode_ltree as wscode,
  s.localcode_ltree as localcode,
  s.watershed_group_code,
  s.downstream_route_measure,
  c.upstream_route_measure,
  round(st_length(c.geom)::numeric, 7) as length_metre,
  s.waterbody_key,
  s.gnis_name,
  s.stream_order,
  s.stream_magnitude,
  s.feature_code,
  (round(((st_z(st_pointn(c.geom, '-1'::integer)) - st_z(st_pointn(c.geom, 1))) / st_length(c.geom))::numeric, 4)) as gradient,
  s.left_right_tributary,
  op.stream_order_parent,
  om.stream_order_max,
  ua.upstream_area_ha,
  p.map_upstream,
  cw.channel_width,
  cw.channel_width_source,
  d.mad_m3s,
  c.geom as geom
from cut c
inner join whse_basemapping.fwa_stream_networks_sp s on c.linear_feature_id = s.linear_feature_id
left outer join whse_basemapping.fwa_streams_watersheds_lut l on s.linear_feature_id = l.linear_feature_id
inner join whse_basemapping.fwa_watersheds_upstream_area ua on l.watershed_feature_id = ua.watershed_feature_id
left outer join whse_basemapping.fwa_stream_networks_channel_width cw on c.linear_feature_id = cw.linear_feature_id
left outer join whse_basemapping.fwa_stream_networks_discharge d on c.linear_feature_id = d.linear_feature_id
left outer join whse_basemapping.fwa_stream_networks_mean_annual_precip p ON s.wscode_ltree = p.wscode_ltree AND s.localcode_ltree = p.localcode_ltree
left outer join whse_basemapping.fwa_stream_networks_order_max om on s.blue_line_key = om.blue_line_key
left outer join whse_basemapping.fwa_stream_networks_order_parent op on s.blue_line_key = op.blue_line_key
union all
select
  dn.linear_feature_id,
  s.edge_type,
  s.blue_line_key,
  s.watershed_key,
  s.wscode_ltree as wscode,
  s.localcode_ltree as localcode,
  s.watershed_group_code,
  s.downstream_route_measure,
  s.upstream_route_measure,
  s.length_metre,
  s.waterbody_key,
  s.gnis_name,
  s.stream_order,
  s.stream_magnitude,
  s.feature_code,
  s.gradient,
  s.left_right_tributary,
  op.stream_order_parent,
  om.stream_order_max,
  ua.upstream_area_ha,
  p.map_upstream,
  cw.channel_width,
  cw.channel_width_source,
  d.mad_m3s,
  s.geom as geom
from dnstr dn
inner join whse_basemapping.fwa_stream_networks_sp s on dn.linear_feature_id = s.linear_feature_id
left outer join whse_basemapping.fwa_streams_watersheds_lut l on s.linear_feature_id = l.linear_feature_id
inner join whse_basemapping.fwa_watersheds_upstream_area ua on l.watershed_feature_id = ua.watershed_feature_id
left outer join whse_basemapping.fwa_stream_networks_channel_width cw on dn.linear_feature_id = cw.linear_feature_id
left outer join whse_basemapping.fwa_stream_networks_discharge d on dn.linear_feature_id = d.linear_feature_id
left outer join whse_basemapping.fwa_stream_networks_mean_annual_precip p ON s.wscode_ltree = p.wscode_ltree AND s.localcode_ltree = p.localcode_ltree
left outer join whse_basemapping.fwa_stream_networks_order_max om on s.blue_line_key = om.blue_line_key
left outer join whse_basemapping.fwa_stream_networks_order_parent op on s.blue_line_key = op.blue_line_key
order by wscode desc, localcode desc, downstream_route_measure desc;


END

$function$;

CREATE OR REPLACE FUNCTION whse_basemapping.fwa_watershedhex(blue_line_key integer, downstream_route_measure double precision)
 RETURNS TABLE(hex_id bigint, geom geometry)
 LANGUAGE plpgsql
 IMMUTABLE PARALLEL SAFE
AS $function$

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
  AND round(s.upstream_route_measure::numeric, 4) >= round(v_measure::numeric, 4)
  -- the highest segment whose range, closed at the top, holds the measure: at a
  -- junction the one starting there, at the stream's head its top segment
  ORDER BY s.downstream_route_measure DESC
  LIMIT 1
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
$function$;

CREATE OR REPLACE FUNCTION postgisftw.fwa_watershedhex(blue_line_key integer, downstream_route_measure double precision)
 RETURNS TABLE(hex_id bigint, geom geometry)
 LANGUAGE plpgsql
 IMMUTABLE PARALLEL SAFE
AS $function$

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
  AND round(s.upstream_route_measure::numeric, 4) >= round(v_measure::numeric, 4)
  -- the highest segment whose range, closed at the top, holds the measure: at a
  -- junction the one starting there, at the stream's head its top segment
  ORDER BY s.downstream_route_measure DESC
  LIMIT 1
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
$function$;

CREATE OR REPLACE FUNCTION whse_basemapping.fwa_watershedstream(blue_line_key integer, downstream_route_measure double precision)
 RETURNS TABLE(linear_feature_id bigint, geom geometry)
 LANGUAGE plpgsql
 IMMUTABLE PARALLEL SAFE
AS $function$

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
AND round(s.upstream_route_measure::numeric, 4) >= round(v_measure::numeric, 4)
-- the highest segment whose range, closed at the top, holds the measure: at a
-- junction the one starting there, at the stream's head its top segment
ORDER BY s.downstream_route_measure DESC
LIMIT 1
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

$function$;

CREATE OR REPLACE FUNCTION postgisftw.fwa_watershedstream(blue_line_key integer, downstream_route_measure double precision)
 RETURNS TABLE(linear_feature_id bigint, geom geometry)
 LANGUAGE plpgsql
 IMMUTABLE PARALLEL SAFE
AS $function$

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
AND round(s.upstream_route_measure::numeric, 4) >= round(v_measure::numeric, 4)
-- the highest segment whose range, closed at the top, holds the measure: at a
-- junction the one starting there, at the stream's head its top segment
ORDER BY s.downstream_route_measure DESC
LIMIT 1
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

$function$;

CREATE OR REPLACE FUNCTION whse_basemapping.fwa_upstreambordercrossings(blkey integer, meas double precision)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE STRICT
AS $function$

WITH local_segment AS
(
  SELECT
    s.linear_feature_id,
    s.blue_line_key,
    meas as downstream_route_measure,
    s.wscode_ltree,
    s.localcode_ltree,
    ST_Force2D(
      ST_Multi(
        ST_LineSubstring((ST_Dump(s.geom)).geom,
                     -- a measure from the geometry's m can run past length_metre
                     -- near the top, and up to 1 cm below the start: keep in [0, 1]
                     LEAST(GREATEST((meas - s.downstream_route_measure) / s.length_metre, 0), 1),
                     1)
                     )
    ) AS geom
  FROM whse_basemapping.fwa_stream_networks_sp s
  WHERE s.blue_line_key = blkey
  AND s.downstream_route_measure <= meas + .01
  AND (
    s.upstream_route_measure > meas
    -- or the stream's top segment, so a measure at its head (the geometry's
    -- last m, which can equal upstream_route_measure) is accepted
    OR (
      round(s.upstream_route_measure::numeric, 4) >= round(meas::numeric, 4)
      AND NOT EXISTS (
        SELECT 1
        FROM whse_basemapping.fwa_stream_networks_sp u
        WHERE u.blue_line_key = s.blue_line_key
        AND u.downstream_route_measure > s.downstream_route_measure
      )
    )
  )
),

upstream AS
(
  SELECT
    linear_feature_id,
    geom
  FROM local_segment
  UNION ALL
  SELECT
    b.linear_feature_id,
    b.geom
  FROM local_segment a
  INNER JOIN whse_basemapping.fwa_stream_networks_sp b
  ON FWA_Upstream(a.blue_line_key, a.downstream_route_measure, a.wscode_ltree, a.localcode_ltree,
                  b.blue_line_key, b.downstream_route_measure, b.wscode_ltree, b.localcode_ltree)
)

-- Return only one value - we don't currently do any thing different for ab vs yt/nwt so
-- there is no need to differentiate in event that a point has both borders upstream
SELECT border FROM
(
 SELECT
  b.border,
  s.linear_feature_id,
  CASE
    WHEN b.border = 'USA_49' THEN
      ST_ClosestPoint(
        ST_Translate(b.geom, 0, -50),
          ST_Intersection(s.geom, b.geom)
       )
    WHEN b.border = 'YTNWT_60' THEN
      ST_ClosestPoint(
        ST_Translate(b.geom, 0, 50),
          ST_Intersection(s.geom, b.geom)
       )
    WHEN b.border = 'AB_120' THEN
      ST_ClosestPoint(
        ST_Translate(b.geom, 50, 0),
          ST_Intersection(s.geom, b.geom)
       )
    END AS geom
FROM upstream s
INNER JOIN whse_basemapping.fwa_approx_borders b
ON ST_Intersects(s.geom, b.geom)
LIMIT 1) as f;


$function$;

CREATE OR REPLACE FUNCTION whse_basemapping.fwa_slicewatershedatpoint(blkey integer, meas double precision)
 RETURNS TABLE(wsds integer[], geom geometry)
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE STRICT
AS $function$

-- Generate a point from the privided blue line key and measure
WITH ref_point AS
(SELECT
  s.linear_feature_id,
  s.blue_line_key,
  s.downstream_route_measure,
  s.wscode_ltree,
  s.localcode_ltree,
  s.waterbody_key,
  ST_LineInterpolatePoint(
    (ST_Dump(s.geom)).geom,
    -- a measure from the geometry's m can run past length_metre at a stream's
    -- head: keep the fraction in [0, 1]
    LEAST(GREATEST(ROUND(CAST((meas - s.downstream_route_measure) / s.length_metre AS NUMERIC), 5), 0), 1)
        ) as geom
FROM whse_basemapping.fwa_stream_networks_sp s
WHERE s.blue_line_key = blkey
AND s.downstream_route_measure <= meas
ORDER BY s.downstream_route_measure desc
LIMIT 1),


-- Find watershed polys that compose the waterbody on which the point lies.
-- This is not a simple case of extracting watersheds with the equivalent
-- waterbody key, waterbodies may terminate near a site, we may have to
-- include several watershed polygons.
-- Therefore, here we will first select watersheds with a matching wb key
-- (within 100m) and then in the next WITH CTE, widen the selection to
-- any watersheds with that touch the waterbody in which the point lies.
wsds_river_prelim AS
(SELECT
  wsd.watershed_feature_id,
  wsd.waterbody_key,
  wsd.geom
 FROM whse_basemapping.fwa_watersheds_poly wsd
 INNER JOIN ref_point pt
  ON (wsd.waterbody_key = pt.waterbody_key
     AND ST_DWithin(wsd.geom, pt.geom, 100))
),

-- Add intersecting waterbodies if present, combining with results from above
wsds_river AS
(SELECT DISTINCT watershed_feature_id, waterbody_key, geom
FROM (
(SELECT wsd.watershed_feature_id, wsd.waterbody_key, wsd.geom
FROM whse_basemapping.fwa_watersheds_poly wsd
INNER JOIN wsds_river_prelim p ON ST_Intersects(wsd.geom, p.geom)
WHERE wsd.watershed_feature_id != p.watershed_feature_id
AND wsd.waterbody_key != 0
UNION ALL
SELECT * FROM wsds_river_prelim)
) as foo
) ,


-- Find the watershed polygons that are on the banks of wsds_river, returns all
-- watersheds that share an edge with the river (or lake) polys
wsds_adjacent AS
(SELECT
    r.watershed_feature_id as riv_id,
  wsd.watershed_feature_id,
  wsd.geom,
  ST_Distance(s.geom, wsd.geom) as dist_to_site
FROM whse_basemapping.fwa_watersheds_poly wsd
INNER JOIN wsds_river r
ON (r.geom && wsd.geom AND ST_Relate(r.geom, wsd.geom, '****1****'))
INNER JOIN ref_point s ON ST_DWithin(s.geom, r.geom, 5)
LEFT OUTER JOIN whse_basemapping.fwa_lakes_poly lk
ON wsd.waterbody_key = lk.waterbody_key
LEFT OUTER JOIN whse_basemapping.fwa_rivers_poly riv
ON wsd.waterbody_key = riv.waterbody_key
LEFT OUTER JOIN whse_basemapping.fwa_manmade_waterbodies_poly mm
ON wsd.waterbody_key = mm.waterbody_key
WHERE lk.waterbody_key IS NULL AND riv.waterbody_key IS NULL AND mm.waterbody_key IS NULL
AND r.watershed_feature_id != wsd.watershed_feature_id
AND wsd.watershed_feature_id NOT IN (SELECT watershed_feature_id FROM wsds_river)),

-- From wsds_adjacent, find just the nearest wsd poly to the point (on each
-- bank) - there should always be just two results
wsds_adjacent_nearest AS
(SELECT DISTINCT ON (riv_id) riv_id, watershed_feature_id, dist_to_site, geom
FROM wsds_adjacent
ORDER BY riv_id, dist_to_site),

-- Extract the (valid) exterior ring from wsds_adjacent_nearest and retain
-- only the portion that doesn't intersect with the river polys -
-- the outside edges
edges AS (
  SELECT
  w_adj.watershed_feature_id,
  ST_Difference(
    ST_ExteriorRing(
      ST_MakeValid(
        (ST_Dump(w_adj.geom)).geom
      )
    ),
    w_riv.geom
  ) as geom
  FROM wsds_adjacent_nearest w_adj,
(SELECT ST_Union(geom) as geom FROM wsds_river) as w_riv),

-- build all possible blades because the shortest may not work
-- the shortest edge may cross the waterbody before getting to the site,
-- resulting in an invalid blade
all_ends AS (
  SELECT
    row_number() over() AS id,
    e.watershed_feature_id,
    (ST_DumpPoints(e.geom)).geom as geom_end,
    stn.blue_line_key,
    stn.geom as geom_stn
  FROM edges e, ref_point stn
),

-- build all possible blades to see which ones don't cross the river
all_blade_edges AS (
  SELECT
    e.id,
    e.blue_line_key,
    ST_Makeline(geom_end, geom_stn) as geom
  FROM all_ends e),

-- buffer the stream for use below, the buffer ensures that intersections occur,
-- otherwise precision errors may occur when intersecting the point with the line end
stream_buff AS (
SELECT ST_Union(ST_Buffer(ST_LineMerge(s.geom), .01)) as geom
FROM whse_basemapping.fwa_stream_networks_sp s
INNER JOIN ref_point p ON s.blue_line_key = p.blue_line_key
),

-- find the shortest of the blades that do not cross the river
shortest_valid_edges AS (
SELECT DISTINCT ON (id)
    e.id,
    ST_Length(e.geom) AS length,
    e.geom
  FROM all_blade_edges e
  INNER JOIN stream_buff s ON ST_Intersects(e.geom, s.geom)
  AND ST_GeometryType(ST_Intersection(e.geom, s.geom)) = 'ST_LineString'
  ORDER BY id, length
),

-- Now we can construct a valid blade.
-- One of the lines has to be flipped for the line to build properly
blade AS
(SELECT
  1 as id,
  ST_LineMerge(ST_Collect(geom)) as geom
FROM (
  SELECT
    id,
    ST_Reverse(geom) as geom
  FROM shortest_valid_edges
  WHERE id = 1
  UNION ALL
  SELECT id, geom
  FROM shortest_valid_edges
  WHERE id = 2) as flipped
),

-- Aggregate the watersheds extracted above (river and nearest adjacent) into
-- a single poly for cutting. Insert other nearby waterbodies in case we are
-- missing part of the river when sharp angles get involved
to_split AS
(
SELECT array_agg(watershed_feature_id) as wsds, (ST_Dump(ST_Union(geom))).geom AS geom
FROM
  (SELECT watershed_feature_id, geom FROM wsds_adjacent_nearest
   UNION ALL
   SELECT watershed_feature_id, geom FROM wsds_river
   UNION ALL
   SELECT wsd.watershed_feature_id, wsd.geom FROM whse_basemapping.fwa_watersheds_poly wsd
   INNER JOIN ref_point pt
   ON ST_DWithin(wsd.geom, pt.geom, 100)
   WHERE wsd.waterbody_key != 0) AS bar
)

-- Cut the aggregated watershed poly
SELECT
  wsds,
  ST_Multi(cut.geom) AS geom
FROM
  (SELECT
    wsds,
    (ST_Dump(ST_Split(ST_Snap(w.geom, b.geom, .001), b.geom))).geom
   FROM to_split w, blade b
   ) AS cut
INNER JOIN
(SELECT
   str.geom
 FROM whse_basemapping.fwa_stream_networks_sp str
 INNER JOIN ref_point p
 ON str.blue_line_key = p.blue_line_key
 AND str.downstream_route_measure > p.downstream_route_measure
 ORDER BY str. downstream_route_measure asc
 LIMIT 1
) stream
ON st_intersects(cut.geom, stream.geom);



$function$;

COMMIT;
