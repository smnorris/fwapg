--DROP FUNCTION fwa_networktrace(integer, double precision, integer, double precision, double precision, double precision);
-- -------------------------------------------------------------------------------------------------------------------------
-- FWA_NetworkTrace
-- Return stream network between two locations.
-- (breaking stream at given locations if locations are farther from existing endpoints than the provided tolerance)
-- -------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION whse_basemapping.FWA_NetworkTrace(
  blue_line_key_a integer,
  measure_a float,
  blue_line_key_b integer,
  measure_b float,
  tolerance float default 1,
  aggregate_path boolean default true
)

RETURNS TABLE (
  linear_feature_id        bigint                      ,
  edge_type                integer                     ,
  blue_line_key            integer                     ,
  watershed_key            integer                     ,
  wscode                   ltree                       ,
  localcode                ltree                       ,
  watershed_group_code     character varying(4)        ,
  downstream_route_measure double precision            ,
  upstream_route_measure   double precision            ,
  length_metre             double precision            ,
  waterbody_key            integer                     ,
  gnis_name                character varying(80)       ,
  stream_order             integer                     ,
  stream_magnitude         integer                     ,
  feature_code             character varying(10)       ,
  gradient                 double precision            ,
  left_right_tributary     character varying(7)        ,
  stream_order_parent      integer                     ,
  stream_order_max         integer                     ,
  upstream_area_ha         double precision            ,
  map_upstream             integer                     ,
  channel_width            double precision            ,
  channel_width_source     text                        ,
  mad_m3s                  double precision            ,
  geom                     geometry(LineStringZM,3005)
)

AS

$$

DECLARE
   v_blkey_a    integer := blue_line_key_a;
   v_measure_a  float   := measure_a;
   v_blkey_b    integer := blue_line_key_b;
   v_measure_b  float   := measure_b;
   v_tolerance  float   := tolerance;
   v_aggregate_path boolean := aggregate_path;

BEGIN

RETURN QUERY

-- trace downstream from both locations, the portion of the
-- traces that are not common to both is the path between the points

-- return source features
WITH p1 AS (
  SELECT *
  FROM fwa_downstreamtrace(v_blkey_a, v_measure_a, v_tolerance)
),

p2 AS (
  SELECT * 
  FROM fwa_downstreamtrace(v_blkey_b, v_measure_b, v_tolerance)
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

) AS f
WHERE f.blue_line_key = f.watershed_key -- do not return side channels, just the network path
ORDER BY wscode DESC, localcode DESC, downstream_route_measure DESC;


-- return a single line (aggregate the geometries)

END

$$
LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION whse_basemapping.FWA_NetworkTrace IS 'Return stream network path between the provided locations';



-- select * from fwa_networktrace(356135133, 200, 356364114, 96830)