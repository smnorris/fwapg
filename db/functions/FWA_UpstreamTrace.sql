--DROP FUNCTION fwa_upstreamtrace(integer,double precision,double precision)
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

$$
LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION whse_basemapping.FWA_UpstreamTrace IS 'Return stream network upstream of provided location';



