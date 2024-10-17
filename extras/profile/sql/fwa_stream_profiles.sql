insert into whse_basemapping.fwa_stream_profiles (
  blue_line_key,
  linear_feature_id,
  segment_id,
  downstream_route_measure,
  upstream_route_measure,
  downstream_elevation,
  upstream_elevation
)

-- extract coordinates from streams
with coordinates as (
  select
    blue_line_key,
    downstream_route_measure,
    linear_feature_id,
    edge_type,
    (st_dumppoints(geom)).path[1] as node_id,
    (st_dumppoints(geom)).geom as geom
  from whse_basemapping.fwa_stream_networks_sp
  where watershed_group_code = :'wsg'
),

-- extract elevation of each point and determine distances between each point
lengths as (
  select
    blue_line_key,
    downstream_route_measure,
    linear_feature_id,
    edge_type,
    node_id,
    st_z(geom) as elevation_from,
    st_z(lead(geom) OVER(partition by linear_feature_id ORDER BY node_id)) as elevation_to,
    st_distance(geom, lead(geom) OVER(partition by linear_feature_id ORDER BY node_id)) as length
  from coordinates
  order by blue_line_key, downstream_route_measure, node_id
),

-- derive measure of upstream point
-- drop duplicates at geometry endpoints (where length is 0)
-- drop the final vertex (where length is null)
tidy as (
  select
    linear_feature_id,
    node_id,
    blue_line_key,
    downstream_route_measure,
    edge_type,
    round((downstream_route_measure + sum(length) over (partition by linear_feature_id order by node_id))::numeric, 2) as upstream_route_measure,
    round(elevation_from::numeric, 2) as elevation_from,
    round(elevation_to::numeric, 2) as elevation_to
  from lengths
  where length !=0 and length is not null
  order by blue_line_key, downstream_route_measure, node_id
)

select
  blue_line_key,
  linear_feature_id,
  row_number() over() as segment_id,
  lag(upstream_route_measure, 1, 0) over (partition by blue_line_key order by downstream_route_measure, node_id) as downstream_route_measure,
  upstream_route_measure,
  elevation_from as downstream_elevation,
  elevation_to as upstream_elevation
from tidy
order by blue_line_key, downstream_route_measure, node_id;
