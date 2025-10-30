-- DROP FUNCTION whse_basemapping.fwa_networktrace(integer, double precision, integer, double precision, double precision, double precision);
-- -------------------------------------------------------------------------------------------------------------------------
-- FWA_NetworkTrace
-- Return stream network between two locations.
-- (breaking stream at given locations if locations are farther from existing endpoints than the provided tolerance)
-- -------------------------------------------------------------------------------------------------------------------------
-- DROP FUNCTION whse_basemapping.FWA_NetworkTrace(integer, float, integer, float, float);

CREATE OR REPLACE FUNCTION whse_basemapping.FWA_NetworkTrace(
  blue_line_key_a integer,
  measure_a float,
  blue_line_key_b integer,
  measure_b float,
  tolerance float default 1
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


$$
LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION whse_basemapping.FWA_NetworkTrace IS 'Return stream network path between the provided locations';


-- select * from fwa_networktrace(356135133, 200, 356364114, 96830)
-- select * from fwa_networktrace(354132308, 2000, 354154440, 37100)