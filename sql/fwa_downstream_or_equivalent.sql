/*
FWA_downstream_or_equivalent(
  blue_line_key_a,
  downstream_route_measure_a,
  wscode_ltree_a,
  localcode_ltree_a,
  blue_line_key_b,
  downstream_route_measure_b,
  wscode_ltree_b,
  localcode_ltree_b,
)

Provided two sets of blue_line_key, downtream_route_measure and watershed codes,
(a and b), compare the values and return TRUE when the values for b are downstream
of the values for a or at the same locaiont. The tolerance specifies how close
*on the same blueline* a record must be to be considered at equivalent location.

*/

CREATE OR REPLACE FUNCTION fwa_downstream_or_equivalent(
    blue_line_key_a integer,
    downstream_route_measure_a double precision,
    wscode_ltree_a ltree,
    localcode_ltree_a ltree,
    blue_line_key_b integer,
    downstream_route_measure_b double precision,
    wscode_ltree_b ltree,
    localcode_ltree_b ltree,
    tolerance double precision default .01
)

RETURNS boolean AS $$

SELECT
-- criteria 1 - on the same stream and lower down or at the same measure (+/- given tolerance)
(
    blue_line_key_a = blue_line_key_b AND
    (
      downstream_route_measure_a > downstream_route_measure_b OR
      abs(downstream_route_measure_a - downstream_route_measure_b) < tolerance
    )
)
OR
-- criteria 2 - watershed code a is a descendant of watershed code b
    (
        wscode_ltree_a <@ wscode_ltree_b AND
        (
            -- AND localcode of a is bigger than localcode of b at given level
            subltree(
                localcode_ltree_a,
                0,
                nlevel(localcode_ltree_b)
            ) > localcode_ltree_b
            -- OR, where b's wscode and localcode are equivalent
            -- (ie, at bottom segment of a given watershed code)
            -- but excluding records in a and b on same stream
            OR (
                wscode_ltree_b = localcode_ltree_b AND
                wscode_ltree_a != wscode_ltree_b
            )
            -- OR any missed side channels on the same watershed code
            OR (
                wscode_ltree_a = wscode_ltree_b AND
                blue_line_key_a != blue_line_key_b
              AND localcode_ltree_a > localcode_ltree_b)
            )
    )

$$
language 'sql' immutable parallel safe;




