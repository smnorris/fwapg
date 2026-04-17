SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: fwapg; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA fwapg;


--
-- Name: hydrosheds; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA hydrosheds;


--
-- Name: postgisftw; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA postgisftw;


--
-- Name: psf; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA psf;


--
-- Name: usgs; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA usgs;


--
-- Name: whse_basemapping; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA whse_basemapping;


--
-- Name: fuzzystrmatch; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;


--
-- Name: EXTENSION fuzzystrmatch; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION fuzzystrmatch IS 'determine similarities and distance between strings';


--
-- Name: intarray; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS intarray WITH SCHEMA public;


--
-- Name: EXTENSION intarray; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION intarray IS 'functions, operators, and index support for 1-D arrays of integers';


--
-- Name: ltree; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS ltree WITH SCHEMA public;


--
-- Name: EXTENSION ltree; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION ltree IS 'data type for hierarchical tree-like structures';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: hydroshed(bigint); Type: FUNCTION; Schema: hydrosheds; Owner: -
--

CREATE FUNCTION hydrosheds.hydroshed(id bigint) RETURNS public.geometry
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $$

WITH RECURSIVE walkup (hybas_id, geom) AS
    (
        SELECT hybas_id, wsd.geom
        FROM hydrosheds.hybas_lev12_v1c wsd
        WHERE hybas_id = id

        UNION ALL

        SELECT b.hybas_id, b.geom
        FROM hydrosheds.hybas_lev12_v1c b,
        walkup w
        WHERE b.next_down = w.hybas_id
    )
SELECT
  ST_Union(w.geom, .5) as geom
FROM walkup w;

$$;


--
-- Name: FUNCTION hydroshed(id bigint); Type: COMMENT; Schema: hydrosheds; Owner: -
--

COMMENT ON FUNCTION hydrosheds.hydroshed(id bigint) IS 'Return geometry of aggregated watershed boundary for watershed upstream of provided hydroshed id';


--
-- Name: fwa_downstreamtrace(integer, double precision, double precision); Type: FUNCTION; Schema: postgisftw; Owner: -
--

