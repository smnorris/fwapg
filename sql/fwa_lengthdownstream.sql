-- fwa_lengthdownstream(blue_line_key, downstream_route_measure, padding)

-- Return sum of length of stream downstream of a point represented by
-- a blue line key and a downstream route measure

-- Note 1
-- All segments that are referancable on the network are included -
-- everything with a local watershed code. This will include side channels,
-- lake construction lines, subsurface flow - anything that has a local code.

-- Note 2
-- The function only sums the length of streams present in the database. Any
-- stream flow outside of BC will not be included in the total.

-- Note 3
-- The function will not return anything if provided  a location that does not
-- have a local code - this cannot be referenced on the network


CREATE OR REPLACE FUNCTION fwa_lengthdownstream(
    blkey integer,
    measure double precision,
    padding numeric DEFAULT .001
)

RETURNS double precision AS $$

with a as (
  SELECT 1 as k,
    linear_feature_id,
    blue_line_key,
    wscode_ltree,
    localcode_ltree,
    downstream_route_measure,
    length_metre
  FROM whse_basemapping.fwa_stream_networks_sp
  WHERE blue_line_key = blkey
  -- use zero measure when measure minus padding is negative
  AND downstream_route_measure <= GREATEST(0::float, (measure - padding)::float)
  -- do not compute anything for side channels, we don't know what is downstream
  AND localcode_ltree IS NOT NULL AND localcode_ltree != ''
  ORDER BY downstream_route_measure desc
  LIMIT 1

),

downstream as (
  SELECT
      1 as k,
      SUM(b.length_metre) as length_metre
   FROM
     whse_basemapping.fwa_stream_networks_sp b
   INNER JOIN a ON
    -- never return the stream segment at which we start, that is dealt with
    -- at the end
    b.linear_feature_id != a.linear_feature_id AND
    (
      -- donwstream criteria 1 - same blue line, lower measure
      (b.blue_line_key = a.blue_line_key AND
       b.downstream_route_measure <= a.downstream_route_measure)
      OR
      -- criteria 2 - watershed code a is a child of watershed code b
      (b.wscode_ltree @> a.wscode_ltree
          AND (
               -- AND local code is lower
               b.localcode_ltree < subltree(a.localcode_ltree, 0, nlevel(b.localcode_ltree))
               -- OR wscode and localcode are equivalent
               OR b.wscode_ltree = b.localcode_ltree
               -- OR any missed side channels on the same watershed code
               OR (b.wscode_ltree = a.wscode_ltree AND
                   b.blue_line_key != a.blue_line_key AND
                   b.localcode_ltree < a.localcode_ltree)
               )
      )
  )
)
-- add together length from segment on which measure falls,
-- plus everything downstream
  SELECT
    (measure - a.downstream_route_measure) +
    CASE WHEN downstream.length_metre IS NULL THEN 0
         ELSE downstream.length_metre
     END AS length_downstr
  FROM a left outer join downstream on a.k = downstream.k

$$
language 'sql' immutable strict parallel safe;
