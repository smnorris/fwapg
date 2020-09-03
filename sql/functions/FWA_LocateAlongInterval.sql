-- Return a point on the stream network based on the location provided by input blue_line_key and downstream_route_measure

DROP FUNCTION postgisftw.FWA_LocateAlongInterval;
CREATE OR REPLACE FUNCTION postgisftw.FWA_LocateAlongInterval(blue_line_key integer, start integer DEFAULT 0, interval_length integer DEFAULT 1000)

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
   v_measure_start  integer := start;
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
  RAISE EXCEPTION 'Input downstream_route_measure value does not exist in FWA';
END IF;


RETURN QUERY

WITH intervals AS

(SELECT
  v_blkey as blue_line_key,
  generate_series(0, v_measure_max / v_interval) as n,
  generate_series(v_measure_start, v_measure_max, v_interval) as downstream_route_measure
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

COMMENT ON FUNCTION postgisftw.fwa_IndexPoint IS 'Return a point on the stream network based on the location provided by blue_line_key and downstream_route_measure'