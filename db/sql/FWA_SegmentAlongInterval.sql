CREATE OR REPLACE FUNCTION whse_basemapping.FWA_SegmentAlongInterval(
    blue_line_key integer, 
    interval_length integer DEFAULT 100,
    start_measure integer DEFAULT 0,
    end_measure integer DEFAULT NULL
)

-- note that multipart geometries are returned in order to support non-contiguous stream geoms
-- (ie, cross border or similar)

RETURNS TABLE
    (
        index                    integer,
        downstream_route_measure double precision,
        upstream_route_measure   double precision,
        geom                     geometry(MultiLineString, 3005)
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

$$
LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION whse_basemapping.FWA_SegmentAlongInterval IS 'Return a table (index, downstream_route_measure, upstream_route_measure, geom), representing segments along a stream between specified locations at specified interval';