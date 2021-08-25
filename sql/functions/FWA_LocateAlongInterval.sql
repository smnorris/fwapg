-- Return a point on the stream network based on the location provided by input blue_line_key and downstream_route_measure

DROP FUNCTION postgisftw.FWA_LocateAlongInterval;
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
  FWA_LocateAlong(s.blue_line_key, s.downstream_route_measure) as geom
FROM segments s;

END;

$$
LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION postgisftw.FWA_LocateAlongInterval IS 'Return a table (index, measure, geom), representing points along a stream between specified locatins at specified interval'