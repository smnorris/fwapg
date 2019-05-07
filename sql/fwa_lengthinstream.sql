-- fwa_lengthinstream()

-- Return length of stream between two points

CREATE OR REPLACE FUNCTION fwa_lengthinstream(
    blkey_a integer,
    measure_a double precision,
    blkey_b integer,
    measure_b double precision,
    padding numeric DEFAULT .001
)

RETURNS double precision AS $$

-- find the watershed / local codes of starting (lower) point (a)
with bottom as (
  SELECT 1 as k,
    linear_feature_id,
    blue_line_key,
    wscode_ltree,
    localcode_ltree,
    downstream_route_measure,
    length_metre
  FROM whse_basemapping.fwa_stream_networks_sp
  WHERE blue_line_key = blkey_a
  -- use zero measure when measure minus padding is negative
  AND downstream_route_measure <= GREATEST(0::float, (measure_a - padding)::float)
  -- do not compute anything for null local codes, we don't know where they are
  AND localcode_ltree IS NOT NULL AND localcode_ltree != ''
  ORDER BY downstream_route_measure desc
  LIMIT 1
),

-- find the watershed / local codes of ending (higher) point (b)
top as
(
  SELECT 1 as k,
    linear_feature_id,
    blue_line_key,
    wscode_ltree,
    localcode_ltree,
    downstream_route_measure,
    length_metre
  FROM whse_basemapping.fwa_stream_networks_sp
  WHERE blue_line_key = blkey_b
  -- use zero measure when measure minus padding is negative
  AND downstream_route_measure <= GREATEST(0::float, (50 - padding)::float)
  -- do not compute anything for null local codes, we don't know where they are
  AND localcode_ltree IS NOT NULL AND localcode_ltree != ''
  ORDER BY downstream_route_measure desc
  LIMIT 1
),

-- Find all stream segments between bottom and top by searching upstream of
-- bottom and downstream of top. We could find the instream length by subtracting
-- downstream bottom from downstream top, but that doesn't ensure that the
-- points actually have this relationship

instream as
(
  SELECT
    1 as k,
    SUM(CASE WHEN str.length_metre IS NULL THEN 0
             ELSE str.length_metre
        END) as length_metre
  FROM
     whse_basemapping.fwa_stream_networks_sp str

  -- DOWNSTREAM JOIN
  INNER JOIN top ON
    (
      -- donwstream criteria 1 - same blue line, lower measure
      (str.blue_line_key = top.blue_line_key AND
       str.downstream_route_measure <= top.downstream_route_measure)
      OR
      -- criteria 2 - watershed code a is a child of watershed code b
      (str.wscode_ltree @> top.wscode_ltree
          AND (
               -- AND local code is lower
               str.localcode_ltree < subltree(top.localcode_ltree, 0, nlevel(str.localcode_ltree))
               -- OR wscode and localcode are equivalent
               OR str.wscode_ltree = str.localcode_ltree
               -- OR any missed side channels on the same watershed code
               OR (str.wscode_ltree = top.wscode_ltree AND
                   str.blue_line_key != top.blue_line_key AND
                   str.localcode_ltree < top.localcode_ltree)
               )
      )
  )

  -- UPSTREAM JOIN
  INNER JOIN bottom ON
    -- b is a child of a, always
    str.wscode_ltree <@ bottom.wscode_ltree
    -- never return the start or finish segments, they are added at the end
  AND
      -- conditional upstream join logic, based on whether watershed codes are equivalent
    CASE
      -- first, consider simple case - streams where wscode and localcode are equivalent
      -- this is all segments with equivalent bluelinekey and a larger measure
      -- (plus fudge factor)
       WHEN
          bottom.wscode_ltree = bottom.localcode_ltree AND
          (
              (str.blue_line_key <> bottom.blue_line_key OR
               str.downstream_route_measure > bottom.downstream_route_measure + padding)
          )
       THEN TRUE
       -- next, the more complicated case - where wscode and localcode are not equal
       WHEN
          bottom.wscode_ltree != bottom.localcode_ltree AND
          (
           -- higher up the blue line (plus fudge factor)
              (str.blue_line_key = bottom.blue_line_key AND
               str.downstream_route_measure > bottom.downstream_route_measure + padding)
              OR
           -- tributaries: b wscode > a localcode and b wscode is not a child of a localcode
              (str.wscode_ltree > bottom.localcode_ltree AND
               NOT str.wscode_ltree <@ bottom.localcode_ltree)
              OR
           -- capture side channels: b is the same watershed code, with larger localcode
              (str.wscode_ltree = bottom.wscode_ltree
               AND str.localcode_ltree >= bottom.localcode_ltree)
          )
        THEN TRUE
    END
  WHERE
    str.linear_feature_id != top.linear_feature_id AND
    str.linear_feature_id != bottom.linear_feature_id

)


SELECT
  CASE
    -- when points are on the same stream, just return the difference of the measures
    -- **Actually, no - we always want to use everything, so that side channels are included!**
    WHEN b.blue_line_key = t.blue_line_key
    THEN measure_b - measure_a
    -- otherwise, add things up
    ELSE
      (b.length_metre - (measure_a - b.downstream_route_measure)) + -- bottom segment
      (measure_b - t.downstream_route_measure) + -- top segment
      + i.length_metre -- instream length
  END as length_instream
FROM instream i
LEFT OUTER JOIN bottom b ON i.k = b.k
LEFT OUTER JOIN top t on i.k = t.k

$$
language 'sql' immutable strict parallel safe;