CREATE FUNCTION postgisftw.fwa_downstreamtrace(start_blue_line_key integer, start_measure double precision, tolerance double precision DEFAULT 1) RETURNS TABLE(linear_feature_id bigint, edge_type integer, blue_line_key integer, watershed_key integer, wscode public.ltree, localcode public.ltree, watershed_group_code character varying, downstream_route_measure double precision, upstream_route_measure double precision, length_metre double precision, waterbody_key integer, gnis_name character varying, stream_order integer, stream_magnitude integer, feature_code character varying, gradient double precision, left_right_tributary character varying, stream_order_parent integer, stream_order_max integer, upstream_area_ha double precision, map_upstream integer, channel_width double precision, channel_width_source text, mad_m3s double precision, geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
    AS $$

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
  AND round(s.upstream_route_measure::numeric, 4) > round(v_measure::numeric, 4)
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

$$;


--
-- Name: FUNCTION fwa_downstreamtrace(start_blue_line_key integer, start_measure double precision, tolerance double precision); Type: COMMENT; Schema: postgisftw; Owner: -
--

COMMENT ON FUNCTION postgisftw.fwa_downstreamtrace(start_blue_line_key integer, start_measure double precision, tolerance double precision) IS 'Return stream network downstream of provided location';


--
-- Name: fwa_indexpoint(double precision, double precision, integer, double precision, integer); Type: FUNCTION; Schema: postgisftw; Owner: -
--

CREATE FUNCTION postgisftw.fwa_indexpoint(x double precision, y double precision, srid integer, tolerance double precision DEFAULT 5000, num_features integer DEFAULT 1) RETURNS TABLE(linear_feature_id bigint, gnis_name text, wscode_ltree public.ltree, localcode_ltree public.ltree, blue_line_key integer, downstream_route_measure double precision, distance_to_stream double precision, bc_ind boolean, geom public.geometry)
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $_$

WITH pt AS

(
  SELECT ST_Transform(ST_SetSRID(ST_Makepoint($1, $2), $3), 3005) as geom
)

SELECT FWA_IndexPoint(pt.geom, $4, $5)
FROM pt

$_$;


--
-- Name: FUNCTION fwa_indexpoint(x double precision, y double precision, srid integer, tolerance double precision, num_features integer); Type: COMMENT; Schema: postgisftw; Owner: -
--

COMMENT ON FUNCTION postgisftw.fwa_indexpoint(x double precision, y double precision, srid integer, tolerance double precision, num_features integer) IS 'Provided a point (as x,y coordinates and EPSG code), return the point indexed (snapped) to nearest stream(s) within specified tolerance (m)';


--
-- Name: fwa_locatealong(integer, double precision); Type: FUNCTION; Schema: postgisftw; Owner: -
--

CREATE FUNCTION postgisftw.fwa_locatealong(blue_line_key integer, downstream_route_measure double precision) RETURNS TABLE(geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
    AS $$

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

$$;


--
-- Name: FUNCTION fwa_locatealong(blue_line_key integer, downstream_route_measure double precision); Type: COMMENT; Schema: postgisftw; Owner: -
--

COMMENT ON FUNCTION postgisftw.fwa_locatealong(blue_line_key integer, downstream_route_measure double precision) IS 'Return a point on the stream network based on the location provided by blue_line_key and downstream_route_measure';


--
-- Name: fwa_locatealonginterval(integer, integer, integer, integer); Type: FUNCTION; Schema: postgisftw; Owner: -
--

CREATE FUNCTION postgisftw.fwa_locatealonginterval(blue_line_key integer, start_measure integer DEFAULT 0, interval_length integer DEFAULT 1000, end_measure integer DEFAULT NULL::integer) RETURNS TABLE(index integer, downstream_route_measure double precision, geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$

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

$$;


--
-- Name: FUNCTION fwa_locatealonginterval(blue_line_key integer, start_measure integer, interval_length integer, end_measure integer); Type: COMMENT; Schema: postgisftw; Owner: -
--

COMMENT ON FUNCTION postgisftw.fwa_locatealonginterval(blue_line_key integer, start_measure integer, interval_length integer, end_measure integer) IS 'Return a table (index, measure, geom), representing points along a stream between specified locations at specified interval';


--
-- Name: fwa_networktrace(integer, double precision, integer, double precision, double precision); Type: FUNCTION; Schema: postgisftw; Owner: -
--

CREATE FUNCTION postgisftw.fwa_networktrace(blue_line_key_a integer, measure_a double precision, blue_line_key_b integer, measure_b double precision, tolerance double precision DEFAULT 1) RETURNS TABLE(linear_feature_id bigint, edge_type integer, blue_line_key integer, watershed_key integer, wscode public.ltree, localcode public.ltree, watershed_group_code character varying, downstream_route_measure double precision, upstream_route_measure double precision, length_metre double precision, waterbody_key integer, gnis_name character varying, stream_order integer, stream_magnitude integer, feature_code character varying, gradient double precision, left_right_tributary character varying, stream_order_parent integer, stream_order_max integer, upstream_area_ha double precision, map_upstream integer, channel_width double precision, channel_width_source text, mad_m3s double precision, geom public.geometry)
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$


-- trace downstream from both locations, the portion of the
-- traces that are not common to both is the path between the points

-- return source features
WITH p1 AS (
  SELECT *
  FROM fwa_downstreamtrace($1, $2, $5)
),

p2 AS (
  SELECT *
  FROM fwa_downstreamtrace($3, $4, $5)
)

SELECT * FROM (

  SELECT p1.*
  FROM p1
  LEFT JOIN p2 ON p1.linear_feature_id = p2.linear_feature_id
  WHERE p2.linear_feature_id IS NULL

  UNION ALL

  SELECT p2.*
  FROM p2
  LEFT JOIN p1 ON p2.linear_feature_id = p1.linear_feature_id
  WHERE p1.linear_feature_id IS NULL

  UNION ALL

  -- if one point is downstream of the other, the split source stream
  -- needs to be added to the result (the linear feature id is common to both traces,
  -- so excluded above, but a portion of it needs to be included)
  SELECT
    s.linear_feature_id,
    s.edge_type,
    s.blue_line_key,
    s.watershed_key,
    s.wscode,
    s.localcode,
    s.watershed_group_code,
    least(p1.upstream_route_measure, p2.upstream_route_measure) as downstream_route_measure,
    greatest(p1.upstream_route_measure, p2.upstream_route_measure) as upstream_route_measure,
    greatest(p1.upstream_route_measure, p2.upstream_route_measure) - least(p1.upstream_route_measure, p2.upstream_route_measure) as length_metre,
    s.waterbody_key,
    s.gnis_name,
    s.stream_order,
    s.stream_magnitude,
    s.feature_code,
    s.gradient,
    s.left_right_tributary,
    s.stream_order_parent,
    s.stream_order_max,
    s.upstream_area_ha,
    s.map_upstream,
    s.channel_width,
    s.channel_width_source,
    s.mad_m3s,
    st_locatebetween(s.geom,
      least(p1.upstream_route_measure, p2.upstream_route_measure),
      greatest(p1.upstream_route_measure, p2.upstream_route_measure)
    )  as geom
  FROM p1
  INNER JOIN p2 ON p1.linear_feature_id = p2.linear_feature_id
  AND p1.upstream_route_measure != p2.upstream_route_measure
  -- join to source streams so we don't have to compare the two geoms to find the full length segment
  INNER JOIN whse_basemapping.fwa_streams s ON s.linear_feature_id = p1.linear_feature_id

) AS f
WHERE f.blue_line_key = f.watershed_key -- do not return side channels, just the network path
ORDER BY wscode DESC, localcode DESC, downstream_route_measure DESC;


$_$;


--
-- Name: FUNCTION fwa_networktrace(blue_line_key_a integer, measure_a double precision, blue_line_key_b integer, measure_b double precision, tolerance double precision); Type: COMMENT; Schema: postgisftw; Owner: -
--

COMMENT ON FUNCTION postgisftw.fwa_networktrace(blue_line_key_a integer, measure_a double precision, blue_line_key_b integer, measure_b double precision, tolerance double precision) IS 'Return aggregated stream network path(s) between the provided locations';


--
-- Name: fwa_networktraceagg(integer, double precision, integer, double precision, double precision); Type: FUNCTION; Schema: postgisftw; Owner: -
--

CREATE FUNCTION postgisftw.fwa_networktraceagg(blue_line_key_a integer, measure_a double precision, blue_line_key_b integer, measure_b double precision, tolerance double precision DEFAULT 1) RETURNS TABLE(id integer, from_blue_line_key integer, from_measure double precision, to_blue_line_key integer, to_measure double precision, geom public.geometry)
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$

  -- trace downstream from both locations, the portion of the
  -- traces that are not common to both is the path between the points

  WITH t1 AS (
    SELECT 1 as id, *
    FROM fwa_downstreamtrace($1, $2, $5)
    WHERE blue_line_key = watershed_key
  ),

  t2 AS (
    SELECT 2 as id, *
    FROM fwa_downstreamtrace($3, $4, $5)
    WHERE blue_line_key = watershed_key
  ),

  -- if the origins are flow-connected (ie downstream/upstream of the other),
  -- the split source stream needs to be added to the result (the linear feature id
  -- is common to both traces and excluded below, but a portion of it needs to be included)
  remainder AS (
    SELECT
      s.linear_feature_id,
      s.edge_type,
      s.blue_line_key,
      s.watershed_key,
      s.wscode,
      s.localcode,
      s.watershed_group_code,
      least(t1.upstream_route_measure, t2.upstream_route_measure) as downstream_route_measure,
      greatest(t1.upstream_route_measure, t2.upstream_route_measure) as upstream_route_measure,
      greatest(t1.upstream_route_measure, t2.upstream_route_measure) - least(t1.upstream_route_measure, t2.upstream_route_measure) as length_metre,
      s.waterbody_key,
      s.gnis_name,
      s.stream_order,
      s.stream_magnitude,
      s.feature_code,
      s.gradient,
      s.left_right_tributary,
      s.stream_order_parent,
      s.stream_order_max,
      s.upstream_area_ha,
      s.map_upstream,
      s.channel_width,
      s.channel_width_source,
      s.mad_m3s,
      st_force3d(st_locatebetween(s.geom,
        least(t1.upstream_route_measure, t2.upstream_route_measure),
        greatest(t1.upstream_route_measure, t2.upstream_route_measure)
      ))  as geom
    FROM t1
    INNER JOIN t2 ON t1.linear_feature_id = t2.linear_feature_id
    AND t1.upstream_route_measure != t2.upstream_route_measure
    -- join to source streams so we don't have to compare the two geoms to find the full length segment
    INNER JOIN whse_basemapping.fwa_streams s ON s.linear_feature_id = t1.linear_feature_id
  ),

  t1_agg AS (
    SELECT
      t1.id,
      first(t1.blue_line_key) as from_blue_line_key,
      first(t1.upstream_route_measure) as from_measure,
      last(t1.blue_line_key) as to_blue_line_key,
      last(t1.downstream_route_measure) as to_measure,
      st_linemerge(st_union(t1.geom)) as geom
    FROM t1
    LEFT JOIN t2 ON t1.linear_feature_id = t2.linear_feature_id
    WHERE t2.linear_feature_id IS NULL
    GROUP BY t1.id
  ),

  t2_agg AS (
    SELECT
      t2.id,
      first(t2.blue_line_key) as from_blue_line_key,
      first(t2.upstream_route_measure) as from_measure,
      last(t2.blue_line_key) as to_blue_line_key,
      last(t2.downstream_route_measure) as to_measure,
      st_linemerge(st_union(t2.geom)) as geom
    FROM t2
    LEFT JOIN t1 ON t2.linear_feature_id = t1.linear_feature_id
    WHERE t1.linear_feature_id IS NULL
    GROUP BY t2.id
  ),

  -- determin which trace the remainder should be aggregated with
  r_agg as (
    select
      coalesce(t1_agg.id, t2_agg.id) as id,
      r.blue_line_key as from_blue_line_key,
      r.upstream_route_measure as from_measure,
      r.blue_line_key as to_blue_line_key,
      r.downstream_route_measure as to_measure,
      r.geom
    from remainder r
    left outer join t1_agg on round(r.upstream_route_measure) = round(t1_agg.to_measure)
    left outer join t2_agg on round(r.upstream_route_measure) = round(t2_agg.to_measure)
  ),

  all_agg as (
    select * from t1_agg
    union all
    select * from t2_agg
    union all
    select * from r_agg
  )

  select
    id,
    first(from_blue_line_key) as from_blue_line_key,
    first(from_measure) as from_measure,
    last(to_blue_line_key) as to_blue_line_key,
    last(to_measure) as to_measure,
    ST_RemoveRepeatedPoints(st_linemerge(st_union(st_multi(geom), .01))) as geom
  from all_agg
  group by id

$_$;


--
-- Name: fwa_segmentalonginterval(integer, integer, integer, integer); Type: FUNCTION; Schema: postgisftw; Owner: -
--

CREATE FUNCTION postgisftw.fwa_segmentalonginterval(blue_line_key integer, interval_length integer DEFAULT 100, start_measure integer DEFAULT 0, end_measure integer DEFAULT NULL::integer) RETURNS TABLE(index integer, downstream_route_measure double precision, upstream_route_measure double precision, geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$

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


WITH start_pts as
(
  SELECT
    generate_series(0, v_measure_end / v_interval) as n,
    v_blkey as blue_line_key,
    generate_series(v_measure_start, v_measure_end, v_interval) as downstream_route_measure
),

intervals as (
  SELECT
    n,
    s.blue_line_key,
    s.downstream_route_measure,
    coalesce(lead(s.downstream_route_measure) OVER (ORDER BY n), v_measure_end) AS upstream_route_measure
  FROM start_pts s
)

select
  i.n::integer as index,
  i.downstream_route_measure::double precision,
  i.upstream_route_measure::double precision,
  ST_Multi(st_union(ST_LocateBetween(s.geom, i.downstream_route_measure, i.upstream_route_measure))) as geom
FROM intervals i
inner join whse_basemapping.fwa_stream_networks_sp s on s.blue_line_key = i.blue_line_key
AND s.downstream_route_measure <= i.downstream_route_measure
AND s.upstream_route_measure > i.downstream_route_measure
GROUP BY i.n, i.blue_line_key, i.downstream_route_measure, i.upstream_route_measure
ORDER BY i.n;

END;

$$;


--
-- Name: FUNCTION fwa_segmentalonginterval(blue_line_key integer, interval_length integer, start_measure integer, end_measure integer); Type: COMMENT; Schema: postgisftw; Owner: -
--

COMMENT ON FUNCTION postgisftw.fwa_segmentalonginterval(blue_line_key integer, interval_length integer, start_measure integer, end_measure integer) IS 'Return a table (index, downstream_route_measure, upstream_route_measure, geom), representing segments along a stream between specified locations at specified interval';


--
-- Name: fwa_slopealonginterval(integer, integer, integer, integer, integer); Type: FUNCTION; Schema: postgisftw; Owner: -
--

CREATE FUNCTION postgisftw.fwa_slopealonginterval(blue_line_key integer, interval_length integer DEFAULT 100, distance_upstream integer DEFAULT 100, start_measure integer DEFAULT 0, end_measure integer DEFAULT NULL::integer) RETURNS TABLE(idx integer, downstream_measure numeric, downstream_z numeric, upstream_measure numeric, upstream_z numeric, gradient numeric)
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$

DECLARE

   v_blkey          integer := blue_line_key;
   v_interval       integer := interval_length;
   v_distance_upstream integer := distance_upstream;
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

-- if no end point provided, process the entire stream
IF v_measure_end IS NULL THEN
  v_measure_end := floor(v_measure_max);
END IF;

IF v_measure_end > v_measure_max THEN
  RAISE NOTICE 'Value: %', v_measure_end;
  RAISE EXCEPTION 'Input end_measure value does not exist in FWA';
END IF;

IF v_measure_end <= v_measure_start THEN
  RAISE EXCEPTION 'Input end_measure value must be more than input start_measure value';
END IF;

IF (v_measure_end - v_measure_start) < v_interval THEN
  RAISE EXCEPTION 'Distance between start_measure and end_measure is less than input interval_length';
END IF;


RETURN QUERY

with dnstr as (
  select
    index as idx,
    downstream_route_measure as dnstr_measure,
    st_z(geom) as dnstr_z
  from fwa_locatealonginterval(v_blkey, v_interval, v_measure_start, v_measure_end)
),

upstr as (
  select
    index as idx,
    downstream_route_measure as upstr_measure,
    st_z(geom) as upstr_z
  from fwa_locatealonginterval(v_blkey, v_interval, (v_measure_start + v_distance_upstream), v_measure_end)
)

select
  d.idx,
  d.dnstr_measure::numeric as downstream_route_measure,
  round(d.dnstr_z::numeric, 2) as downstream_z,
  u.upstr_measure::numeric as upstream_route_measure,
  round(u.upstr_z::numeric, 2) as upstream_z,
  round(((u.upstr_z - d.dnstr_z) / (u.upstr_measure - d.dnstr_measure))::numeric, 3) as gradient
from dnstr d
inner join upstr u on d.idx = u.idx;

END;

$$;


--
-- Name: FUNCTION fwa_slopealonginterval(blue_line_key integer, interval_length integer, distance_upstream integer, start_measure integer, end_measure integer); Type: COMMENT; Schema: postgisftw; Owner: -
--

COMMENT ON FUNCTION postgisftw.fwa_slopealonginterval(blue_line_key integer, interval_length integer, distance_upstream integer, start_measure integer, end_measure integer) IS 'Return a table (n, downstream_route_measure, downstream_z, upstream_route_measure, upstream_z, gradient), measuring slope at equal intervals';


--
-- Name: fwa_streamsasmvt(integer, integer, integer); Type: FUNCTION; Schema: postgisftw; Owner: -
--

CREATE FUNCTION postgisftw.fwa_streamsasmvt(z integer, x integer, y integer) RETURNS bytea
    LANGUAGE plpgsql STABLE PARALLEL SAFE
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
$$;


--
-- Name: FUNCTION fwa_streamsasmvt(z integer, x integer, y integer); Type: COMMENT; Schema: postgisftw; Owner: -
--

COMMENT ON FUNCTION postgisftw.fwa_streamsasmvt(z integer, x integer, y integer) IS 'Zoom-level dependent FWA streams';


--
-- Name: fwa_upstream(integer, double precision, double precision, public.ltree, public.ltree, integer, double precision, public.ltree, public.ltree, boolean, double precision); Type: FUNCTION; Schema: postgisftw; Owner: -
--

CREATE FUNCTION postgisftw.fwa_upstream(blue_line_key_a integer, downstream_route_measure_a double precision, upstream_route_measure_a double precision, wscode_a public.ltree, localcode_a public.ltree, blue_line_key_b integer, downstream_route_measure_b double precision, wscode_b public.ltree, localcode_b public.ltree, include_equivalents boolean DEFAULT false, tolerance double precision DEFAULT 0.001) RETURNS TABLE(upstream boolean)
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$


WITH codes as
  (
    SELECT
      wscode_a::ltree as wscode_ltree_a,
      localcode_a::ltree as localcode_ltree_a,
      wscode_b::ltree as wscode_ltree_b,
      localcode_b::ltree as localcode_ltree_b
  )

SELECT
  -- b is a child of a, always
  wscode_ltree_b <@ wscode_ltree_a AND

    -- conditional upstream join logic, based on whether watershed codes are equivalent
  (
    CASE
       -- first, consider simple case - streams where wscode and localcode are equivalent
       WHEN include_equivalents IS False AND
          wscode_ltree_a = localcode_ltree_a AND
          (
              -- upstream tribs
              (blue_line_key_b != blue_line_key_a) OR

              -- on same blue line
              (blue_line_key_b = blue_line_key_a AND
               downstream_route_measure_b >= upstream_route_measure_a + tolerance)
          )
          -- exclude distributaries with equivalent codes and different blkeys
          AND NOT (
            wscode_ltree_a = wscode_ltree_b AND
            localcode_ltree_a = localcode_ltree_b AND
            blue_line_key_a != blue_line_key_b
          )
       THEN TRUE

       -- next, the more complicated case - where wscode and localcode are not equal
       WHEN include_equivalents IS False AND
         wscode_ltree_a != localcode_ltree_a AND
          (
                -- on same blue line
              (blue_line_key_b = blue_line_key_a AND
               downstream_route_measure_b >= upstream_route_measure_a + tolerance)
              OR
              -- tributaries: b wscode > a localcode and b wscode is not a child of a localcode
              (wscode_ltree_b > localcode_ltree_a AND
               NOT wscode_ltree_b <@ localcode_ltree_a)
              OR
              -- capture side channels: b is the same watershed code, with larger localcode
              (wscode_ltree_b = wscode_ltree_a
               AND localcode_ltree_b > localcode_ltree_a)
          )
        THEN TRUE

      -- run the same process, but return true for locations at the same measure
      -- (within tolerance)
       WHEN include_equivalents IS True AND
          wscode_ltree_a = localcode_ltree_a AND
          (
              -- upstream tribs
              (blue_line_key_b != blue_line_key_a) OR

              -- on same blue line
              (blue_line_key_b = blue_line_key_a AND
               (downstream_route_measure_b > upstream_route_measure_a OR
                abs(upstream_route_measure_a - downstream_route_measure_b) <= tolerance)
              )
          )
          -- exclude distributaries with equivalent codes and different blkeys
          AND NOT (
            wscode_ltree_a = wscode_ltree_b AND
            localcode_ltree_a = localcode_ltree_b AND
            blue_line_key_a != blue_line_key_b
          )
       THEN TRUE

       -- next, the more complicated case - where wscode and localcode are not equal
       WHEN include_equivalents IS True AND
         wscode_ltree_a != localcode_ltree_a AND
          (
              -- on same blue line
              (blue_line_key_b = blue_line_key_a AND
               (downstream_route_measure_b > upstream_route_measure_a OR
                abs(upstream_route_measure_a - downstream_route_measure_b) <= tolerance)
              )
              OR
              -- tributaries: b wscode > a localcode and b wscode is not a child of a localcode
              (wscode_ltree_b > localcode_ltree_a AND
               NOT wscode_ltree_b <@ localcode_ltree_a)
              OR
              -- capture side channels: b is the same watershed code, with larger localcode
              (wscode_ltree_b = wscode_ltree_a
               AND localcode_ltree_b > localcode_ltree_a)
          )
        THEN TRUE

        ELSE FALSE
    END
  )
FROM codes
$$;


--
-- Name: FUNCTION fwa_upstream(blue_line_key_a integer, downstream_route_measure_a double precision, upstream_route_measure_a double precision, wscode_a public.ltree, localcode_a public.ltree, blue_line_key_b integer, downstream_route_measure_b double precision, wscode_b public.ltree, localcode_b public.ltree, include_equivalents boolean, tolerance double precision); Type: COMMENT; Schema: postgisftw; Owner: -
--

COMMENT ON FUNCTION postgisftw.fwa_upstream(blue_line_key_a integer, downstream_route_measure_a double precision, upstream_route_measure_a double precision, wscode_a public.ltree, localcode_a public.ltree, blue_line_key_b integer, downstream_route_measure_b double precision, wscode_b public.ltree, localcode_b public.ltree, include_equivalents boolean, tolerance double precision) IS 'Evaluate if a set of watershed codes/measures is upstream of another set of watershed codes/measures';


--
-- Name: fwa_upstreamtrace(integer, double precision, double precision); Type: FUNCTION; Schema: postgisftw; Owner: -
--

CREATE FUNCTION postgisftw.fwa_upstreamtrace(start_blue_line_key integer, start_measure double precision, tolerance double precision DEFAULT 1) RETURNS TABLE(linear_feature_id bigint, edge_type integer, blue_line_key integer, watershed_key integer, wscode public.ltree, localcode public.ltree, watershed_group_code character varying, downstream_route_measure double precision, upstream_route_measure double precision, length_metre double precision, waterbody_key integer, gnis_name character varying, stream_order integer, stream_magnitude integer, feature_code character varying, gradient double precision, left_right_tributary character varying, stream_order_parent integer, stream_order_max integer, upstream_area_ha double precision, map_upstream integer, channel_width double precision, channel_width_source text, mad_m3s double precision, geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
    AS $$

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
  AND round(s.upstream_route_measure::numeric, 4) > round(v_measure::numeric, 4)
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

$$;


--
-- Name: FUNCTION fwa_upstreamtrace(start_blue_line_key integer, start_measure double precision, tolerance double precision); Type: COMMENT; Schema: postgisftw; Owner: -
--

COMMENT ON FUNCTION postgisftw.fwa_upstreamtrace(start_blue_line_key integer, start_measure double precision, tolerance double precision) IS 'Return stream network upstream of provided location';


--
-- Name: fwa_watershedatmeasure(integer, double precision); Type: FUNCTION; Schema: postgisftw; Owner: -
--

CREATE FUNCTION postgisftw.fwa_watershedatmeasure(blue_line_key integer, downstream_route_measure double precision) RETURNS TABLE(wscode_ltree text, localcode_ltree text, area_ha numeric, refine_method text, geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
    AS $$

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
$$;


--
-- Name: FUNCTION fwa_watershedatmeasure(blue_line_key integer, downstream_route_measure double precision); Type: COMMENT; Schema: postgisftw; Owner: -
--

COMMENT ON FUNCTION postgisftw.fwa_watershedatmeasure(blue_line_key integer, downstream_route_measure double precision) IS 'Provided a location as blue_line_key and downstream_route_measure, return the entire watershed boundary upstream of the location';


--
-- Name: fwa_watershedhex(integer, double precision); Type: FUNCTION; Schema: postgisftw; Owner: -
--

CREATE FUNCTION postgisftw.fwa_watershedhex(blue_line_key integer, downstream_route_measure double precision) RETURNS TABLE(hex_id bigint, geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$

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
$$;


--
-- Name: FUNCTION fwa_watershedhex(blue_line_key integer, downstream_route_measure double precision); Type: COMMENT; Schema: postgisftw; Owner: -
--

COMMENT ON FUNCTION postgisftw.fwa_watershedhex(blue_line_key integer, downstream_route_measure double precision) IS 'Provided a location as blue_line_key and downstream_route_measure, return a 25m hexagon grid covering first order watershed in which location lies';


--
-- Name: fwa_watershedstream(integer, double precision); Type: FUNCTION; Schema: postgisftw; Owner: -
--

CREATE FUNCTION postgisftw.fwa_watershedstream(blue_line_key integer, downstream_route_measure double precision) RETURNS TABLE(linear_feature_id bigint, geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$

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

$$;


--
-- Name: FUNCTION fwa_watershedstream(blue_line_key integer, downstream_route_measure double precision); Type: COMMENT; Schema: postgisftw; Owner: -
--

COMMENT ON FUNCTION postgisftw.fwa_watershedstream(blue_line_key integer, downstream_route_measure double precision) IS 'Provided a location as blue_line_key and downstream_route_measure, return stream segments upstream, within the same first order watershed.';


--
-- Name: hydroshed(double precision, double precision, integer); Type: FUNCTION; Schema: postgisftw; Owner: -
--

CREATE FUNCTION postgisftw.hydroshed(x double precision, y double precision, srid integer) RETURNS TABLE(geom public.geometry)
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$

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

$$;


--
-- Name: FUNCTION hydroshed(x double precision, y double precision, srid integer); Type: COMMENT; Schema: postgisftw; Owner: -
--

COMMENT ON FUNCTION postgisftw.hydroshed(x double precision, y double precision, srid integer) IS 'Return aggregated boundary of all hydroshed polygons upstream of the provided location';


--
-- Name: cdb_hexagongrid(public.geometry, double precision, public.geometry, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cdb_hexagongrid(ext public.geometry, side double precision, origin public.geometry DEFAULT NULL::public.geometry, maxcells integer DEFAULT (512 * 512)) RETURNS SETOF public.geometry
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$
DECLARE
  h GEOMETRY; -- hexagon
  c GEOMETRY; -- center point
  rec RECORD;
  hstep FLOAT8; -- horizontal step
  vstep FLOAT8; -- vertical step
  vstart FLOAT8;
  vstartary FLOAT8[];
  vstartidx INTEGER;
  hskip BIGINT;
  hstart FLOAT8;
  hend FLOAT8;
  vend FLOAT8;
  xoff FLOAT8;
  yoff FLOAT8;
  xgrd FLOAT8;
  ygrd FLOAT8;
  srid INTEGER;
BEGIN

  --            |     |
  --            |hstep|
  --  ______   ___    |
  --  vstep  /     \ ___ /
  --  ______ \ ___ /     \
  --         /     \ ___ /
  --
  --
  RAISE DEBUG 'Side: %', side;

  vstep := side * sqrt(3); -- x 2 ?
  hstep := side * 1.5;

  RAISE DEBUG 'vstep: %', vstep;
  RAISE DEBUG 'hstep: %', hstep;

  srid := ST_SRID(ext);

  xoff := 0;
  yoff := 0;

  IF origin IS NOT NULL THEN
    IF ST_SRID(origin) != srid THEN
      RAISE EXCEPTION 'SRID mismatch between extent (%) and origin (%)', srid, ST_SRID(origin);
    END IF;
    xoff := ST_X(origin);
    yoff := ST_Y(origin);
  END IF;

  RAISE DEBUG 'X offset: %', xoff;
  RAISE DEBUG 'Y offset: %', yoff;

  xgrd := side * 0.5;
  ygrd := ( side * sqrt(3) ) / 2.0;
  RAISE DEBUG 'X grid size: %', xgrd;
  RAISE DEBUG 'Y grid size: %', ygrd;

  -- Tweak horizontal start on hstep*2 grid from origin
  hskip := ceil((ST_XMin(ext)-xoff)/hstep);
  RAISE DEBUG 'hskip: %', hskip;
  hstart := xoff + hskip*hstep;
  RAISE DEBUG 'hstart: %', hstart;

  -- Tweak vertical start on hstep grid from origin
  vstart := yoff + ceil((ST_Ymin(ext)-yoff)/vstep)*vstep;
  RAISE DEBUG 'vstart: %', vstart;

  hend := ST_XMax(ext);
  vend := ST_YMax(ext);

  IF vstart - (vstep/2.0) < ST_YMin(ext) THEN
    vstartary := ARRAY[ vstart + (vstep/2.0), vstart ];
  ELSE
    vstartary := ARRAY[ vstart - (vstep/2.0), vstart ];
  END IF;

  If maxcells IS NOT NULL AND maxcells > 0 THEN
    IF CEIL((CEIL((vend-vstart)/(vstep/2.0)) * CEIL((hend-hstart)/(hstep*2.0/3.0)))/3.0)::integer > maxcells THEN
      RAISE EXCEPTION 'The requested grid is too big to be rendered';
    END IF;
  END IF;

  vstartidx := abs(hskip)%2;

  RAISE DEBUG 'vstartary: % : %', vstartary[1], vstartary[2];
  RAISE DEBUG 'vstartidx: %', vstartidx;

  c := ST_SetSRID(ST_MakePoint(hstart, vstartary[vstartidx+1]), srid);
  h := ST_SnapToGrid(CDB_MakeHexagon(c, side), xoff, yoff, xgrd, ygrd);
  vstartidx := (vstartidx + 1) % 2;
  WHILE ST_X(c) < hend LOOP -- over X
    --RAISE DEBUG 'X loop starts, center point: %', ST_AsText(c);
    WHILE ST_Y(c) < vend LOOP -- over Y
      --RAISE DEBUG 'Center: %', ST_AsText(c);
      --h := ST_SnapToGrid(CDB_MakeHexagon(c, side), xoff, yoff, xgrd, ygrd);
      RETURN NEXT h;
      h := ST_SnapToGrid(ST_Translate(h, 0, vstep), xoff, yoff, xgrd, ygrd);
      c := ST_Translate(c, 0, vstep);  -- TODO: drop ?
    END LOOP;
    -- TODO: translate h direcly ...
    c := ST_SetSRID(ST_MakePoint(ST_X(c)+hstep, vstartary[vstartidx+1]), srid);
    h := ST_SnapToGrid(CDB_MakeHexagon(c, side), xoff, yoff, xgrd, ygrd);
    vstartidx := (vstartidx + 1) % 2;
  END LOOP;

  RETURN;
END
$$;


--
-- Name: cdb_makehexagon(public.geometry, double precision); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cdb_makehexagon(center public.geometry, radius double precision) RETURNS public.geometry
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
  SELECT ST_MakePolygon(ST_MakeLine(geom))
    FROM
    (
      SELECT (ST_DumpPoints(ST_ExteriorRing(ST_Buffer($1, $2, 3)))).*
    ) as points
    WHERE path[1] % 2 != 0
$_$;


--
-- Name: first_agg(anyelement, anyelement); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.first_agg(anyelement, anyelement) RETURNS anyelement
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$SELECT $1$_$;


--
-- Name: last_agg(anyelement, anyelement); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.last_agg(anyelement, anyelement) RETURNS anyelement
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
        SELECT $2;
$_$;


--
-- Name: st_safe_repair(public.geometry, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.st_safe_repair(geom public.geometry, message text DEFAULT '[unspecified]'::text) RETURNS public.geometry
    LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
    AS $$
begin
    if ST_IsEmpty(geom)
    then
        raise debug 'ST_Safe_Repair: geometry is empty (%)', message;
-- empty POLYGON makes ST_Segmentize fail, replace it with empty GEOMETRYCOLLECTION
        return ST_SetSRID('GEOMETRYCOLLECTION EMPTY' :: geometry, ST_SRID(geom));
    end if;
    if ST_IsValid(geom)
    then
        return ST_ForceRHR(ST_CollectionExtract(geom, ST_Dimension(geom) + 1));
    end if;
    return
    ST_ForceRHR(
        ST_CollectionExtract(
            ST_MakeValid(
                geom
            ),
            ST_Dimension(geom) + 1
        )
    );
end
$$;


--
-- Name: fwa_huc12(character varying); Type: FUNCTION; Schema: usgs; Owner: -
--

CREATE FUNCTION usgs.fwa_huc12(id character varying) RETURNS public.geometry
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $$

WITH RECURSIVE walkup (huc12, geom) AS
    (
        SELECT huc12, wsd.geom
        FROM usgs.wbdhu12 wsd
        WHERE huc12 = id

        UNION ALL

        SELECT b.huc12, b.geom
        FROM usgs.wbdhu12 b,
        walkup w
        WHERE b.tohuc = w.huc12
    )
SELECT
  ST_Union(w.geom) as geom
FROM walkup w;

$$;


--
-- Name: FUNCTION fwa_huc12(id character varying); Type: COMMENT; Schema: usgs; Owner: -
--

COMMENT ON FUNCTION usgs.fwa_huc12(id character varying) IS 'Return geometry of aggregated watershed boundary for watershed upstream of provided huc12 id';


--
-- Name: fwa_downstream(public.ltree, public.ltree, public.ltree, public.ltree); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_downstream(wscode_ltree_a public.ltree, localcode_ltree_a public.ltree, wscode_ltree_b public.ltree, localcode_ltree_b public.ltree) RETURNS boolean
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$


SELECT
-- watershed code a is a descendant of watershed code b
  wscode_ltree_a <@ wscode_ltree_b AND
  (
    -- AND localcode of a is bigger than localcode of b at given level
    subltree(
        localcode_ltree_a,
        0,
        nlevel(localcode_ltree_b)
    ) > localcode_ltree_b
    -- OR, where b's wscode and localcode are equivalent
    -- (ie, at bottom segment of a given watershed code)
    -- but excluding records in a and b on same stream
    OR (
        wscode_ltree_b = localcode_ltree_b AND
        wscode_ltree_a != wscode_ltree_b
    )
  )

$$;


--
-- Name: fwa_downstream(integer, double precision, public.ltree, public.ltree, integer, double precision, public.ltree, public.ltree, boolean, double precision); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_downstream(blue_line_key_a integer, downstream_route_measure_a double precision, wscode_ltree_a public.ltree, localcode_ltree_a public.ltree, blue_line_key_b integer, downstream_route_measure_b double precision, wscode_ltree_b public.ltree, localcode_ltree_b public.ltree, include_equivalents boolean DEFAULT false, tolerance double precision DEFAULT 0.001) RETURNS boolean
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$

SELECT
  whse_basemapping.FWA_Downstream(
    blue_line_key_a,
    downstream_route_measure_a,
    downstream_route_measure_a,
    wscode_ltree_a,
    localcode_ltree_a,
    blue_line_key_b,
    downstream_route_measure_b,
    wscode_ltree_b,
    localcode_ltree_b,
    include_equivalents,
    tolerance
  )

$$;


--
-- Name: fwa_downstream(integer, double precision, double precision, public.ltree, public.ltree, integer, double precision, public.ltree, public.ltree, boolean, double precision); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_downstream(blue_line_key_a integer, downstream_route_measure_a double precision, upstream_route_measure_a double precision, wscode_ltree_a public.ltree, localcode_ltree_a public.ltree, blue_line_key_b integer, downstream_route_measure_b double precision, wscode_ltree_b public.ltree, localcode_ltree_b public.ltree, include_equivalents boolean DEFAULT false, tolerance double precision DEFAULT 0.001) RETURNS boolean
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$

  SELECT

    CASE WHEN include_equivalents IS False THEN
    -- criteria 1 - on the same stream and lower down (minus tolerance/fudge factor)
    -- the tolerance value nudges record a down slightly so that equivalent/near equivalent features are not returned
        (
            blue_line_key_a = blue_line_key_b AND
            downstream_route_measure_b <= downstream_route_measure_a - tolerance

        )
    OR
    -- criteria 2 - watershed code a is a descendant of watershed code b
        (
            wscode_ltree_a <@ wscode_ltree_b AND
            (
                -- AND localcode of a is bigger than localcode of b at given level
                subltree(
                    localcode_ltree_a,
                    0,
                    nlevel(localcode_ltree_b)
                ) > localcode_ltree_b
                -- OR, where b's wscode and localcode are equivalent
                -- (ie, at bottom segment of a given watershed code)
                -- but excluding records in a and b on same stream
                OR (
                    wscode_ltree_b = localcode_ltree_b AND
                    wscode_ltree_a != wscode_ltree_b
                )
                -- OR any missed side channels on the same watershed code
                OR (
                    wscode_ltree_a = wscode_ltree_b AND
                    blue_line_key_a != blue_line_key_b
                  AND localcode_ltree_a > localcode_ltree_b)
                )
        )

  ELSE

    -- criteria 1 - on the same stream and lower down or in the same position
    -- the tolerance value is how far the features can be apart to be considered at the same spot
    (
      blue_line_key_a = blue_line_key_b AND
      (
        downstream_route_measure_b < downstream_route_measure_a  OR
        abs(downstream_route_measure_a - downstream_route_measure_b) <= tolerance
      )
    )

    OR
    -- criteria 2 - watershed code a is a descendant of watershed code b
        (
            wscode_ltree_a <@ wscode_ltree_b AND
            (
                -- AND localcode of a is bigger than localcode of b at given level
                subltree(
                    localcode_ltree_a,
                    0,
                    nlevel(localcode_ltree_b)
                ) > localcode_ltree_b
                -- OR, where b's wscode and localcode are equivalent
                -- (ie, at bottom segment of a given watershed code)
                -- but excluding records in a and b on same stream
                OR (
                    wscode_ltree_b = localcode_ltree_b AND
                    wscode_ltree_a != wscode_ltree_b
                )
                -- OR any missed side channels on the same watershed code
                OR (
                    wscode_ltree_a = wscode_ltree_b AND
                    blue_line_key_a != blue_line_key_b
                  AND localcode_ltree_a > localcode_ltree_b)
                )
        )

END

$$;


--
-- Name: fwa_downstreamtrace(integer, double precision, double precision); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_downstreamtrace(start_blue_line_key integer, start_measure double precision, tolerance double precision DEFAULT 1) RETURNS TABLE(linear_feature_id bigint, edge_type integer, blue_line_key integer, watershed_key integer, wscode public.ltree, localcode public.ltree, watershed_group_code character varying, downstream_route_measure double precision, upstream_route_measure double precision, length_metre double precision, waterbody_key integer, gnis_name character varying, stream_order integer, stream_magnitude integer, feature_code character varying, gradient double precision, left_right_tributary character varying, stream_order_parent integer, stream_order_max integer, upstream_area_ha double precision, map_upstream integer, channel_width double precision, channel_width_source text, mad_m3s double precision, geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
    AS $$

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
  AND round(s.upstream_route_measure::numeric, 4) > round(v_measure::numeric, 4)
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

$$;


--
-- Name: FUNCTION fwa_downstreamtrace(start_blue_line_key integer, start_measure double precision, tolerance double precision); Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON FUNCTION whse_basemapping.fwa_downstreamtrace(start_blue_line_key integer, start_measure double precision, tolerance double precision) IS 'Return stream network downstream of provided location';


--
-- Name: fwa_indexpoint(public.geometry, double precision, integer); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_indexpoint(point public.geometry, tolerance double precision DEFAULT 5000, num_features integer DEFAULT 1) RETURNS TABLE(linear_feature_id bigint, gnis_name text, wscode_ltree public.ltree, localcode_ltree public.ltree, blue_line_key integer, downstream_route_measure double precision, distance_to_stream double precision, bc_ind boolean, geom public.geometry)
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
    ORDER BY blue_line_key, distance_to_stream
) b
WHERE distance_to_stream <= $2
ORDER BY distance_to_stream asc
LIMIT $3

$_$;


--
-- Name: FUNCTION fwa_indexpoint(point public.geometry, tolerance double precision, num_features integer); Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON FUNCTION whse_basemapping.fwa_indexpoint(point public.geometry, tolerance double precision, num_features integer) IS 'Provided a BC Albers point geometry, return the point indexed (snapped) to nearest stream(s) within specified tolerance (m)';


--
-- Name: fwa_locatealong(integer, double precision); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_locatealong(blue_line_key integer, downstream_route_measure double precision) RETURNS TABLE(geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
    AS $$

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

$$;


--
-- Name: FUNCTION fwa_locatealong(blue_line_key integer, downstream_route_measure double precision); Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON FUNCTION whse_basemapping.fwa_locatealong(blue_line_key integer, downstream_route_measure double precision) IS 'Return a point on the stream network based on the location provided by blue_line_key and downstream_route_measure';


--
-- Name: fwa_locatealonginterval(integer, integer, integer, integer); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_locatealonginterval(blue_line_key integer, interval_length integer DEFAULT 1000, start_measure integer DEFAULT 0, end_measure integer DEFAULT NULL::integer) RETURNS TABLE(index integer, downstream_route_measure double precision, geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$

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
  whse_basemapping.FWA_LocateAlong(s.blue_line_key, s.downstream_route_measure::float) as geom
FROM segments s;

END;

$$;


--
-- Name: FUNCTION fwa_locatealonginterval(blue_line_key integer, interval_length integer, start_measure integer, end_measure integer); Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON FUNCTION whse_basemapping.fwa_locatealonginterval(blue_line_key integer, interval_length integer, start_measure integer, end_measure integer) IS 'Return a table (index, measure, geom), representing points along a stream at a specified interval between specified locations';


--
-- Name: fwa_networktrace(integer, double precision, integer, double precision, double precision); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_networktrace(blue_line_key_a integer, measure_a double precision, blue_line_key_b integer, measure_b double precision, tolerance double precision DEFAULT 1) RETURNS TABLE(linear_feature_id bigint, edge_type integer, blue_line_key integer, watershed_key integer, wscode public.ltree, localcode public.ltree, watershed_group_code character varying, downstream_route_measure double precision, upstream_route_measure double precision, length_metre double precision, waterbody_key integer, gnis_name character varying, stream_order integer, stream_magnitude integer, feature_code character varying, gradient double precision, left_right_tributary character varying, stream_order_parent integer, stream_order_max integer, upstream_area_ha double precision, map_upstream integer, channel_width double precision, channel_width_source text, mad_m3s double precision, geom public.geometry)
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$


-- trace downstream from both locations, the portion of the
-- traces that are not common to both is the path between the points

-- return source features
WITH p1 AS (
  SELECT *
  FROM fwa_downstreamtrace($1, $2, $5)
),

p2 AS (
  SELECT *
  FROM fwa_downstreamtrace($3, $4, $5)
)

SELECT * FROM (
 
  SELECT p1.*
  FROM p1 
  LEFT JOIN p2 ON p1.linear_feature_id = p2.linear_feature_id
  WHERE p2.linear_feature_id IS NULL

  UNION ALL

  SELECT p2.*
  FROM p2 
  LEFT JOIN p1 ON p2.linear_feature_id = p1.linear_feature_id
  WHERE p1.linear_feature_id IS NULL

  UNION ALL

  -- if one point is downstream of the other, the split source stream
  -- needs to be added to the result (the linear feature id is common to both traces,
  -- so excluded above, but a portion of it needs to be included)
  SELECT
    s.linear_feature_id,
    s.edge_type,
    s.blue_line_key,
    s.watershed_key,
    s.wscode,
    s.localcode,
    s.watershed_group_code,
    least(p1.upstream_route_measure, p2.upstream_route_measure) as downstream_route_measure,
    greatest(p1.upstream_route_measure, p2.upstream_route_measure) as upstream_route_measure,
    greatest(p1.upstream_route_measure, p2.upstream_route_measure) - least(p1.upstream_route_measure, p2.upstream_route_measure) as length_metre,
    s.waterbody_key,
    s.gnis_name,
    s.stream_order,
    s.stream_magnitude,
    s.feature_code,
    s.gradient,
    s.left_right_tributary,
    s.stream_order_parent,
    s.stream_order_max,
    s.upstream_area_ha,
    s.map_upstream,
    s.channel_width,
    s.channel_width_source,
    s.mad_m3s,
    st_locatebetween(s.geom,
      least(p1.upstream_route_measure, p2.upstream_route_measure),
      greatest(p1.upstream_route_measure, p2.upstream_route_measure)
    )  as geom
  FROM p1
  INNER JOIN p2 ON p1.linear_feature_id = p2.linear_feature_id
  AND p1.upstream_route_measure != p2.upstream_route_measure
  -- join to source streams so we don't have to compare the two geoms to find the full length segment
  INNER JOIN whse_basemapping.fwa_streams s ON s.linear_feature_id = p1.linear_feature_id

) AS f
WHERE f.blue_line_key = f.watershed_key -- do not return side channels, just the network path
ORDER BY wscode DESC, localcode DESC, downstream_route_measure DESC;


$_$;


--
-- Name: FUNCTION fwa_networktrace(blue_line_key_a integer, measure_a double precision, blue_line_key_b integer, measure_b double precision, tolerance double precision); Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON FUNCTION whse_basemapping.fwa_networktrace(blue_line_key_a integer, measure_a double precision, blue_line_key_b integer, measure_b double precision, tolerance double precision) IS 'Return stream network path between the provided locations';


--
-- Name: fwa_networktraceagg(integer, double precision, integer, double precision, double precision); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_networktraceagg(blue_line_key_a integer, measure_a double precision, blue_line_key_b integer, measure_b double precision, tolerance double precision DEFAULT 1) RETURNS TABLE(id integer, from_blue_line_key integer, from_measure double precision, to_blue_line_key integer, to_measure double precision, geom public.geometry)
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$

  -- trace downstream from both locations, the portion of the
  -- traces that are not common to both is the path between the points

  WITH t1 AS (
    SELECT 1 as id, *
    FROM fwa_downstreamtrace($1, $2, $5)
    WHERE blue_line_key = watershed_key
  ),

  t2 AS (
    SELECT 2 as id, *
    FROM fwa_downstreamtrace($3, $4, $5)
    WHERE blue_line_key = watershed_key
  ),

  -- if the origins are flow-connected (ie downstream/upstream of the other),
  -- the split source stream needs to be added to the result (the linear feature id
  -- is common to both traces and excluded below, but a portion of it needs to be included)
  remainder AS (
    SELECT
      s.linear_feature_id,
      s.edge_type,
      s.blue_line_key,
      s.watershed_key,
      s.wscode,
      s.localcode,
      s.watershed_group_code,
      least(t1.upstream_route_measure, t2.upstream_route_measure) as downstream_route_measure,
      greatest(t1.upstream_route_measure, t2.upstream_route_measure) as upstream_route_measure,
      greatest(t1.upstream_route_measure, t2.upstream_route_measure) - least(t1.upstream_route_measure, t2.upstream_route_measure) as length_metre,
      s.waterbody_key,
      s.gnis_name,
      s.stream_order,
      s.stream_magnitude,
      s.feature_code,
      s.gradient,
      s.left_right_tributary,
      s.stream_order_parent,
      s.stream_order_max,
      s.upstream_area_ha,
      s.map_upstream,
      s.channel_width,
      s.channel_width_source,
      s.mad_m3s,
      st_force3d(st_locatebetween(s.geom,
        least(t1.upstream_route_measure, t2.upstream_route_measure),
        greatest(t1.upstream_route_measure, t2.upstream_route_measure)
      ))  as geom
    FROM t1
    INNER JOIN t2 ON t1.linear_feature_id = t2.linear_feature_id
    AND t1.upstream_route_measure != t2.upstream_route_measure
    -- join to source streams so we don't have to compare the two geoms to find the full length segment
    INNER JOIN whse_basemapping.fwa_streams s ON s.linear_feature_id = t1.linear_feature_id
  ),

  t1_agg AS (
    SELECT
      t1.id,
      first(t1.blue_line_key) as from_blue_line_key,
      first(t1.upstream_route_measure) as from_measure,
      last(t1.blue_line_key) as to_blue_line_key,
      last(t1.downstream_route_measure) as to_measure,
      st_linemerge(st_union(t1.geom)) as geom
    FROM t1
    LEFT JOIN t2 ON t1.linear_feature_id = t2.linear_feature_id
    WHERE t2.linear_feature_id IS NULL
    GROUP BY t1.id
  ),

  t2_agg AS (
    SELECT
      t2.id,
      first(t2.blue_line_key) as from_blue_line_key,
      first(t2.upstream_route_measure) as from_measure,
      last(t2.blue_line_key) as to_blue_line_key,
      last(t2.downstream_route_measure) as to_measure,
      st_linemerge(st_union(t2.geom)) as geom
    FROM t2
    LEFT JOIN t1 ON t2.linear_feature_id = t1.linear_feature_id
    WHERE t1.linear_feature_id IS NULL
    GROUP BY t2.id
  ),

  -- determin which trace the remainder should be aggregated with
  r_agg as (
    select
      coalesce(t1_agg.id, t2_agg.id) as id,
      r.blue_line_key as from_blue_line_key,
      r.upstream_route_measure as from_measure,
      r.blue_line_key as to_blue_line_key,
      r.downstream_route_measure as to_measure,
      r.geom
    from remainder r
    left outer join t1_agg on round(r.upstream_route_measure) = round(t1_agg.to_measure)
    left outer join t2_agg on round(r.upstream_route_measure) = round(t2_agg.to_measure)
  ),

  all_agg as (
    select * from t1_agg
    union all
    select * from t2_agg
    union all
    select * from r_agg
  )

  select
    id,
    first(from_blue_line_key) as from_blue_line_key,
    first(from_measure) as from_measure,
    last(to_blue_line_key) as to_blue_line_key,
    last(to_measure) as to_measure,
    ST_RemoveRepeatedPoints(st_linemerge(st_union(st_multi(geom), .01))) as geom
  from all_agg
  group by id

$_$;


--
-- Name: fwa_segmentalonginterval(integer, integer, integer, integer); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_segmentalonginterval(blue_line_key integer, interval_length integer DEFAULT 100, start_measure integer DEFAULT 0, end_measure integer DEFAULT NULL::integer) RETURNS TABLE(index integer, downstream_route_measure double precision, upstream_route_measure double precision, geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$

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


WITH start_pts as
(
  SELECT
    generate_series(0, v_measure_end / v_interval) as n,
    v_blkey as blue_line_key,
    generate_series(v_measure_start, v_measure_end, v_interval) as downstream_route_measure
),

intervals as (
  SELECT
    n,
    s.blue_line_key,
    s.downstream_route_measure,
    coalesce(lead(s.downstream_route_measure) OVER (ORDER BY n), v_measure_end) AS upstream_route_measure
  FROM start_pts s
)

select
  i.n::integer as index,
  i.downstream_route_measure::double precision,
  i.upstream_route_measure::double precision,
  ST_Multi(st_union(ST_LocateBetween(s.geom, i.downstream_route_measure, i.upstream_route_measure))) as geom
FROM intervals i
inner join whse_basemapping.fwa_stream_networks_sp s on s.blue_line_key = i.blue_line_key
AND s.downstream_route_measure <= i.downstream_route_measure
AND s.upstream_route_measure > i.downstream_route_measure
GROUP BY i.n, i.blue_line_key, i.downstream_route_measure, i.upstream_route_measure
ORDER BY i.n;

END;

$$;


--
-- Name: FUNCTION fwa_segmentalonginterval(blue_line_key integer, interval_length integer, start_measure integer, end_measure integer); Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON FUNCTION whse_basemapping.fwa_segmentalonginterval(blue_line_key integer, interval_length integer, start_measure integer, end_measure integer) IS 'Return a table (index, downstream_route_measure, upstream_route_measure, geom), representing segments along a stream between specified locations at specified interval';


--
-- Name: fwa_slicewatershedatpoint(integer, double precision); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_slicewatershedatpoint(blkey integer, meas double precision) RETURNS TABLE(wsds integer[], geom public.geometry)
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $$

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
    ROUND(CAST((meas - s.downstream_route_measure) / s.length_metre AS NUMERIC), 5)
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



$$;


--
-- Name: FUNCTION fwa_slicewatershedatpoint(blkey integer, meas double precision); Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON FUNCTION whse_basemapping.fwa_slicewatershedatpoint(blkey integer, meas double precision) IS 'Aggregate and slice watershed polygons on/adjacent to polygonal rivers/canals at given blue_line_key/measure. Returns the cut portion of watersheds upstream of the provided point';


--
-- Name: fwa_slopealonginterval(integer, integer, integer, integer, integer); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_slopealonginterval(blue_line_key integer, interval_length integer DEFAULT 100, distance_upstream integer DEFAULT 100, start_measure integer DEFAULT 0, end_measure integer DEFAULT NULL::integer) RETURNS TABLE(idx integer, downstream_measure numeric, downstream_z numeric, upstream_measure numeric, upstream_z numeric, gradient numeric)
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$

DECLARE

   v_blkey          integer := blue_line_key;
   v_interval       integer := interval_length;
   v_distance_upstream integer := distance_upstream;
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

-- if no end point provided, process the entire stream
IF v_measure_end IS NULL THEN
  v_measure_end := floor(v_measure_max);
END IF;

IF v_measure_end > v_measure_max THEN
  RAISE NOTICE 'Value: %', v_measure_end;
  RAISE EXCEPTION 'Input end_measure value does not exist in FWA';
END IF;

IF v_measure_end <= v_measure_start THEN
  RAISE EXCEPTION 'Input end_measure value must be more than input start_measure value';
END IF;

IF (v_measure_end - v_measure_start) < v_interval THEN
  RAISE EXCEPTION 'Distance between start_measure and end_measure is less than input interval_length';
END IF;


RETURN QUERY

with dnstr as (
  select
    index as idx,
    downstream_route_measure as dnstr_measure,
    st_z(geom) as dnstr_z
  from fwa_locatealonginterval(v_blkey, v_interval, v_measure_start, v_measure_end)
),

upstr as (
  select
    index as idx,
    downstream_route_measure as upstr_measure,
    st_z(geom) as upstr_z
  from fwa_locatealonginterval(v_blkey, v_interval, (v_measure_start + v_distance_upstream), v_measure_end)
)

select
  d.idx,
  d.dnstr_measure::numeric as downstream_route_measure,
  round(d.dnstr_z::numeric, 2) as downstream_z,
  u.upstr_measure::numeric as upstream_route_measure,
  round(u.upstr_z::numeric, 2) as upstream_z,
  round(((u.upstr_z - d.dnstr_z) / (u.upstr_measure - d.dnstr_measure))::numeric, 3) as gradient
from dnstr d
inner join upstr u on d.idx = u.idx;

END;

$$;


--
-- Name: FUNCTION fwa_slopealonginterval(blue_line_key integer, interval_length integer, distance_upstream integer, start_measure integer, end_measure integer); Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON FUNCTION whse_basemapping.fwa_slopealonginterval(blue_line_key integer, interval_length integer, distance_upstream integer, start_measure integer, end_measure integer) IS 'Return a table (n, downstream_route_measure, downstream_z, upstream_route_measure, upstream_z, gradient), measuring slope at equal intervals';


--
-- Name: fwa_upstream(public.ltree, public.ltree, public.ltree, public.ltree); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_upstream(wscode_ltree_a public.ltree, localcode_ltree_a public.ltree, wscode_ltree_b public.ltree, localcode_ltree_b public.ltree) RETURNS boolean
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$

SELECT
  -- Simple case, where watershed code and local code of (a) are equivalent.
  -- Return TRUE for all records in (b) that are children of (a)
    (wscode_ltree_a = localcode_ltree_a AND
    wscode_ltree_b <@ wscode_ltree_a AND
    localcode_ltree_b <@ localcode_ltree_a) -- checking local codes is redundant but this ensures invalid local codes are not matched

  -- Where watershed code and local code of (a) are not equivalent and wsc of b is child of wsc a,
  -- more comparison is required - the local codes must be compared.
  OR
    (
      wscode_ltree_a != localcode_ltree_a AND
      wscode_ltree_b <@ wscode_ltree_a AND
      (
       -- tributaries:
       --   - wsc of b is bigger than local code of a - the trib is upstream
       --   - wsc of b is not a child of local code a - exclude trib at the same position
       --   - local code b is child of wsc a (this should be true anyway but a check handles invalid codes)
          (wscode_ltree_b > localcode_ltree_a AND NOT
           wscode_ltree_b <@ localcode_ltree_a AND
           localcode_ltree_b <@ wscode_ltree_a AND
           localcode_ltree_b > localcode_ltree_a
      )
          OR
       -- side channels (higher up on the same stream)
       --
       --   - wsc of b is the same as wsc of a
       --   - local code b is larger than local code of a
          (
            wscode_ltree_b = wscode_ltree_a AND
            localcode_ltree_b >= localcode_ltree_a
          )

      )
  )

$$;


--
-- Name: fwa_upstream(integer, double precision, public.ltree, public.ltree, integer, double precision, public.ltree, public.ltree, boolean, double precision); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_upstream(blue_line_key_a integer, downstream_route_measure_a double precision, wscode_ltree_a public.ltree, localcode_ltree_a public.ltree, blue_line_key_b integer, downstream_route_measure_b double precision, wscode_ltree_b public.ltree, localcode_ltree_b public.ltree, include_equivalents boolean DEFAULT false, tolerance double precision DEFAULT 0.001) RETURNS boolean
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$

SELECT
  whse_basemapping.FWA_Upstream(
    blue_line_key_a,
    downstream_route_measure_a,
    downstream_route_measure_a,
    wscode_ltree_a,
    localcode_ltree_a,
    blue_line_key_b,
    downstream_route_measure_b,
    wscode_ltree_b,
    localcode_ltree_b,
    include_equivalents,
    tolerance
  )
$$;


--
-- Name: fwa_upstream(integer, double precision, double precision, public.ltree, public.ltree, integer, double precision, public.ltree, public.ltree, boolean, double precision); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_upstream(blue_line_key_a integer, downstream_route_measure_a double precision, upstream_route_measure_a double precision, wscode_ltree_a public.ltree, localcode_ltree_a public.ltree, blue_line_key_b integer, downstream_route_measure_b double precision, wscode_ltree_b public.ltree, localcode_ltree_b public.ltree, include_equivalents boolean DEFAULT false, tolerance double precision DEFAULT 0.001) RETURNS boolean
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$


SELECT
  -- b is a child of a, always
  wscode_ltree_b <@ wscode_ltree_a AND

    -- conditional upstream join logic, based on whether watershed codes are equivalent
  (
    CASE
       -- first, consider simple case - streams where wscode and localcode are equivalent
       WHEN include_equivalents IS False AND
          wscode_ltree_a = localcode_ltree_a AND
          (
              -- upstream tribs
              (blue_line_key_b != blue_line_key_a) OR

              -- on same blue line
              (blue_line_key_b = blue_line_key_a AND
               downstream_route_measure_b >= upstream_route_measure_a + tolerance)
          )
          -- exclude distributaries with equivalent codes and different blkeys
          AND NOT (
            wscode_ltree_a = wscode_ltree_b AND
            localcode_ltree_a = localcode_ltree_b AND
            blue_line_key_a != blue_line_key_b
          )
       THEN TRUE

       -- next, the more complicated case - where wscode and localcode are not equal
       WHEN include_equivalents IS False AND
         wscode_ltree_a != localcode_ltree_a AND
          (
                -- on same blue line
              (blue_line_key_b = blue_line_key_a AND
               downstream_route_measure_b >= upstream_route_measure_a + tolerance)
              OR
              -- tributaries: b wscode > a localcode and b wscode is not a child of a localcode
              (wscode_ltree_b > localcode_ltree_a AND
               NOT wscode_ltree_b <@ localcode_ltree_a)
              OR
              -- capture side channels: b is the same watershed code, with larger localcode
              (wscode_ltree_b = wscode_ltree_a
               AND localcode_ltree_b > localcode_ltree_a)
          )
        THEN TRUE

      -- run the same process, but return true for locations at the same measure
      -- (within tolerance)
       WHEN include_equivalents IS True AND
          wscode_ltree_a = localcode_ltree_a AND
          (
              -- upstream tribs
              (blue_line_key_b != blue_line_key_a) OR

              -- on same blue line
              (blue_line_key_b = blue_line_key_a AND
               (downstream_route_measure_b > upstream_route_measure_a OR
                abs(upstream_route_measure_a - downstream_route_measure_b) <= tolerance)
              )
          )
          -- exclude distributaries with equivalent codes and different blkeys
          AND NOT (
            wscode_ltree_a = wscode_ltree_b AND
            localcode_ltree_a = localcode_ltree_b AND
            blue_line_key_a != blue_line_key_b
          )
       THEN TRUE

       -- next, the more complicated case - where wscode and localcode are not equal
       WHEN include_equivalents IS True AND
         wscode_ltree_a != localcode_ltree_a AND
          (
              -- on same blue line
              (blue_line_key_b = blue_line_key_a AND
               (downstream_route_measure_b > upstream_route_measure_a OR
                abs(upstream_route_measure_a - downstream_route_measure_b) <= tolerance)
              )
              OR
              -- tributaries: b wscode > a localcode and b wscode is not a child of a localcode
              (wscode_ltree_b > localcode_ltree_a AND
               NOT wscode_ltree_b <@ localcode_ltree_a)
              OR
              -- capture side channels: b is the same watershed code, with larger localcode
              (wscode_ltree_b = wscode_ltree_a
               AND localcode_ltree_b > localcode_ltree_a)
          )
        THEN TRUE

        ELSE FALSE
    END
  )
$$;


--
-- Name: fwa_upstreambordercrossings(integer, double precision); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_upstreambordercrossings(blkey integer, meas double precision) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $$

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
                     ((meas - s.downstream_route_measure) / s.length_metre),
                     1)
                     )
    ) AS geom
  FROM whse_basemapping.fwa_stream_networks_sp s
  WHERE s.blue_line_key = blkey
  AND s.downstream_route_measure <= meas + .01
  AND s.upstream_route_measure > meas
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


$$;


--
-- Name: FUNCTION fwa_upstreambordercrossings(blkey integer, meas double precision); Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON FUNCTION whse_basemapping.fwa_upstreambordercrossings(blkey integer, meas double precision) IS 'Provided a location as blue_line_key and downstream_route_measure, return border name if any streams upstream of the location intersect parallels 49/60 or longitude -120 ';


--
-- Name: fwa_upstreamtrace(integer, double precision, double precision); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_upstreamtrace(start_blue_line_key integer, start_measure double precision, tolerance double precision DEFAULT 1) RETURNS TABLE(linear_feature_id bigint, edge_type integer, blue_line_key integer, watershed_key integer, wscode public.ltree, localcode public.ltree, watershed_group_code character varying, downstream_route_measure double precision, upstream_route_measure double precision, length_metre double precision, waterbody_key integer, gnis_name character varying, stream_order integer, stream_magnitude integer, feature_code character varying, gradient double precision, left_right_tributary character varying, stream_order_parent integer, stream_order_max integer, upstream_area_ha double precision, map_upstream integer, channel_width double precision, channel_width_source text, mad_m3s double precision, geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
    AS $$

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
  AND round(s.upstream_route_measure::numeric, 4) > round(v_measure::numeric, 4)
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

$$;


--
-- Name: FUNCTION fwa_upstreamtrace(start_blue_line_key integer, start_measure double precision, tolerance double precision); Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON FUNCTION whse_basemapping.fwa_upstreamtrace(start_blue_line_key integer, start_measure double precision, tolerance double precision) IS 'Return stream network upstream of provided location';


--
-- Name: fwa_watershedatmeasure(integer, double precision); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_watershedatmeasure(blue_line_key integer, downstream_route_measure double precision) RETURNS TABLE(wscode_ltree text, localcode_ltree text, area_ha numeric, refine_method text, geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
    AS $$

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
$$;


--
-- Name: FUNCTION fwa_watershedatmeasure(blue_line_key integer, downstream_route_measure double precision); Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON FUNCTION whse_basemapping.fwa_watershedatmeasure(blue_line_key integer, downstream_route_measure double precision) IS 'Provided a location as blue_line_key and downstream_route_measure, return the entire watershed boundary upstream of the location';


--
-- Name: fwa_watershedhex(integer, double precision); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_watershedhex(blue_line_key integer, downstream_route_measure double precision) RETURNS TABLE(hex_id bigint, geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$

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
$$;


--
-- Name: FUNCTION fwa_watershedhex(blue_line_key integer, downstream_route_measure double precision); Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON FUNCTION whse_basemapping.fwa_watershedhex(blue_line_key integer, downstream_route_measure double precision) IS 'Provided a location as blue_line_key and downstream_route_measure, return a 25m hexagon grid covering first order watershed in which location lies';


--
-- Name: fwa_watershedstream(integer, double precision); Type: FUNCTION; Schema: whse_basemapping; Owner: -
--

CREATE FUNCTION whse_basemapping.fwa_watershedstream(blue_line_key integer, downstream_route_measure double precision) RETURNS TABLE(linear_feature_id bigint, geom public.geometry)
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$

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

$$;


--
-- Name: FUNCTION fwa_watershedstream(blue_line_key integer, downstream_route_measure double precision); Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON FUNCTION whse_basemapping.fwa_watershedstream(blue_line_key integer, downstream_route_measure double precision) IS 'Provided a location as blue_line_key and downstream_route_measure, return stream segments upstream, within the same first order watershed.';


--
-- Name: first(anyelement); Type: AGGREGATE; Schema: public; Owner: -
--

CREATE AGGREGATE public.first(anyelement) (
    SFUNC = public.first_agg,
    STYPE = anyelement,
    PARALLEL = safe
);


--
-- Name: last(anyelement); Type: AGGREGATE; Schema: public; Owner: -
--

CREATE AGGREGATE public.last(anyelement) (
    SFUNC = public.last_agg,
    STYPE = anyelement
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: hybas_lev12_v1c; Type: TABLE; Schema: hydrosheds; Owner: -
--

CREATE TABLE hydrosheds.hybas_lev12_v1c (
    hybas_id bigint NOT NULL,
    next_down numeric(11,0),
    geom public.geometry(MultiPolygon,3005)
);


--
-- Name: TABLE hybas_lev12_v1c; Type: COMMENT; Schema: hydrosheds; Owner: -
--

COMMENT ON TABLE hydrosheds.hybas_lev12_v1c IS 'HydroBasins for North America from https://www.hydrosheds.org. See source for column documentation';


--
-- Name: wbdhu12; Type: TABLE; Schema: usgs; Owner: -
--

CREATE TABLE usgs.wbdhu12 (
    tnmid character varying(40),
    metasourceid character varying(40),
    sourcedatadesc character varying(100),
    sourceoriginator character varying(130),
    sourcefeatureid character varying(40),
    loaddate timestamp with time zone,
    referencegnis_ids character varying(50),
    areaacres double precision,
    areasqkm double precision,
    states character varying(50),
    huc12 character varying(12) NOT NULL,
    name character varying(120),
    hutype character varying(1),
    humod character varying(30),
    tohuc character varying(16),
    noncontributingareaacres double precision,
    noncontributingareasqkm double precision,
    globalid character varying,
    shape_length double precision,
    shape_area double precision,
    geom public.geometry(MultiPolygon,3005)
);


--
-- Name: TABLE wbdhu12; Type: COMMENT; Schema: usgs; Owner: -
--

COMMENT ON TABLE usgs.wbdhu12 IS 'USGS National Watershed Boundary Dataset, HUC12 level. See https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.xml';


--
-- Name: fwa_approx_borders; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_approx_borders (
    approx_border_id integer NOT NULL,
    border text,
    geom public.geometry(LineString,3005)
);


--
-- Name: TABLE fwa_approx_borders; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON TABLE whse_basemapping.fwa_approx_borders IS 'lines of latitude / longitude for 49n, 60n, -120w. these are used by fwapg for finding cross-border streams';


--
-- Name: COLUMN fwa_approx_borders.approx_border_id; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_approx_borders.approx_border_id IS 'unique identifer';


--
-- Name: COLUMN fwa_approx_borders.border; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_approx_borders.border IS 'a code identifying the border (usa49, ytnwt_60, ab_120)';


--
-- Name: COLUMN fwa_approx_borders.geom; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_approx_borders.geom IS 'geometry of the border line';


--
-- Name: fwa_approx_borders_approx_border_id_seq; Type: SEQUENCE; Schema: whse_basemapping; Owner: -
--

CREATE SEQUENCE whse_basemapping.fwa_approx_borders_approx_border_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fwa_approx_borders_approx_border_id_seq; Type: SEQUENCE OWNED BY; Schema: whse_basemapping; Owner: -
--

ALTER SEQUENCE whse_basemapping.fwa_approx_borders_approx_border_id_seq OWNED BY whse_basemapping.fwa_approx_borders.approx_border_id;


--
-- Name: fwa_assessment_watersheds_lut; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_assessment_watersheds_lut (
    watershed_feature_id integer NOT NULL,
    assmnt_watershed_id integer
);


--
-- Name: fwa_assessment_watersheds_poly; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_assessment_watersheds_poly (
    watershed_feature_id integer NOT NULL,
    watershed_group_id integer,
    watershed_type character varying(1),
    gnis_id_1 integer,
    gnis_name_1 character varying(80),
    gnis_id_2 integer,
    gnis_name_2 character varying(80),
    gnis_id_3 integer,
    gnis_name_3 character varying(80),
    waterbody_id bigint,
    waterbody_key bigint,
    watershed_key bigint,
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    watershed_group_code character varying(4),
    left_right_tributary character varying(7),
    watershed_order integer,
    watershed_magnitude integer,
    local_watershed_order integer,
    local_watershed_magnitude integer,
    area_ha double precision,
    feature_code character varying(10),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    geom public.geometry(MultiPolygon,3005)
);


--
-- Name: fwa_assessment_watersheds_streams_lut; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_assessment_watersheds_streams_lut (
    linear_feature_id integer NOT NULL,
    assmnt_watershed_id integer
);


--
-- Name: fwa_basins_poly; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_basins_poly (
    basin_id integer NOT NULL,
    basin_name text,
    wscode_ltree public.ltree,
    localcode_ltree public.ltree,
    geom public.geometry(Polygon,3005)
);


--
-- Name: TABLE fwa_basins_poly; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON TABLE whse_basemapping.fwa_basins_poly IS 'Large BC waterhseds consisting of at least 2-3 watershed groups, used by fwapg for watershed pre-aggregation';


--
-- Name: COLUMN fwa_basins_poly.basin_id; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_basins_poly.basin_id IS 'Basin unique identifier';


--
-- Name: COLUMN fwa_basins_poly.basin_name; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_basins_poly.basin_name IS 'Basin name, eg Thompson River';


--
-- Name: COLUMN fwa_basins_poly.wscode_ltree; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_basins_poly.wscode_ltree IS 'The watershed code associated with the stream at the outlet of the basin';


--
-- Name: COLUMN fwa_basins_poly.localcode_ltree; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_basins_poly.localcode_ltree IS 'The local watershed code associated with the stream at the outlet of the basin';


--
-- Name: COLUMN fwa_basins_poly.geom; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_basins_poly.geom IS 'Geometry of the basin';


--
-- Name: fwa_bays_and_channels_poly; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_bays_and_channels_poly (
    bay_and_channel_id integer NOT NULL,
    bay_channel_type character varying(14),
    gnis_id integer,
    gnis_name character varying(80),
    area_ha double precision,
    feature_code character varying(10),
    geom public.geometry(MultiPolygon,3005)
);


--
-- Name: fwa_bcboundary; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_bcboundary (
    bcboundary_id integer NOT NULL,
    geom public.geometry(Polygon,3005)
);


--
-- Name: TABLE fwa_bcboundary; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON TABLE whse_basemapping.fwa_bcboundary IS 'Boundary of BC as defined by FWA - used by FWA_WatershedAtMeasure()';


--
-- Name: COLUMN fwa_bcboundary.bcboundary_id; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_bcboundary.bcboundary_id IS 'Boundary polygon id';


--
-- Name: COLUMN fwa_bcboundary.geom; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_bcboundary.geom IS 'Boundary geometry';


--
-- Name: fwa_bcboundary_bcboundary_id_seq; Type: SEQUENCE; Schema: whse_basemapping; Owner: -
--

CREATE SEQUENCE whse_basemapping.fwa_bcboundary_bcboundary_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fwa_bcboundary_bcboundary_id_seq; Type: SEQUENCE OWNED BY; Schema: whse_basemapping; Owner: -
--

ALTER SEQUENCE whse_basemapping.fwa_bcboundary_bcboundary_id_seq OWNED BY whse_basemapping.fwa_bcboundary.bcboundary_id;


--
-- Name: fwa_coastlines_sp; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_coastlines_sp (
    linear_feature_id integer NOT NULL,
    watershed_group_id integer,
    edge_type integer,
    blue_line_key integer,
    watershed_key integer,
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    watershed_group_code character varying(4),
    downstream_route_measure double precision,
    length_metre double precision,
    feature_source character varying(15),
    feature_code character varying(10),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    geom public.geometry(LineString,3005)
);


--
-- Name: fwa_edge_type_codes; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_edge_type_codes (
    edge_type bigint,
    edge_description character varying(100)
);


--
-- Name: fwa_glaciers_poly; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_glaciers_poly (
    waterbody_poly_id integer NOT NULL,
    watershed_group_id integer,
    waterbody_type character varying(1),
    waterbody_key integer,
    area_ha double precision,
    gnis_id_1 integer,
    gnis_name_1 character varying(80),
    gnis_id_2 integer,
    gnis_name_2 character varying(80),
    gnis_id_3 integer,
    gnis_name_3 character varying(80),
    blue_line_key integer,
    watershed_key integer,
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    watershed_group_code character varying(4),
    left_right_tributary character varying(7),
    waterbody_key_50k integer,
    watershed_group_code_50k character varying(4),
    waterbody_key_group_code_50k character varying(55),
    watershed_code_50k character varying(45),
    feature_code character varying(10),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    geom public.geometry(MultiPolygon,3005)
);


--
-- Name: fwa_islands_poly; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_islands_poly (
    island_id integer NOT NULL,
    island_type character varying(12),
    gnis_id_1 integer,
    gnis_name_1 character varying(80),
    gnis_id_2 integer,
    gnis_name_2 character varying(80),
    gnis_id_3 integer,
    gnis_name_3 character varying(80),
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    area_ha double precision,
    feature_code character varying(10),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    geom public.geometry(MultiPolygon,3005)
);


--
-- Name: fwa_lakes_poly; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_lakes_poly (
    waterbody_poly_id integer NOT NULL,
    watershed_group_id integer,
    waterbody_type character varying(1),
    waterbody_key integer,
    area_ha double precision,
    gnis_id_1 integer,
    gnis_name_1 character varying(80),
    gnis_id_2 integer,
    gnis_name_2 character varying(80),
    gnis_id_3 integer,
    gnis_name_3 character varying(80),
    blue_line_key integer,
    watershed_key integer,
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    watershed_group_code character varying(4),
    left_right_tributary character varying(7),
    waterbody_key_50k integer,
    watershed_group_code_50k character varying(4),
    waterbody_key_group_code_50k character varying(55),
    watershed_code_50k character varying(45),
    feature_code character varying(10),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    geom public.geometry(MultiPolygon,3005)
);


--
-- Name: fwa_linear_boundaries_sp; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_linear_boundaries_sp (
    linear_feature_id integer NOT NULL,
    watershed_group_id integer NOT NULL,
    edge_type integer,
    waterbody_key integer,
    blue_line_key integer,
    watershed_key integer,
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    watershed_group_code character varying(4),
    downstream_route_measure double precision,
    length_metre double precision,
    feature_source character varying,
    feature_code character varying(10),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    geom public.geometry(MultiLineString,3005)
);


--
-- Name: fwa_manmade_waterbodies_poly; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_manmade_waterbodies_poly (
    waterbody_poly_id integer NOT NULL,
    watershed_group_id integer,
    waterbody_type character varying(1),
    waterbody_key integer,
    area_ha double precision,
    gnis_id_1 integer,
    gnis_name_1 character varying(80),
    gnis_id_2 integer,
    gnis_name_2 character varying(80),
    gnis_id_3 integer,
    gnis_name_3 character varying(80),
    blue_line_key integer,
    watershed_key integer,
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    watershed_group_code character varying(4),
    left_right_tributary character varying(7),
    waterbody_key_50k integer,
    watershed_group_code_50k character varying(4),
    waterbody_key_group_code_50k character varying(55),
    watershed_code_50k character varying(45),
    feature_code character varying(10),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    geom public.geometry(MultiPolygon,3005)
);


--
-- Name: fwa_named_point_features_sp; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_named_point_features_sp (
    named_point_feature_id integer NOT NULL,
    gnis_id integer,
    gnis_name character varying(80),
    named_feature_type character varying(6),
    feature_code character varying(10),
    geom public.geometry(Point,3005)
);


--
-- Name: fwa_named_streams; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_named_streams (
    named_streams_id integer NOT NULL,
    gnis_name text,
    blue_line_key bigint,
    stream_order integer,
    watershed_group_code text,
    geom public.geometry(MultiLineString,3005)
);


--
-- Name: TABLE fwa_named_streams; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON TABLE whse_basemapping.fwa_named_streams IS 'Named streams of BC, aggregated per watershed group and simplified using a 25m tolerance (primarily for mapping use)';


--
-- Name: COLUMN fwa_named_streams.named_streams_id; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_named_streams.named_streams_id IS 'Named stream unique identifier';


--
-- Name: COLUMN fwa_named_streams.gnis_name; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_named_streams.gnis_name IS 'The BCGNIS (BC Geographical Names Information System) name associated with the stream';


--
-- Name: COLUMN fwa_named_streams.blue_line_key; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_named_streams.blue_line_key IS 'The blue line key of the named stream, see FWA documentation for blue_line_key description';


--
-- Name: COLUMN fwa_named_streams.stream_order; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_named_streams.stream_order IS 'The maximum stream order associated with the stream name';


--
-- Name: COLUMN fwa_named_streams.watershed_group_code; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_named_streams.watershed_group_code IS 'The watershed group code associated with the named stream';


--
-- Name: COLUMN fwa_named_streams.geom; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_named_streams.geom IS 'The geometry of the named stream, an aggregation of the source features and simpified by 25m';


--
-- Name: fwa_named_streams_named_streams_id_seq; Type: SEQUENCE; Schema: whse_basemapping; Owner: -
--

CREATE SEQUENCE whse_basemapping.fwa_named_streams_named_streams_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fwa_named_streams_named_streams_id_seq; Type: SEQUENCE OWNED BY; Schema: whse_basemapping; Owner: -
--

ALTER SEQUENCE whse_basemapping.fwa_named_streams_named_streams_id_seq OWNED BY whse_basemapping.fwa_named_streams.named_streams_id;


--
-- Name: fwa_named_watersheds_poly; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_named_watersheds_poly (
    named_watershed_id integer NOT NULL,
    gnis_id integer,
    gnis_name character varying(80),
    blue_line_key integer,
    watershed_key integer,
    fwa_watershed_code character varying(143),
    stream_order integer,
    stream_magnitude integer,
    area_ha double precision,
    feature_code character varying(10),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    geom public.geometry(MultiPolygon,3005)
);


--
-- Name: fwa_obstructions_sp; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_obstructions_sp (
    obstruction_id integer NOT NULL,
    watershed_group_id integer,
    linear_feature_id integer,
    gnis_id integer,
    gnis_name character varying(80),
    obstruction_type character varying(20),
    blue_line_key integer,
    watershed_key integer,
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    watershed_group_code character varying(4),
    route_measure double precision,
    feature_source character varying(15),
    feature_code character varying(10),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    geom public.geometry(Point,3005)
);


--
-- Name: fwa_rivers_poly; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_rivers_poly (
    waterbody_poly_id integer NOT NULL,
    watershed_group_id integer,
    waterbody_type character varying(1),
    waterbody_key integer,
    area_ha double precision,
    gnis_id_1 integer,
    gnis_name_1 character varying(80),
    gnis_id_2 integer,
    gnis_name_2 character varying(80),
    gnis_id_3 integer,
    gnis_name_3 character varying(80),
    blue_line_key integer,
    watershed_key integer,
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    watershed_group_code character varying(4),
    left_right_tributary character varying(7),
    waterbody_key_50k integer,
    watershed_group_code_50k character varying(4),
    waterbody_key_group_code_50k character varying(55),
    watershed_code_50k character varying(45),
    feature_code character varying(10),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    geom public.geometry(MultiPolygon,3005)
);


--
-- Name: fwa_stream_networks_channel_width; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_stream_networks_channel_width (
    linear_feature_id bigint NOT NULL,
    channel_width_source text,
    channel_width double precision
);


--
-- Name: fwa_stream_networks_discharge; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_stream_networks_discharge (
    linear_feature_id integer NOT NULL,
    watershed_group_code text,
    mad_mm double precision,
    mad_m3s double precision
);


--
-- Name: fwa_stream_networks_mean_annual_precip; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_stream_networks_mean_annual_precip (
    id integer NOT NULL,
    wscode_ltree public.ltree,
    localcode_ltree public.ltree,
    watershed_group_code text,
    area bigint,
    map integer,
    map_upstream integer
);


--
-- Name: fwa_stream_networks_mean_annual_precip_id_seq; Type: SEQUENCE; Schema: whse_basemapping; Owner: -
--

CREATE SEQUENCE whse_basemapping.fwa_stream_networks_mean_annual_precip_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fwa_stream_networks_mean_annual_precip_id_seq; Type: SEQUENCE OWNED BY; Schema: whse_basemapping; Owner: -
--

ALTER SEQUENCE whse_basemapping.fwa_stream_networks_mean_annual_precip_id_seq OWNED BY whse_basemapping.fwa_stream_networks_mean_annual_precip.id;


--
-- Name: fwa_stream_networks_order_max; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_stream_networks_order_max (
    blue_line_key integer NOT NULL,
    stream_order_max integer
);


--
-- Name: fwa_stream_networks_order_parent; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_stream_networks_order_parent (
    blue_line_key integer NOT NULL,
    stream_order_parent integer
);


--
-- Name: fwa_stream_networks_sp; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_stream_networks_sp (
    linear_feature_id bigint NOT NULL,
    watershed_group_id integer NOT NULL,
    edge_type integer NOT NULL,
    blue_line_key integer NOT NULL,
    watershed_key integer NOT NULL,
    fwa_watershed_code character varying(143) NOT NULL,
    local_watershed_code character varying(143),
    watershed_group_code character varying(4) NOT NULL,
    downstream_route_measure double precision NOT NULL,
    length_metre double precision NOT NULL,
    feature_source character varying(15),
    gnis_id integer,
    gnis_name character varying(80),
    left_right_tributary character varying(7),
    stream_order integer,
    stream_magnitude integer,
    waterbody_key integer,
    blue_line_key_50k integer,
    watershed_code_50k character varying(45),
    watershed_key_50k integer,
    watershed_group_code_50k character varying(4),
    gradient double precision GENERATED ALWAYS AS (round((((public.st_z(public.st_pointn(geom, '-1'::integer)) - public.st_z(public.st_pointn(geom, 1))) / public.st_length(geom)))::numeric, 4)) STORED,
    feature_code character varying(10),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    upstream_route_measure double precision GENERATED ALWAYS AS ((downstream_route_measure + public.st_length(geom))) STORED,
    geom public.geometry(LineStringZM,3005)
);


--
-- Name: fwa_streams; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_streams (
    linear_feature_id bigint NOT NULL,
    edge_type integer,
    blue_line_key integer,
    watershed_key integer,
    wscode public.ltree,
    localcode public.ltree,
    watershed_group_code character varying(4),
    downstream_route_measure double precision,
    upstream_route_measure double precision,
    length_metre double precision,
    waterbody_key integer,
    gnis_name character varying(80),
    stream_order integer,
    stream_magnitude integer,
    feature_code character varying(10),
    gradient double precision,
    left_right_tributary character varying(7),
    stream_order_parent integer,
    stream_order_max integer,
    upstream_area_ha double precision,
    map_upstream integer,
    channel_width double precision,
    channel_width_source text,
    mad_m3s double precision,
    geom public.geometry(LineStringZM,3005)
);


--
-- Name: TABLE fwa_streams; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON TABLE whse_basemapping.fwa_streams IS 'FWA stream networks and value-added attributes';


--
-- Name: COLUMN fwa_streams.linear_feature_id; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.linear_feature_id IS 'See FWA documentation';


--
-- Name: COLUMN fwa_streams.edge_type; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.edge_type IS 'See FWA documentation';


--
-- Name: COLUMN fwa_streams.blue_line_key; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.blue_line_key IS 'See FWA documentation';


--
-- Name: COLUMN fwa_streams.watershed_key; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.watershed_key IS 'See FWA documentation';


--
-- Name: COLUMN fwa_streams.wscode; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.wscode IS 'FWA watershed code as postgres ltree type, with trailing -000000 strings removed';


--
-- Name: COLUMN fwa_streams.localcode; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.localcode IS 'FWA local watershed code as postgres ltree type, with trailing -000000 strings removed';


--
-- Name: COLUMN fwa_streams.watershed_group_code; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.watershed_group_code IS 'See FWA documentation';


--
-- Name: COLUMN fwa_streams.downstream_route_measure; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.downstream_route_measure IS 'See FWA documentation';


--
-- Name: COLUMN fwa_streams.upstream_route_measure; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.upstream_route_measure IS 'See FWA documentation';


--
-- Name: COLUMN fwa_streams.length_metre; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.length_metre IS 'See FWA documentation';


--
-- Name: COLUMN fwa_streams.waterbody_key; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.waterbody_key IS 'See FWA documentation';


--
-- Name: COLUMN fwa_streams.gnis_name; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.gnis_name IS 'See FWA documentation';


--
-- Name: COLUMN fwa_streams.stream_order; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.stream_order IS 'See FWA documentation';


--
-- Name: COLUMN fwa_streams.stream_magnitude; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.stream_magnitude IS 'See FWA documentation';


--
-- Name: COLUMN fwa_streams.feature_code; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.feature_code IS 'See FWA documentation';


--
-- Name: COLUMN fwa_streams.gradient; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.gradient IS 'See FWA documentation';


--
-- Name: COLUMN fwa_streams.left_right_tributary; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.left_right_tributary IS 'See FWA documentation';


--
-- Name: COLUMN fwa_streams.stream_order_parent; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.stream_order_parent IS 'Stream order of parent stream at confluence with stream having `blue_line_key` of the stream segment';


--
-- Name: COLUMN fwa_streams.stream_order_max; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.stream_order_max IS 'Maxiumum order of the stream with equivalent `blue_line_key` as given segment)';


--
-- Name: COLUMN fwa_streams.upstream_area_ha; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.upstream_area_ha IS 'Area (ha) upstream of the stream segment (including all fundamental watersheds with equivalent watershed code)';


--
-- Name: COLUMN fwa_streams.map_upstream; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.map_upstream IS 'Area weighted average mean annual precipitation upstream of the stream segment, source ClimateBC';


--
-- Name: COLUMN fwa_streams.channel_width; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.channel_width IS 'Channel width of the stream segment in metres, with source as per channel_width_source';


--
-- Name: COLUMN fwa_streams.channel_width_source; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.channel_width_source IS 'Data source for channel_width at given segment, with values (FIELD_MEASURMENT, FWA_RIVERS_POLY, MODELLED). FIELD_MEASUREMENT is derived from PSCIS and FISS data, MODELLED is taken from Thorley et al, 2021';


--
-- Name: COLUMN fwa_streams.mad_m3s; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams.mad_m3s IS 'Modelled mean annual discharge at the stream segment (Pacific Climate Impacts Consortium, University of Victoria, (January 2020) VIC-GL BCCAQ CMIP5: Gridded Hydrologic Model Output)';


--
-- Name: fwa_streams_20k_50k; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_streams_20k_50k (
    stream_20k_50k_id bigint NOT NULL,
    watershed_group_id_20k integer,
    linear_feature_id_20k bigint,
    blue_line_key_20k integer,
    watershed_key_20k integer,
    fwa_watershed_code_20k character varying(143),
    watershed_group_code_20k character varying(4),
    blue_line_key_50k integer,
    watershed_key_50k integer,
    watershed_code_50k character varying(45),
    watershed_group_code_50k character varying(4),
    match_type character varying(7)
);


--
-- Name: fwa_streams_pse_conservation_units_lut; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_streams_pse_conservation_units_lut (
    linear_feature_id bigint,
    cuid integer
);


--
-- Name: fwa_streams_watersheds_lut; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_streams_watersheds_lut (
    linear_feature_id bigint NOT NULL,
    watershed_feature_id integer
);


--
-- Name: TABLE fwa_streams_watersheds_lut; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON TABLE whse_basemapping.fwa_streams_watersheds_lut IS 'A convenience lookup for quickly relating streams and fundamental watersheds';


--
-- Name: COLUMN fwa_streams_watersheds_lut.linear_feature_id; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams_watersheds_lut.linear_feature_id IS 'FWA stream segment unique identifier';


--
-- Name: COLUMN fwa_streams_watersheds_lut.watershed_feature_id; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON COLUMN whse_basemapping.fwa_streams_watersheds_lut.watershed_feature_id IS 'FWA fundamental watershed unique identifer';


--
-- Name: fwa_waterbodies; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_waterbodies (
    waterbody_key integer NOT NULL,
    waterbody_type character varying(1),
    blue_line_key integer,
    downstream_route_measure double precision,
    wscode_ltree public.ltree,
    localcode_ltree public.ltree
);


--
-- Name: TABLE fwa_waterbodies; Type: COMMENT; Schema: whse_basemapping; Owner: -
--

COMMENT ON TABLE whse_basemapping.fwa_waterbodies IS 'All FWA waterbodies in one table for convenience (lakes, wetlands, rivers, manmade waterbodies, glaciers). See FWA docs for column descriptions.';


--
-- Name: fwa_waterbodies_20k_50k; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_waterbodies_20k_50k (
    waterbody_20k_50k_id integer NOT NULL,
    watershed_group_id_20k integer,
    waterbody_type_20k character varying(1),
    waterbody_poly_id_20k integer,
    waterbody_key_20k integer,
    fwa_watershed_code_20k character varying(143),
    local_watershed_code_20k character varying(143),
    watershed_group_code_20k character varying(4),
    waterbody_type_50k character varying(1),
    waterbody_key_50k integer,
    watershed_group_code_50k character varying(4),
    watershed_code_50k character varying(45),
    match_type character varying(7)
);


--
-- Name: fwa_waterbodies_upstream_area; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_waterbodies_upstream_area (
    linear_feature_id bigint NOT NULL,
    upstream_lake_ha double precision,
    upstream_reservoir_ha double precision,
    upstream_wetland_ha double precision
);


--
-- Name: fwa_waterbody_type_codes; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_waterbody_type_codes (
    waterbody_type character varying(1),
    waterbody_description character varying(180)
);


--
-- Name: fwa_watershed_groups_poly; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_watershed_groups_poly (
    watershed_group_id integer NOT NULL,
    watershed_group_code character varying(4),
    watershed_group_name character varying(80),
    area_ha double precision,
    feature_code character varying(10),
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    basin_id integer,
    geom public.geometry(MultiPolygon,3005)
);


--
-- Name: fwa_watershed_type_codes; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_watershed_type_codes (
    watershed_type character varying(1),
    watershed_description character varying(255)
);


--
-- Name: fwa_watersheds_poly; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_watersheds_poly (
    watershed_feature_id integer NOT NULL,
    watershed_group_id integer NOT NULL,
    watershed_type character varying(1),
    gnis_id_1 integer,
    gnis_name_1 character varying(80),
    gnis_id_2 integer,
    gnis_name_2 character varying(80),
    gnis_id_3 integer,
    gnis_name_3 character varying(80),
    waterbody_id integer,
    waterbody_key integer,
    watershed_key integer NOT NULL,
    fwa_watershed_code character varying(143) NOT NULL,
    local_watershed_code character varying(143) NOT NULL,
    watershed_group_code character varying(4) NOT NULL,
    left_right_tributary character varying(7),
    watershed_order integer,
    watershed_magnitude integer,
    local_watershed_order integer,
    local_watershed_magnitude integer,
    area_ha double precision,
    river_area double precision,
    lake_area double precision,
    wetland_area double precision,
    manmade_area double precision,
    glacier_area double precision,
    average_elevation double precision,
    average_slope double precision,
    aspect_north double precision,
    aspect_south double precision,
    aspect_west double precision,
    aspect_east double precision,
    aspect_flat double precision,
    feature_code character varying(10),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    geom public.geometry(MultiPolygon,3005)
);


--
-- Name: fwa_watersheds_upstream_area; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_watersheds_upstream_area (
    watershed_feature_id integer NOT NULL,
    upstream_area_ha double precision
);


--
-- Name: fwa_watersheds_xborder_poly; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_watersheds_xborder_poly (
    watershed_feature_id integer NOT NULL,
    watershed_group_id integer NOT NULL,
    watershed_key integer NOT NULL,
    fwa_watershed_code character varying(143) NOT NULL,
    local_watershed_code character varying(143) NOT NULL,
    watershed_group_code character varying(4) NOT NULL,
    watershed_order integer,
    watershed_magnitude integer,
    local_watershed_order integer,
    local_watershed_magnitude integer,
    feature_code character varying(10),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    geom public.geometry(MultiPolygon,3005)
);


--
-- Name: fwa_wetlands_poly; Type: TABLE; Schema: whse_basemapping; Owner: -
--

CREATE TABLE whse_basemapping.fwa_wetlands_poly (
    waterbody_poly_id integer NOT NULL,
    watershed_group_id integer,
    waterbody_type character varying(1),
    waterbody_key integer,
    area_ha double precision,
    gnis_id_1 integer,
    gnis_name_1 character varying(80),
    gnis_id_2 integer,
    gnis_name_2 character varying(80),
    gnis_id_3 integer,
    gnis_name_3 character varying(80),
    blue_line_key integer,
    watershed_key integer,
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    watershed_group_code character varying(4),
    left_right_tributary character varying(7),
    waterbody_key_50k integer,
    watershed_group_code_50k character varying(4),
    waterbody_key_group_code_50k character varying(55),
    watershed_code_50k character varying(45),
    feature_code character varying(10),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    geom public.geometry(MultiPolygon,3005)
);


--
-- Name: fwa_approx_borders approx_border_id; Type: DEFAULT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_approx_borders ALTER COLUMN approx_border_id SET DEFAULT nextval('whse_basemapping.fwa_approx_borders_approx_border_id_seq'::regclass);


--
-- Name: fwa_bcboundary bcboundary_id; Type: DEFAULT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_bcboundary ALTER COLUMN bcboundary_id SET DEFAULT nextval('whse_basemapping.fwa_bcboundary_bcboundary_id_seq'::regclass);


--
-- Name: fwa_named_streams named_streams_id; Type: DEFAULT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_named_streams ALTER COLUMN named_streams_id SET DEFAULT nextval('whse_basemapping.fwa_named_streams_named_streams_id_seq'::regclass);


--
-- Name: fwa_stream_networks_mean_annual_precip id; Type: DEFAULT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_stream_networks_mean_annual_precip ALTER COLUMN id SET DEFAULT nextval('whse_basemapping.fwa_stream_networks_mean_annual_precip_id_seq'::regclass);


--
-- Name: hybas_lev12_v1c hybas_lev12_v1c_pkey; Type: CONSTRAINT; Schema: hydrosheds; Owner: -
--

ALTER TABLE ONLY hydrosheds.hybas_lev12_v1c
    ADD CONSTRAINT hybas_lev12_v1c_pkey PRIMARY KEY (hybas_id);


--
-- Name: wbdhu12 wbdhu12_pkey; Type: CONSTRAINT; Schema: usgs; Owner: -
--

ALTER TABLE ONLY usgs.wbdhu12
    ADD CONSTRAINT wbdhu12_pkey PRIMARY KEY (huc12);


--
-- Name: fwa_approx_borders fwa_approx_borders_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_approx_borders
    ADD CONSTRAINT fwa_approx_borders_pkey PRIMARY KEY (approx_border_id);


--
-- Name: fwa_assessment_watersheds_lut fwa_assessment_watersheds_lut_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_assessment_watersheds_lut
    ADD CONSTRAINT fwa_assessment_watersheds_lut_pkey PRIMARY KEY (watershed_feature_id);


--
-- Name: fwa_assessment_watersheds_poly fwa_assessment_watersheds_poly_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_assessment_watersheds_poly
    ADD CONSTRAINT fwa_assessment_watersheds_poly_pkey PRIMARY KEY (watershed_feature_id);


--
-- Name: fwa_assessment_watersheds_streams_lut fwa_assessment_watersheds_streams_lut_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_assessment_watersheds_streams_lut
    ADD CONSTRAINT fwa_assessment_watersheds_streams_lut_pkey PRIMARY KEY (linear_feature_id);


--
-- Name: fwa_basins_poly fwa_basins_poly_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_basins_poly
    ADD CONSTRAINT fwa_basins_poly_pkey PRIMARY KEY (basin_id);


--
-- Name: fwa_bays_and_channels_poly fwa_bays_and_channels_poly_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_bays_and_channels_poly
    ADD CONSTRAINT fwa_bays_and_channels_poly_pkey PRIMARY KEY (bay_and_channel_id);


--
-- Name: fwa_bcboundary fwa_bcboundary_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_bcboundary
    ADD CONSTRAINT fwa_bcboundary_pkey PRIMARY KEY (bcboundary_id);


--
-- Name: fwa_coastlines_sp fwa_coastlines_sp_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_coastlines_sp
    ADD CONSTRAINT fwa_coastlines_sp_pkey PRIMARY KEY (linear_feature_id);


--
-- Name: fwa_glaciers_poly fwa_glaciers_poly_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_glaciers_poly
    ADD CONSTRAINT fwa_glaciers_poly_pkey PRIMARY KEY (waterbody_poly_id);


--
-- Name: fwa_islands_poly fwa_islands_poly_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_islands_poly
    ADD CONSTRAINT fwa_islands_poly_pkey PRIMARY KEY (island_id);


--
-- Name: fwa_lakes_poly fwa_lakes_poly_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_lakes_poly
    ADD CONSTRAINT fwa_lakes_poly_pkey PRIMARY KEY (waterbody_poly_id);


--
-- Name: fwa_linear_boundaries_sp fwa_linear_boundaries_sp_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_linear_boundaries_sp
    ADD CONSTRAINT fwa_linear_boundaries_sp_pkey PRIMARY KEY (linear_feature_id);


--
-- Name: fwa_manmade_waterbodies_poly fwa_manmade_waterbodies_poly_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_manmade_waterbodies_poly
    ADD CONSTRAINT fwa_manmade_waterbodies_poly_pkey PRIMARY KEY (waterbody_poly_id);


--
-- Name: fwa_named_point_features_sp fwa_named_point_features_sp_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_named_point_features_sp
    ADD CONSTRAINT fwa_named_point_features_sp_pkey PRIMARY KEY (named_point_feature_id);


--
-- Name: fwa_named_streams fwa_named_streams_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_named_streams
    ADD CONSTRAINT fwa_named_streams_pkey PRIMARY KEY (named_streams_id);


--
-- Name: fwa_named_watersheds_poly fwa_named_watersheds_poly_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_named_watersheds_poly
    ADD CONSTRAINT fwa_named_watersheds_poly_pkey PRIMARY KEY (named_watershed_id);


--
-- Name: fwa_obstructions_sp fwa_obstructions_sp_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_obstructions_sp
    ADD CONSTRAINT fwa_obstructions_sp_pkey PRIMARY KEY (obstruction_id);


--
-- Name: fwa_rivers_poly fwa_rivers_poly_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_rivers_poly
    ADD CONSTRAINT fwa_rivers_poly_pkey PRIMARY KEY (waterbody_poly_id);


--
-- Name: fwa_stream_networks_channel_width fwa_stream_networks_channel_width_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_stream_networks_channel_width
    ADD CONSTRAINT fwa_stream_networks_channel_width_pkey PRIMARY KEY (linear_feature_id);


--
-- Name: fwa_stream_networks_discharge fwa_stream_networks_discharge_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_stream_networks_discharge
    ADD CONSTRAINT fwa_stream_networks_discharge_pkey PRIMARY KEY (linear_feature_id);


--
-- Name: fwa_stream_networks_mean_annual_precip fwa_stream_networks_mean_annua_wscode_ltree_localcode_ltree_key; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_stream_networks_mean_annual_precip
    ADD CONSTRAINT fwa_stream_networks_mean_annua_wscode_ltree_localcode_ltree_key UNIQUE (wscode_ltree, localcode_ltree);


--
-- Name: fwa_stream_networks_mean_annual_precip fwa_stream_networks_mean_annual_precip_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_stream_networks_mean_annual_precip
    ADD CONSTRAINT fwa_stream_networks_mean_annual_precip_pkey PRIMARY KEY (id);


--
-- Name: fwa_stream_networks_order_max fwa_stream_networks_order_max_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_stream_networks_order_max
    ADD CONSTRAINT fwa_stream_networks_order_max_pkey PRIMARY KEY (blue_line_key);


--
-- Name: fwa_stream_networks_order_parent fwa_stream_networks_order_parent_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_stream_networks_order_parent
    ADD CONSTRAINT fwa_stream_networks_order_parent_pkey PRIMARY KEY (blue_line_key);


--
-- Name: fwa_stream_networks_sp fwa_stream_networks_sp_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_stream_networks_sp
    ADD CONSTRAINT fwa_stream_networks_sp_pkey PRIMARY KEY (linear_feature_id);


--
-- Name: fwa_streams_20k_50k fwa_streams_20k_50k_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_streams_20k_50k
    ADD CONSTRAINT fwa_streams_20k_50k_pkey PRIMARY KEY (stream_20k_50k_id);


--
-- Name: fwa_streams fwa_streams_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_streams
    ADD CONSTRAINT fwa_streams_pkey PRIMARY KEY (linear_feature_id);


--
-- Name: fwa_streams_watersheds_lut fwa_streams_watersheds_lut_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_streams_watersheds_lut
    ADD CONSTRAINT fwa_streams_watersheds_lut_pkey PRIMARY KEY (linear_feature_id);


--
-- Name: fwa_waterbodies_20k_50k fwa_waterbodies_20k_50k_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_waterbodies_20k_50k
    ADD CONSTRAINT fwa_waterbodies_20k_50k_pkey PRIMARY KEY (waterbody_20k_50k_id);


--
-- Name: fwa_waterbodies fwa_waterbodies_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_waterbodies
    ADD CONSTRAINT fwa_waterbodies_pkey PRIMARY KEY (waterbody_key);


--
-- Name: fwa_waterbodies_upstream_area fwa_waterbodies_upstream_area_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_waterbodies_upstream_area
    ADD CONSTRAINT fwa_waterbodies_upstream_area_pkey PRIMARY KEY (linear_feature_id);


--
-- Name: fwa_watershed_groups_poly fwa_watershed_groups_poly_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_watershed_groups_poly
    ADD CONSTRAINT fwa_watershed_groups_poly_pkey PRIMARY KEY (watershed_group_id);


--
-- Name: fwa_watersheds_poly fwa_watersheds_poly_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_watersheds_poly
    ADD CONSTRAINT fwa_watersheds_poly_pkey PRIMARY KEY (watershed_feature_id);


--
-- Name: fwa_watersheds_upstream_area fwa_watersheds_upstream_area_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_watersheds_upstream_area
    ADD CONSTRAINT fwa_watersheds_upstream_area_pkey PRIMARY KEY (watershed_feature_id);


--
-- Name: fwa_watersheds_xborder_poly fwa_watersheds_xborder_poly_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_watersheds_xborder_poly
    ADD CONSTRAINT fwa_watersheds_xborder_poly_pkey PRIMARY KEY (watershed_feature_id);


--
-- Name: fwa_wetlands_poly fwa_wetlands_poly_pkey; Type: CONSTRAINT; Schema: whse_basemapping; Owner: -
--

ALTER TABLE ONLY whse_basemapping.fwa_wetlands_poly
    ADD CONSTRAINT fwa_wetlands_poly_pkey PRIMARY KEY (waterbody_poly_id);


--
-- Name: hybas_lev12_v1c_geom_idx; Type: INDEX; Schema: hydrosheds; Owner: -
--

CREATE INDEX hybas_lev12_v1c_geom_idx ON hydrosheds.hybas_lev12_v1c USING gist (geom);


--
-- Name: hybas_lev12_v1c_next_down_idx; Type: INDEX; Schema: hydrosheds; Owner: -
--

CREATE INDEX hybas_lev12_v1c_next_down_idx ON hydrosheds.hybas_lev12_v1c USING btree (next_down);


--
-- Name: wbdhu12_tohuc_idx; Type: INDEX; Schema: usgs; Owner: -
--

CREATE INDEX wbdhu12_tohuc_idx ON usgs.wbdhu12 USING btree (tohuc);


--
-- Name: fwa_assessment_watersheds_lut_assmnt_watershed_id_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_assessment_watersheds_lut_assmnt_watershed_id_idx ON whse_basemapping.fwa_assessment_watersheds_lut USING btree (assmnt_watershed_id);


--
-- Name: fwa_assessment_watersheds_streams_lut_assmnt_watershed_id_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_assessment_watersheds_streams_lut_assmnt_watershed_id_idx ON whse_basemapping.fwa_assessment_watersheds_streams_lut USING btree (assmnt_watershed_id);


--
-- Name: fwa_assmnt_wshds_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_assmnt_wshds_geom_idx ON whse_basemapping.fwa_assessment_watersheds_poly USING gist (geom);


--
-- Name: fwa_assmnt_wshds_gnis_name_1_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_assmnt_wshds_gnis_name_1_idx ON whse_basemapping.fwa_assessment_watersheds_poly USING btree (gnis_name_1);


--
-- Name: fwa_assmnt_wshds_lc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_assmnt_wshds_lc_btree_idx ON whse_basemapping.fwa_assessment_watersheds_poly USING btree (localcode_ltree);


--
-- Name: fwa_assmnt_wshds_lc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_assmnt_wshds_lc_gist_idx ON whse_basemapping.fwa_assessment_watersheds_poly USING gist (localcode_ltree);


--
-- Name: fwa_assmnt_wshds_waterbody_id_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_assmnt_wshds_waterbody_id_idx ON whse_basemapping.fwa_assessment_watersheds_poly USING btree (waterbody_id);


--
-- Name: fwa_assmnt_wshds_waterbody_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_assmnt_wshds_waterbody_key_idx ON whse_basemapping.fwa_assessment_watersheds_poly USING btree (waterbody_key);


--
-- Name: fwa_assmnt_wshds_watershed_group_code_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_assmnt_wshds_watershed_group_code_idx ON whse_basemapping.fwa_assessment_watersheds_poly USING btree (watershed_group_code);


--
-- Name: fwa_assmnt_wshds_watershed_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_assmnt_wshds_watershed_key_idx ON whse_basemapping.fwa_assessment_watersheds_poly USING btree (watershed_key);


--
-- Name: fwa_assmnt_wshds_wsc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_assmnt_wshds_wsc_btree_idx ON whse_basemapping.fwa_assessment_watersheds_poly USING btree (wscode_ltree);


--
-- Name: fwa_assmnt_wshds_wsc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_assmnt_wshds_wsc_gist_idx ON whse_basemapping.fwa_assessment_watersheds_poly USING gist (wscode_ltree);


--
-- Name: fwa_basins_poly_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_basins_poly_geom_idx ON whse_basemapping.fwa_basins_poly USING gist (geom);


--
-- Name: fwa_basins_poly_localcode_ltree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_basins_poly_localcode_ltree_idx ON whse_basemapping.fwa_basins_poly USING gist (localcode_ltree);


--
-- Name: fwa_basins_poly_localcode_ltree_idx1; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_basins_poly_localcode_ltree_idx1 ON whse_basemapping.fwa_basins_poly USING btree (localcode_ltree);


--
-- Name: fwa_basins_poly_wscode_ltree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_basins_poly_wscode_ltree_idx ON whse_basemapping.fwa_basins_poly USING gist (wscode_ltree);


--
-- Name: fwa_basins_poly_wscode_ltree_idx1; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_basins_poly_wscode_ltree_idx1 ON whse_basemapping.fwa_basins_poly USING btree (wscode_ltree);


--
-- Name: fwa_bays_channels_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_bays_channels_geom_idx ON whse_basemapping.fwa_bays_and_channels_poly USING gist (geom);


--
-- Name: fwa_bays_channels_gnis_name_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_bays_channels_gnis_name_idx ON whse_basemapping.fwa_bays_and_channels_poly USING btree (gnis_name);


--
-- Name: fwa_bcboundary_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_bcboundary_geom_idx ON whse_basemapping.fwa_bcboundary USING gist (geom);


--
-- Name: fwa_coastlines_blue_line_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_coastlines_blue_line_key_idx ON whse_basemapping.fwa_coastlines_sp USING btree (blue_line_key);


--
-- Name: fwa_coastlines_edge_type_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_coastlines_edge_type_idx ON whse_basemapping.fwa_coastlines_sp USING btree (edge_type);


--
-- Name: fwa_coastlines_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_coastlines_geom_idx ON whse_basemapping.fwa_coastlines_sp USING gist (geom);


--
-- Name: fwa_coastlines_watershed_group_code_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_coastlines_watershed_group_code_idx ON whse_basemapping.fwa_coastlines_sp USING btree (watershed_group_code);


--
-- Name: fwa_coastlines_watershed_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_coastlines_watershed_key_idx ON whse_basemapping.fwa_coastlines_sp USING btree (watershed_key);


--
-- Name: fwa_glaciers_blue_line_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_glaciers_blue_line_key_idx ON whse_basemapping.fwa_glaciers_poly USING btree (blue_line_key);


--
-- Name: fwa_glaciers_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_glaciers_geom_idx ON whse_basemapping.fwa_glaciers_poly USING gist (geom);


--
-- Name: fwa_glaciers_gnis_name_1_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_glaciers_gnis_name_1_idx ON whse_basemapping.fwa_glaciers_poly USING btree (gnis_name_1);


--
-- Name: fwa_glaciers_lc_btree_ltree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_glaciers_lc_btree_ltree_idx ON whse_basemapping.fwa_glaciers_poly USING btree (localcode_ltree);


--
-- Name: fwa_glaciers_lc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_glaciers_lc_gist_idx ON whse_basemapping.fwa_glaciers_poly USING gist (localcode_ltree);


--
-- Name: fwa_glaciers_waterbody_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_glaciers_waterbody_key_idx ON whse_basemapping.fwa_glaciers_poly USING btree (waterbody_key);


--
-- Name: fwa_glaciers_watershed_group_code_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_glaciers_watershed_group_code_idx ON whse_basemapping.fwa_glaciers_poly USING btree (watershed_group_code);


--
-- Name: fwa_glaciers_watershed_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_glaciers_watershed_key_idx ON whse_basemapping.fwa_glaciers_poly USING btree (watershed_key);


--
-- Name: fwa_glaciers_wsc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_glaciers_wsc_btree_idx ON whse_basemapping.fwa_glaciers_poly USING btree (wscode_ltree);


--
-- Name: fwa_glaciers_wsc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_glaciers_wsc_gist_idx ON whse_basemapping.fwa_glaciers_poly USING gist (wscode_ltree);


--
-- Name: fwa_islands_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_islands_geom_idx ON whse_basemapping.fwa_islands_poly USING gist (geom);


--
-- Name: fwa_islands_gnis_name_1_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_islands_gnis_name_1_idx ON whse_basemapping.fwa_islands_poly USING btree (gnis_name_1);


--
-- Name: fwa_islands_gnis_name_2_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_islands_gnis_name_2_idx ON whse_basemapping.fwa_islands_poly USING btree (gnis_name_2);


--
-- Name: fwa_islands_lc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_islands_lc_btree_idx ON whse_basemapping.fwa_islands_poly USING btree (localcode_ltree);


--
-- Name: fwa_islands_lc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_islands_lc_gist_idx ON whse_basemapping.fwa_islands_poly USING gist (localcode_ltree);


--
-- Name: fwa_islands_wsc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_islands_wsc_btree_idx ON whse_basemapping.fwa_islands_poly USING btree (wscode_ltree);


--
-- Name: fwa_islands_wsc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_islands_wsc_gist_idx ON whse_basemapping.fwa_islands_poly USING gist (wscode_ltree);


--
-- Name: fwa_lakes_blue_line_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_lakes_blue_line_key_idx ON whse_basemapping.fwa_lakes_poly USING btree (blue_line_key);


--
-- Name: fwa_lakes_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_lakes_geom_idx ON whse_basemapping.fwa_lakes_poly USING gist (geom);


--
-- Name: fwa_lakes_gnis_name_1_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_lakes_gnis_name_1_idx ON whse_basemapping.fwa_lakes_poly USING btree (gnis_name_1);


--
-- Name: fwa_lakes_lc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_lakes_lc_btree_idx ON whse_basemapping.fwa_lakes_poly USING btree (localcode_ltree);


--
-- Name: fwa_lakes_lc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_lakes_lc_gist_idx ON whse_basemapping.fwa_lakes_poly USING gist (localcode_ltree);


--
-- Name: fwa_lakes_waterbody_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_lakes_waterbody_key_idx ON whse_basemapping.fwa_lakes_poly USING btree (waterbody_key);


--
-- Name: fwa_lakes_watershed_group_code_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_lakes_watershed_group_code_idx ON whse_basemapping.fwa_lakes_poly USING btree (watershed_group_code);


--
-- Name: fwa_lakes_watershed_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_lakes_watershed_key_idx ON whse_basemapping.fwa_lakes_poly USING btree (watershed_key);


--
-- Name: fwa_lakes_wsc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_lakes_wsc_btree_idx ON whse_basemapping.fwa_lakes_poly USING btree (wscode_ltree);


--
-- Name: fwa_lakes_wsc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_lakes_wsc_gist_idx ON whse_basemapping.fwa_lakes_poly USING gist (wscode_ltree);


--
-- Name: fwa_linear_bnd_blue_line_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_linear_bnd_blue_line_key_idx ON whse_basemapping.fwa_linear_boundaries_sp USING btree (blue_line_key);


--
-- Name: fwa_linear_bnd_edge_type_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_linear_bnd_edge_type_idx ON whse_basemapping.fwa_linear_boundaries_sp USING btree (edge_type);


--
-- Name: fwa_linear_bnd_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_linear_bnd_geom_idx ON whse_basemapping.fwa_linear_boundaries_sp USING gist (geom);


--
-- Name: fwa_linear_bnd_lc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_linear_bnd_lc_btree_idx ON whse_basemapping.fwa_linear_boundaries_sp USING btree (localcode_ltree);


--
-- Name: fwa_linear_bnd_lc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_linear_bnd_lc_gist_idx ON whse_basemapping.fwa_linear_boundaries_sp USING gist (localcode_ltree);


--
-- Name: fwa_linear_bnd_waterbody_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_linear_bnd_waterbody_key_idx ON whse_basemapping.fwa_linear_boundaries_sp USING btree (waterbody_key);


--
-- Name: fwa_linear_bnd_watershed_group_code_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_linear_bnd_watershed_group_code_idx ON whse_basemapping.fwa_linear_boundaries_sp USING btree (watershed_group_code);


--
-- Name: fwa_linear_bnd_watershed_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_linear_bnd_watershed_key_idx ON whse_basemapping.fwa_linear_boundaries_sp USING btree (watershed_key);


--
-- Name: fwa_linear_bnd_wsc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_linear_bnd_wsc_btree_idx ON whse_basemapping.fwa_linear_boundaries_sp USING btree (wscode_ltree);


--
-- Name: fwa_linear_bnd_wsc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_linear_bnd_wsc_gist_idx ON whse_basemapping.fwa_linear_boundaries_sp USING gist (wscode_ltree);


--
-- Name: fwa_mmdwbdy_blue_line_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_mmdwbdy_blue_line_key_idx ON whse_basemapping.fwa_manmade_waterbodies_poly USING btree (blue_line_key);


--
-- Name: fwa_mmdwbdy_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_mmdwbdy_geom_idx ON whse_basemapping.fwa_manmade_waterbodies_poly USING gist (geom);


--
-- Name: fwa_mmdwbdy_gnis_name_1_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_mmdwbdy_gnis_name_1_idx ON whse_basemapping.fwa_manmade_waterbodies_poly USING btree (gnis_name_1);


--
-- Name: fwa_mmdwbdy_lc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_mmdwbdy_lc_btree_idx ON whse_basemapping.fwa_manmade_waterbodies_poly USING btree (localcode_ltree);


--
-- Name: fwa_mmdwbdy_lc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_mmdwbdy_lc_gist_idx ON whse_basemapping.fwa_manmade_waterbodies_poly USING gist (localcode_ltree);


--
-- Name: fwa_mmdwbdy_waterbody_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_mmdwbdy_waterbody_key_idx ON whse_basemapping.fwa_manmade_waterbodies_poly USING btree (waterbody_key);


--
-- Name: fwa_mmdwbdy_watershed_group_code_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_mmdwbdy_watershed_group_code_idx ON whse_basemapping.fwa_manmade_waterbodies_poly USING btree (watershed_group_code);


--
-- Name: fwa_mmdwbdy_watershed_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_mmdwbdy_watershed_key_idx ON whse_basemapping.fwa_manmade_waterbodies_poly USING btree (watershed_key);


--
-- Name: fwa_mmdwbdy_wsc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_mmdwbdy_wsc_btree_idx ON whse_basemapping.fwa_manmade_waterbodies_poly USING btree (wscode_ltree);


--
-- Name: fwa_mmdwbdy_wsc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_mmdwbdy_wsc_gist_idx ON whse_basemapping.fwa_manmade_waterbodies_poly USING gist (wscode_ltree);


--
-- Name: fwa_named_streams_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_named_streams_geom_idx ON whse_basemapping.fwa_named_streams USING gist (geom);


--
-- Name: fwa_named_wsds_blue_line_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_named_wsds_blue_line_key_idx ON whse_basemapping.fwa_named_watersheds_poly USING btree (blue_line_key);


--
-- Name: fwa_named_wsds_fwa_watershed_code_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_named_wsds_fwa_watershed_code_idx ON whse_basemapping.fwa_named_watersheds_poly USING btree (fwa_watershed_code);


--
-- Name: fwa_named_wsds_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_named_wsds_geom_idx ON whse_basemapping.fwa_named_watersheds_poly USING gist (geom);


--
-- Name: fwa_named_wsds_gnis_name_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_named_wsds_gnis_name_idx ON whse_basemapping.fwa_named_watersheds_poly USING btree (gnis_name);


--
-- Name: fwa_named_wsds_wsc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_named_wsds_wsc_btree_idx ON whse_basemapping.fwa_named_watersheds_poly USING btree (wscode_ltree);


--
-- Name: fwa_named_wsds_wsc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_named_wsds_wsc_gist_idx ON whse_basemapping.fwa_named_watersheds_poly USING gist (wscode_ltree);


--
-- Name: fwa_namedpt_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_namedpt_geom_idx ON whse_basemapping.fwa_named_point_features_sp USING gist (geom);


--
-- Name: fwa_namedpt_gnis_name_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_namedpt_gnis_name_idx ON whse_basemapping.fwa_named_point_features_sp USING btree (gnis_name);


--
-- Name: fwa_obstructions_blue_line_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_obstructions_blue_line_key_idx ON whse_basemapping.fwa_obstructions_sp USING btree (blue_line_key);


--
-- Name: fwa_obstructions_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_obstructions_geom_idx ON whse_basemapping.fwa_obstructions_sp USING gist (geom);


--
-- Name: fwa_obstructions_gnis_name_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_obstructions_gnis_name_idx ON whse_basemapping.fwa_obstructions_sp USING btree (gnis_name);


--
-- Name: fwa_obstructions_lc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_obstructions_lc_btree_idx ON whse_basemapping.fwa_obstructions_sp USING btree (localcode_ltree);


--
-- Name: fwa_obstructions_lc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_obstructions_lc_gist_idx ON whse_basemapping.fwa_obstructions_sp USING gist (localcode_ltree);


--
-- Name: fwa_obstructions_linear_feature_id_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_obstructions_linear_feature_id_idx ON whse_basemapping.fwa_obstructions_sp USING btree (linear_feature_id);


--
-- Name: fwa_obstructions_obstruction_type_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_obstructions_obstruction_type_idx ON whse_basemapping.fwa_obstructions_sp USING btree (obstruction_type);


--
-- Name: fwa_obstructions_watershed_group_code_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_obstructions_watershed_group_code_idx ON whse_basemapping.fwa_obstructions_sp USING btree (watershed_group_code);


--
-- Name: fwa_obstructions_watershed_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_obstructions_watershed_key_idx ON whse_basemapping.fwa_obstructions_sp USING btree (watershed_key);


--
-- Name: fwa_obstructions_wsc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_obstructions_wsc_btree_idx ON whse_basemapping.fwa_obstructions_sp USING btree (wscode_ltree);


--
-- Name: fwa_obstructions_wsc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_obstructions_wsc_gist_idx ON whse_basemapping.fwa_obstructions_sp USING gist (wscode_ltree);


--
-- Name: fwa_rivers_blue_line_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_rivers_blue_line_key_idx ON whse_basemapping.fwa_rivers_poly USING btree (blue_line_key);


--
-- Name: fwa_rivers_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_rivers_geom_idx ON whse_basemapping.fwa_rivers_poly USING gist (geom);


--
-- Name: fwa_rivers_gnis_name_1_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_rivers_gnis_name_1_idx ON whse_basemapping.fwa_rivers_poly USING btree (gnis_name_1);


--
-- Name: fwa_rivers_lc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_rivers_lc_btree_idx ON whse_basemapping.fwa_rivers_poly USING btree (localcode_ltree);


--
-- Name: fwa_rivers_lc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_rivers_lc_gist_idx ON whse_basemapping.fwa_rivers_poly USING gist (localcode_ltree);


--
-- Name: fwa_rivers_waterbody_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_rivers_waterbody_key_idx ON whse_basemapping.fwa_rivers_poly USING btree (waterbody_key);


--
-- Name: fwa_rivers_watershed_group_code_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_rivers_watershed_group_code_idx ON whse_basemapping.fwa_rivers_poly USING btree (watershed_group_code);


--
-- Name: fwa_rivers_watershed_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_rivers_watershed_key_idx ON whse_basemapping.fwa_rivers_poly USING btree (watershed_key);


--
-- Name: fwa_rivers_wsc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_rivers_wsc_btree_idx ON whse_basemapping.fwa_rivers_poly USING btree (wscode_ltree);


--
-- Name: fwa_rivers_wsc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_rivers_wsc_gist_idx ON whse_basemapping.fwa_rivers_poly USING gist (wscode_ltree);


--
-- Name: fwa_streamnetworks_blkey_measure_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streamnetworks_blkey_measure_idx ON whse_basemapping.fwa_stream_networks_sp USING btree (blue_line_key, downstream_route_measure);


--
-- Name: fwa_streamnetworks_blue_line_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streamnetworks_blue_line_key_idx ON whse_basemapping.fwa_stream_networks_sp USING btree (blue_line_key);


--
-- Name: fwa_streamnetworks_edge_type_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streamnetworks_edge_type_idx ON whse_basemapping.fwa_stream_networks_sp USING btree (edge_type);


--
-- Name: fwa_streamnetworks_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streamnetworks_geom_idx ON whse_basemapping.fwa_stream_networks_sp USING gist (geom);


--
-- Name: fwa_streamnetworks_gnis_name_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streamnetworks_gnis_name_idx ON whse_basemapping.fwa_stream_networks_sp USING btree (gnis_name);


--
-- Name: fwa_streamnetworks_lc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streamnetworks_lc_btree_idx ON whse_basemapping.fwa_stream_networks_sp USING btree (localcode_ltree);


--
-- Name: fwa_streamnetworks_lc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streamnetworks_lc_gist_idx ON whse_basemapping.fwa_stream_networks_sp USING gist (localcode_ltree);


--
-- Name: fwa_streamnetworks_waterbody_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streamnetworks_waterbody_key_idx ON whse_basemapping.fwa_stream_networks_sp USING btree (waterbody_key);


--
-- Name: fwa_streamnetworks_watershed_group_code_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streamnetworks_watershed_group_code_idx ON whse_basemapping.fwa_stream_networks_sp USING btree (watershed_group_code);


--
-- Name: fwa_streamnetworks_watershed_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streamnetworks_watershed_key_idx ON whse_basemapping.fwa_stream_networks_sp USING btree (watershed_key);


--
-- Name: fwa_streamnetworks_wsc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streamnetworks_wsc_btree_idx ON whse_basemapping.fwa_stream_networks_sp USING btree (wscode_ltree);


--
-- Name: fwa_streamnetworks_wsc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streamnetworks_wsc_gist_idx ON whse_basemapping.fwa_stream_networks_sp USING gist (wscode_ltree);


--
-- Name: fwa_streams_blkey_measure_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streams_blkey_measure_idx ON whse_basemapping.fwa_streams USING btree (blue_line_key, downstream_route_measure);


--
-- Name: fwa_streams_blue_line_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streams_blue_line_key_idx ON whse_basemapping.fwa_streams USING btree (blue_line_key);


--
-- Name: fwa_streams_edge_type_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streams_edge_type_idx ON whse_basemapping.fwa_streams USING btree (edge_type);


--
-- Name: fwa_streams_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streams_geom_idx ON whse_basemapping.fwa_streams USING gist (geom);


--
-- Name: fwa_streams_gnis_name_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streams_gnis_name_idx ON whse_basemapping.fwa_streams USING btree (gnis_name);


--
-- Name: fwa_streams_lc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streams_lc_btree_idx ON whse_basemapping.fwa_streams USING btree (localcode);


--
-- Name: fwa_streams_lc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streams_lc_gist_idx ON whse_basemapping.fwa_streams USING gist (localcode);


--
-- Name: fwa_streams_pse_conservation_units_lut_cuid_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streams_pse_conservation_units_lut_cuid_idx ON whse_basemapping.fwa_streams_pse_conservation_units_lut USING btree (cuid);


--
-- Name: fwa_streams_pse_conservation_units_lut_linear_feature_id_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streams_pse_conservation_units_lut_linear_feature_id_idx ON whse_basemapping.fwa_streams_pse_conservation_units_lut USING btree (linear_feature_id);


--
-- Name: fwa_streams_waterbody_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streams_waterbody_key_idx ON whse_basemapping.fwa_streams USING btree (waterbody_key);


--
-- Name: fwa_streams_watershed_group_code_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streams_watershed_group_code_idx ON whse_basemapping.fwa_streams USING btree (watershed_group_code);


--
-- Name: fwa_streams_watershed_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streams_watershed_key_idx ON whse_basemapping.fwa_streams USING btree (watershed_key);


--
-- Name: fwa_streams_watersheds_lut_watershed_feature_id_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streams_watersheds_lut_watershed_feature_id_idx ON whse_basemapping.fwa_streams_watersheds_lut USING btree (watershed_feature_id);


--
-- Name: fwa_streams_wsc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streams_wsc_btree_idx ON whse_basemapping.fwa_streams USING btree (wscode);


--
-- Name: fwa_streams_wsc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_streams_wsc_gist_idx ON whse_basemapping.fwa_streams USING gist (wscode);


--
-- Name: fwa_strms_20k50k_linear_feature_id_20k_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_strms_20k50k_linear_feature_id_20k_idx ON whse_basemapping.fwa_streams_20k_50k USING btree (linear_feature_id_20k);


--
-- Name: fwa_strms_20k50k_watershed_code_50k_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_strms_20k50k_watershed_code_50k_idx ON whse_basemapping.fwa_streams_20k_50k USING btree (watershed_code_50k);


--
-- Name: fwa_strms_20k50k_watershed_group_id_20k_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_strms_20k50k_watershed_group_id_20k_idx ON whse_basemapping.fwa_streams_20k_50k USING btree (watershed_group_id_20k);


--
-- Name: fwa_waterbodies_blue_line_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_waterbodies_blue_line_key_idx ON whse_basemapping.fwa_waterbodies USING btree (blue_line_key);


--
-- Name: fwa_waterbodies_localcode_ltree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_waterbodies_localcode_ltree_idx ON whse_basemapping.fwa_waterbodies USING gist (localcode_ltree);


--
-- Name: fwa_waterbodies_localcode_ltree_idx1; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_waterbodies_localcode_ltree_idx1 ON whse_basemapping.fwa_waterbodies USING btree (localcode_ltree);


--
-- Name: fwa_waterbodies_wscode_ltree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_waterbodies_wscode_ltree_idx ON whse_basemapping.fwa_waterbodies USING gist (wscode_ltree);


--
-- Name: fwa_waterbodies_wscode_ltree_idx1; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_waterbodies_wscode_ltree_idx1 ON whse_basemapping.fwa_waterbodies USING btree (wscode_ltree);


--
-- Name: fwa_watershed_groups_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_watershed_groups_geom_idx ON whse_basemapping.fwa_watershed_groups_poly USING gist (geom);


--
-- Name: fwa_watershed_groups_watershed_group_code_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE UNIQUE INDEX fwa_watershed_groups_watershed_group_code_idx ON whse_basemapping.fwa_watershed_groups_poly USING btree (watershed_group_code);


--
-- Name: fwa_watersheds_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_watersheds_geom_idx ON whse_basemapping.fwa_watersheds_poly USING gist (geom);


--
-- Name: fwa_watersheds_gnis_name_1_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_watersheds_gnis_name_1_idx ON whse_basemapping.fwa_watersheds_poly USING btree (gnis_name_1);


--
-- Name: fwa_watersheds_lc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_watersheds_lc_btree_idx ON whse_basemapping.fwa_watersheds_poly USING btree (localcode_ltree);


--
-- Name: fwa_watersheds_lc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_watersheds_lc_gist_idx ON whse_basemapping.fwa_watersheds_poly USING gist (localcode_ltree);


--
-- Name: fwa_watersheds_waterbody_id_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_watersheds_waterbody_id_idx ON whse_basemapping.fwa_watersheds_poly USING btree (waterbody_id);


--
-- Name: fwa_watersheds_waterbody_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_watersheds_waterbody_key_idx ON whse_basemapping.fwa_watersheds_poly USING btree (waterbody_key);


--
-- Name: fwa_watersheds_watershed_group_code_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_watersheds_watershed_group_code_idx ON whse_basemapping.fwa_watersheds_poly USING btree (watershed_group_code);


--
-- Name: fwa_watersheds_watershed_group_id_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_watersheds_watershed_group_id_idx ON whse_basemapping.fwa_watersheds_poly USING btree (watershed_group_id);


--
-- Name: fwa_watersheds_watershed_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_watersheds_watershed_key_idx ON whse_basemapping.fwa_watersheds_poly USING btree (watershed_key);


--
-- Name: fwa_watersheds_wsc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_watersheds_wsc_btree_idx ON whse_basemapping.fwa_watersheds_poly USING btree (wscode_ltree);


--
-- Name: fwa_watersheds_wsc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_watersheds_wsc_gist_idx ON whse_basemapping.fwa_watersheds_poly USING gist (wscode_ltree);


--
-- Name: fwa_wb_20k50k_fwa_watershed_code_20k_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wb_20k50k_fwa_watershed_code_20k_idx ON whse_basemapping.fwa_waterbodies_20k_50k USING btree (fwa_watershed_code_20k);


--
-- Name: fwa_wb_20k50k_waterbody_poly_id_20k_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wb_20k50k_waterbody_poly_id_20k_idx ON whse_basemapping.fwa_waterbodies_20k_50k USING btree (waterbody_poly_id_20k);


--
-- Name: fwa_wb_20k50k_waterbody_type_20k_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wb_20k50k_waterbody_type_20k_idx ON whse_basemapping.fwa_waterbodies_20k_50k USING btree (waterbody_type_20k);


--
-- Name: fwa_wb_20k50k_watershed_code_50k_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wb_20k50k_watershed_code_50k_idx ON whse_basemapping.fwa_waterbodies_20k_50k USING btree (watershed_code_50k);


--
-- Name: fwa_wb_20k50k_watershed_group_id_20k_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wb_20k50k_watershed_group_id_20k_idx ON whse_basemapping.fwa_waterbodies_20k_50k USING btree (watershed_group_id_20k);


--
-- Name: fwa_wetlands_blue_line_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wetlands_blue_line_key_idx ON whse_basemapping.fwa_wetlands_poly USING btree (blue_line_key);


--
-- Name: fwa_wetlands_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wetlands_geom_idx ON whse_basemapping.fwa_wetlands_poly USING gist (geom);


--
-- Name: fwa_wetlands_gnis_name_1_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wetlands_gnis_name_1_idx ON whse_basemapping.fwa_wetlands_poly USING btree (gnis_name_1);


--
-- Name: fwa_wetlands_lc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wetlands_lc_btree_idx ON whse_basemapping.fwa_wetlands_poly USING btree (localcode_ltree);


--
-- Name: fwa_wetlands_lc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wetlands_lc_gist_idx ON whse_basemapping.fwa_wetlands_poly USING gist (localcode_ltree);


--
-- Name: fwa_wetlands_waterbody_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wetlands_waterbody_key_idx ON whse_basemapping.fwa_wetlands_poly USING btree (waterbody_key);


--
-- Name: fwa_wetlands_watershed_group_code_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wetlands_watershed_group_code_idx ON whse_basemapping.fwa_wetlands_poly USING btree (watershed_group_code);


--
-- Name: fwa_wetlands_watershed_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wetlands_watershed_key_idx ON whse_basemapping.fwa_wetlands_poly USING btree (watershed_key);


--
-- Name: fwa_wetlands_wsc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wetlands_wsc_btree_idx ON whse_basemapping.fwa_wetlands_poly USING btree (wscode_ltree);


--
-- Name: fwa_wetlands_wsc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wetlands_wsc_gist_idx ON whse_basemapping.fwa_wetlands_poly USING gist (wscode_ltree);


--
-- Name: fwa_wsd_xborder_geom_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wsd_xborder_geom_idx ON whse_basemapping.fwa_watersheds_xborder_poly USING gist (geom);


--
-- Name: fwa_wsd_xborder_lc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wsd_xborder_lc_btree_idx ON whse_basemapping.fwa_watersheds_xborder_poly USING btree (localcode_ltree);


--
-- Name: fwa_wsd_xborder_lc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wsd_xborder_lc_gist_idx ON whse_basemapping.fwa_watersheds_xborder_poly USING gist (localcode_ltree);


--
-- Name: fwa_wsd_xborder_watershed_group_code_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wsd_xborder_watershed_group_code_idx ON whse_basemapping.fwa_watersheds_xborder_poly USING btree (watershed_group_code);


--
-- Name: fwa_wsd_xborder_watershed_group_id_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wsd_xborder_watershed_group_id_idx ON whse_basemapping.fwa_watersheds_xborder_poly USING btree (watershed_group_id);


--
-- Name: fwa_wsd_xborder_watershed_key_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wsd_xborder_watershed_key_idx ON whse_basemapping.fwa_watersheds_xborder_poly USING btree (watershed_key);


--
-- Name: fwa_wsd_xborder_wsc_btree_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wsd_xborder_wsc_btree_idx ON whse_basemapping.fwa_watersheds_xborder_poly USING btree (wscode_ltree);


--
-- Name: fwa_wsd_xborder_wsc_gist_idx; Type: INDEX; Schema: whse_basemapping; Owner: -
--

CREATE INDEX fwa_wsd_xborder_wsc_gist_idx ON whse_basemapping.fwa_watersheds_xborder_poly USING gist (wscode_ltree);
