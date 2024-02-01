-- Calculate the average channel width of stream segments for main flow of double line rivers.
-- (where stream segment = distinct linear_feature_id)
-- To calculate average, measure at 30 points along the line segment

WITH channel_points AS
(
SELECT row_number() over(partition by linear_feature_id) as id, * FROM
  (
  SELECT
    linear_feature_id,
    blue_line_key,
    waterbody_key,
    watershed_group_code,
    (ST_Dump(ST_LineInterpolatePoints(geom, .033333))).geom as geom
  FROM whse_basemapping.fwa_stream_networks_sp
  WHERE edge_type = 1250                      -- main flow only, do not consider side channels
  AND watershed_group_code = :'wsg'
  --AND length_metre > 25
  ORDER BY downstream_route_measure) as p
),

-- find closest right bank (or right bank of closest island)
right_bank AS
 ( SELECT
    pt.linear_feature_id,
    pt.id,
    pt.blue_line_key,
    pt.watershed_group_code,
    pt.geom as midpoint_geom,
    nn.distance_to_pt,
    nn.geom
  FROM channel_points pt
  CROSS JOIN LATERAL
  (SELECT
     lb.linear_feature_id,
     lb.geom,
     ST_Distance(lb.geom, pt.geom) as distance_to_pt
    FROM whse_basemapping.fwa_linear_boundaries_sp AS lb
    WHERE lb.waterbody_key = pt.waterbody_key
    AND lb.edge_type IN (1800, 1825, 1900)
    ORDER BY lb.geom <-> pt.geom
    LIMIT 1) as nn
  WHERE nn.distance_to_pt < 4000
),

-- find left bank (or left bank of closest island)
left_bank AS
 ( SELECT
    pt.linear_feature_id,
    pt.id,
    pt.blue_line_key,
    nn.distance_to_pt,
    nn.geom
  FROM channel_points pt
  CROSS JOIN LATERAL
  (SELECT
     lb.linear_feature_id,
     lb.geom,
     ST_Distance(lb.geom, pt.geom) as distance_to_pt
    FROM whse_basemapping.fwa_linear_boundaries_sp AS lb
    WHERE lb.waterbody_key = pt.waterbody_key
    AND lb.edge_type IN (1850, 1875, 1950)
    ORDER BY lb.geom <-> pt.geom
    LIMIT 1) as nn
  WHERE nn.distance_to_pt < 4000
),

-- calculate distance to each bank and add distances together
widths AS
(SELECT
  r.linear_feature_id,
  r.watershed_group_code,
  r.distance_to_pt + l.distance_to_pt as channel_width_mapped
FROM right_bank r
INNER JOIN left_bank l ON r.linear_feature_id = l.linear_feature_id AND r.id = l.id)


INSERT INTO fwapg.channel_width_mapped
(
  linear_feature_id,
  watershed_group_code,
  channel_width_mapped,
  cw_stddev
)
SELECT
  linear_feature_id,
  watershed_group_code,
  ROUND((avg(channel_width_mapped))::numeric, 2) as channel_width_mapped,
  ROUND((stddev_pop(channel_width_mapped))::numeric, 2) as cw_stddev
FROM widths
GROUP BY linear_feature_id, watershed_group_code;