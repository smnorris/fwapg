/*
FWA_upstream_linear(
  blue_line_key_a,
  downstream_route_measure_a,
  fwa_watershed_code_a,
  local_watershed_code_a,
  fwa_watershed_code_b,
  local_watershed_code_b,
  blue_line_key_a,
  downstream_route_measure_a,
)

Provided two sets of blue_line_key, downtream_route_measure and watershed codes,
(a and b), compare the values and return TRUE when the values for b are upstream
of the values for a.

*/

CREATE OR REPLACE FUNCTION fwa_upstream_linear(
    blue_line_key_a integer,
    downstream_route_measure_a double precision,
    wscode_ltree_a ltree,
    localcode_ltree_a ltree,
    blue_line_key_b integer,
    downstream_route_measure_b double precision,
    wscode_ltree_b ltree,
    localcode_ltree_b ltree
)

RETURNS boolean AS $$

SELECT
    -- b is a child of a, always
  wscode_ltree_b <@ wscode_ltree_a

  AND
      -- conditional upstream join logic, based on whether watershed codes are equivalent
    CASE
      -- first, consider simple case - streams where wscode and localcode are equivalent
      -- this is all segments with equivalent bluelinekey and a larger measure
      -- (plus fudge factor)
       WHEN
          wscode_ltree_a = localcode_ltree_a AND
          (
              (blue_line_key_b <> blue_line_key_a OR
               downstream_route_measure_a < downstream_route_measure_b + .01)
          )
       THEN TRUE
       -- next, the more complicated case - where wscode and localcode are not equal
       WHEN
          wscode_ltree_a != localcode_ltree_a AND
          (
           -- higher up the blue line (plus fudge factor)
              (blue_line_key_b = blue_line_key_a AND
               downstream_route_measure_a < downstream_route_measure_b + .01 )
              OR
           -- tributaries: b wscode > a localcode and b wscode is not a child of a localcode
              (wscode_ltree_b > localcode_ltree_a AND
               NOT wscode_ltree_b <@ localcode_ltree_a)
              OR
           -- capture side channels: b is the same watershed code, with larger localcode
              (wscode_ltree_b = wscode_ltree_a
               AND localcode_ltree_b > localcode_ltree_a)
          )
        THEN TRUE
    END

$$
language 'sql' immutable parallel safe;

