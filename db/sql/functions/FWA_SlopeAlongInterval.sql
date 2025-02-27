CREATE OR REPLACE FUNCTION whse_basemapping.FWA_SlopeAlongInterval(
    blue_line_key integer, 
    interval_length integer DEFAULT 100,
    distance_upstream integer DEFAULT 100,
    start_measure integer DEFAULT 0,
    end_measure integer DEFAULT NULL
)


RETURNS TABLE
    (
        idx                      integer,
        downstream_measure       numeric,
        downstream_z             numeric,
        upstream_measure         numeric,
        upstream_z               numeric,
        gradient                 numeric
    )

AS

$$

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

$$
LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION whse_basemapping.FWA_SlopeAlongInterval IS 'Return a table (n, downstream_route_measure, downstream_z, upstream_route_measure, upstream_z, gradient), measuring slope at equal intervals'