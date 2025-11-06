with raw as (
  SELECT
    blue_line_key,
    linear_feature_id,
    edge_type,
    round(((ST_LineLocatePoint(geom, ST_PointN(geom, generate_series(1, ST_NPoints(geom) - 1))) * length_metre) + downstream_route_measure)::numeric, 2) as downstream_route_measure,
    round(ST_Z(ST_PointN(geom, generate_series(1, ST_NPoints(geom) - 1)))::numeric, 2) AS elevation
  FROM whse_basemapping.fwa_stream_networks_sp s
  WHERE blue_line_key = 356223113
  AND blue_line_key = watershed_key
  AND edge_type != 6010
  ORDER BY blue_line_key, downstream_route_measure
),

indexed as (
  select 
   row_number() over() as n, *
  from raw
),

profile as (
  SELECT
    n,
    linear_feature_id,
    edge_type,
    downstream_route_measure,
    elevation,
    --(lead(elevation) over (order by n)  - elevation) as rise,
    --(lead(downstream_route_measure) over (order by n) - downstream_route_measure) as run,
    round(((lead(elevation) over (order by n)  - elevation) / (lead(downstream_route_measure) over (order by n) - downstream_route_measure))::numeric, 4) as slope
  FROM indexed
)

-- drop final row (can't calculate slope above the final vertex)
select * from profile where slope is not null;