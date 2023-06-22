-- -------------------------------------------------------------------------------------------------------------------------
-- FWA_UpstreamTrace
-- Return stream stream network upstream of provided location
-- (breaking stream at given location if location is farther from provided point than the provided tolerance)
-- NOTE - features with null local codes are not returned -
-- -------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION whse_basemapping.FWA_UpstreamTrace(
  start_blue_line_key integer,
  start_measure float,
  tolerance float default 1
)

RETURNS TABLE (
  linear_feature_id        bigint                      ,
  watershed_group_id       integer                     ,
  edge_type                integer                     ,
  blue_line_key            integer                     ,
  watershed_key            integer                     ,
  fwa_watershed_code       character varying(143)      ,
  local_watershed_code     character varying(143)      ,
  watershed_group_code     character varying(4)        ,
  downstream_route_measure double precision            ,
  length_metre             double precision            ,
  feature_source           character varying(15)       ,
  gnis_id                  integer                     ,
  gnis_name                character varying(80)       ,
  left_right_tributary     character varying(7)        ,
  stream_order             integer                     ,
  stream_order_parent      integer                     ,
  stream_order_max         integer                     ,
  stream_magnitude         integer                     ,
  waterbody_key            integer                     ,
  blue_line_key_50k        integer                     ,
  watershed_code_50k       character varying(45)       ,
  watershed_key_50k        integer                     ,
  watershed_group_code_50k character varying(4)        ,
  gradient                 double precision            ,
  feature_code             character varying(10)       ,
  wscode_ltree             ltree                       ,
  localcode_ltree          ltree                       ,
  upstream_route_measure   double precision            ,
  geom                     geometry(LineStringZM,3005)
)

AS

$$

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
    s.wscode_ltree,
    s.localcode_ltree,
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
    s.wscode_ltree,
    s.localcode_ltree,
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
  select a.*
  from whse_basemapping.fwa_stream_networks_sp a
  inner join segment b on fwa_upstream(
    b.blue_line_key,
    b.downstream_route_measure,
    b.wscode_ltree,
    b.localcode_ltree,
    a.blue_line_key,
    a.downstream_route_measure,
    a.wscode_ltree,
    a.localcode_ltree
    )
)

select
 s.linear_feature_id,
 s.watershed_group_id,
 s.edge_type,
 s.blue_line_key,
 s.watershed_key,
 s.fwa_watershed_code,
 s.local_watershed_code,
 s.watershed_group_code,
 c.downstream_route_measure,
 st_length(c.geom) as length_metre,
 s.feature_source,
 s.gnis_id,
 s.gnis_name,
 s.left_right_tributary,
 s.stream_order,
 s.stream_order_parent,
 s.stream_order_max,
 s.stream_magnitude,
 s.waterbody_key,
 s.blue_line_key_50k,
 s.watershed_code_50k,
 s.watershed_key_50k,
 s.watershed_group_code_50k,
 (round(((st_z(st_pointn(c.geom, '-1'::integer)) - st_z(st_pointn(c.geom, 1))) / st_length(c.geom))::numeric, 4)) as gradient,
 s.feature_code,
 s.wscode_ltree,
 s.localcode_ltree,
 s.upstream_route_measure,
 c.geom as geom
from cut c
inner join whse_basemapping.fwa_stream_networks_sp s
on c.linear_feature_id = s.linear_feature_id
union all
select
  u.linear_feature_id,
  u.watershed_group_id,
  u.edge_type,
  u.blue_line_key,
  u.watershed_key,
  u.fwa_watershed_code,
  u.local_watershed_code,
  u.watershed_group_code,
  u.downstream_route_measure,
  u.length_metre,
  u.feature_source,
  u.gnis_id,
  u.gnis_name,
  u.left_right_tributary,
  u.stream_order,
  u.stream_order_parent,
  u.stream_order_max,
  u.stream_magnitude,
  u.waterbody_key,
  u.blue_line_key_50k,
  u.watershed_code_50k,
  u.watershed_key_50k,
  u.watershed_group_code_50k,
  u.gradient,
  u.feature_code,
  u.wscode_ltree,
  u.localcode_ltree,
  u.upstream_route_measure,
  u.geom
from upstr u
order by wscode_ltree, localcode_ltree, downstream_route_measure;


END

$$
LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION whse_basemapping.FWA_UpstreamTrace IS 'Return stream network upstream of provided location';



