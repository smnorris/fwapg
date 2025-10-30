-- QA for nicole

-- https://features.hillcrestgeo.ca/fwa/functions/postgisftw.fwa_networktraceagg/items.json?blue_line_key_a=356363121&measure_a=25191&blue_line_key_b=356362759&measure_b=21304

-- https://features.hillcrestgeo.ca/fwa/functions/postgisftw.fwa_networktraceagg/items.json?blue_line_key_a=356362521&measure_a=43756&blue_line_key_b=356362759&measure_b=98137




  -- trace downstream from both locations, the portion of the
  -- traces that are not common to both is the path between the points

  WITH t1 AS (
    SELECT 1 as id, *
    FROM fwa_downstreamtrace(356362521, 43756)
    WHERE blue_line_key = watershed_key
  ),

  t2 AS (
    SELECT 2 as id, *
    FROM fwa_downstreamtrace(356362759, 98137)
    WHERE blue_line_key = watershed_key
  ),

  -- if the origins are flow-connected (ie downstream/upstream of the other),
  -- the split source stream needs to be added to the result (the linear feature id
  -- is common to both traces and excluded below, but a portion of it needs to be included)
  remainder AS (
    SELECT
      s.linear_feature_id,
      s.edge_type,
      s.blue_line_key,
      s.watershed_key,
      s.wscode,
      s.localcode,
      s.watershed_group_code,
      least(t1.upstream_route_measure, t2.upstream_route_measure) as downstream_route_measure,
      greatest(t1.upstream_route_measure, t2.upstream_route_measure) as upstream_route_measure,
      greatest(t1.upstream_route_measure, t2.upstream_route_measure) - least(t1.upstream_route_measure, t2.upstream_route_measure) as length_metre,
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
      st_force3d(st_locatebetween(s.geom,
        least(t1.upstream_route_measure, t2.upstream_route_measure),
        greatest(t1.upstream_route_measure, t2.upstream_route_measure)
      ))  as geom
    FROM t1
    INNER JOIN t2 ON t1.linear_feature_id = t2.linear_feature_id
    AND t1.upstream_route_measure != t2.upstream_route_measure
    -- join to source streams so we don't have to compare the two geoms to find the full length segment
    INNER JOIN whse_basemapping.fwa_streams s ON s.linear_feature_id = t1.linear_feature_id
  ),

  t1_agg AS (
    SELECT
      t1.id,
      first(t1.blue_line_key) as from_blue_line_key,
      first(t1.upstream_route_measure) as from_measure,
      last(t1.blue_line_key) as to_blue_line_key,
      last(t1.downstream_route_measure) as to_measure,
      st_linemerge(st_union(t1.geom)) as geom
    FROM t1
    LEFT JOIN t2 ON t1.linear_feature_id = t2.linear_feature_id
    WHERE t2.linear_feature_id IS NULL
    GROUP BY t1.id
  ),

  t2_agg AS (
    SELECT
      t2.id,
      first(t2.blue_line_key) as from_blue_line_key,
      first(t2.upstream_route_measure) as from_measure,
      last(t2.blue_line_key) as to_blue_line_key,
      last(t2.downstream_route_measure) as to_measure,
      st_linemerge(st_union(t2.geom)) as geom
    FROM t2
    LEFT JOIN t1 ON t2.linear_feature_id = t1.linear_feature_id
    WHERE t1.linear_feature_id IS NULL
    GROUP BY t2.id
  ),

  -- determin which trace the remainder should be aggregated with
  r_agg as (
    select
      coalesce(t1_agg.id, t2_agg.id) as id,
      r.blue_line_key as from_blue_line_key,
      r.upstream_route_measure as from_measure,
      r.blue_line_key as to_blue_line_key,
      r.downstream_route_measure as to_measure,
      r.geom
    from remainder r
    left outer join t1_agg on round(r.upstream_route_measure) = round(t1_agg.to_measure)
    left outer join t2_agg on round(r.upstream_route_measure) = round(t2_agg.to_measure)
  )
  ,

  all_agg as (
    select * from t1_agg
    union all
    select * from t2_agg
    union all
    select * from r_agg
  )


select * from t1;
--  select
--    id,
--    first(from_blue_line_key) as from_blue_line_key,
--    first(from_measure) as from_measure,
--    last(to_blue_line_key) as to_blue_line_key,
--    last(to_measure) as to_measure,
--    ST_RemoveRepeatedPoints(st_linemerge(st_union(st_multi(geom), .01))) as geom
--  from all_agg
--  group by id
