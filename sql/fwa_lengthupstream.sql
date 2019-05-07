-- fwa_lengthupstream(blue_line_key, downstream_route_measure, padding)

-- Return sum of length of stream upstream of a point represented by
-- a blue line key and a downstream route measure

-- Note 1
-- All segments that are referancable on the network are included -
-- everything with a local watershed code. This will include side channels,
-- lake construction lines, subsurface flow - anything that has a local code.

-- Note 2
-- The function only sums the length of streams present in the database. Any
-- stream flow outside of BC will not be included in the total.

-- Note 3
-- The function will not return anything if provided a location that does not
-- have a local code - this cannot be referenced on the network


CREATE OR REPLACE FUNCTION fwa_lengthupstream(
    blkey integer,
    measure double precision,
    padding numeric DEFAULT .001
)

RETURNS double precision AS $$

-- get the segment of interest
WITH a AS
  (SELECT * FROM whse_basemapping.fwa_stream_networks_sp
   WHERE
     blue_line_key = blkey
     AND downstream_route_measure <= (measure + padding)
     AND localcode_ltree IS NOT NULL AND localcode_ltree != ''
   ORDER BY downstream_route_measure DESC
   LIMIT 1),

-- find all streams upstream, returning the sum of the lengths
upstream AS
(
  SELECT
    -- if nothing is returned, convert it to zero
    SUM(CASE WHEN b.length_metre IS NULL THEN 0
             ELSE b.length_metre
        END) as length_metre
  FROM a
  LEFT OUTER JOIN whse_basemapping.fwa_stream_networks_sp b ON
    -- b is a child of a, always
    b.wscode_ltree <@ a.wscode_ltree
    -- never return the start segment, that is added at the end
  AND b.linear_feature_id != a.linear_feature_id
  AND
      -- conditional upstream join logic, based on whether watershed codes are equivalent
    CASE
      -- first, consider simple case - streams where wscode and localcode are equivalent
      -- this is all segments with equivalent bluelinekey and a larger measure
      -- (plus fudge factor)
       WHEN
          a.wscode_ltree = a.localcode_ltree AND
          (
              (b.blue_line_key <> a.blue_line_key OR
               b.downstream_route_measure > a.downstream_route_measure + padding)
          )
       THEN TRUE
       -- next, the more complicated case - where wscode and localcode are not equal
       WHEN
          a.wscode_ltree != a.localcode_ltree AND
          (
           -- higher up the blue line (plus fudge factor)
              (b.blue_line_key = a.blue_line_key AND
               b.downstream_route_measure > a.downstream_route_measure + padding)
              OR
           -- tributaries: b wscode > a localcode and b wscode is not a child of a localcode
              (b.wscode_ltree > a.localcode_ltree AND
               NOT b.wscode_ltree <@ a.localcode_ltree)
              OR
           -- capture side channels: b is the same watershed code, with larger localcode
              (b.wscode_ltree = a.wscode_ltree
               AND b.localcode_ltree >= a.localcode_ltree)
          )
        THEN TRUE
    END
)

-- add together length from segment on which measure falls, plus
-- everything upstream
  SELECT  (a.length_metre - (measure - a.downstream_route_measure)) + upstream.length_metre
  FROM a, upstream;

$$
language 'sql' immutable strict parallel safe;
