/*
FWA_Upstream() - return features upstream.

Has two formats:

1. FWA_Upstream(
      ltree wscode_a,
      ltree localcode_a,
      ltree wscode_b,
      ltree localcode_b
   )

Provided two sets of watershed/local codes (a and b), compare the codes and
return TRUE when the codes for b are upstream of the codes for a.
Note that TRUE is returned if the codes are equivalent.

eg:

# SELECT FWA_Upstream('100.100000'::ltree, '100.100000'::ltree,
                      '100.100000.000100'::ltree, '100.100000.000100'::ltree);
 fwa_upstream
--------------
 t
(1 row)

# SELECT FWW_Upstream('100.100000'::ltree, '100.100000'::ltree,
                      '100.100000'::ltree, '100.100000'::ltree);
 fwa_upstream
--------------
 t
(1 row)

2. FWA_Upstream(
    integer blue_line_key_a,
    double precision downstream_route_measure_a,
    ltree wscode_ltree_a,
    ltree localcode_ltree_a,
    integer blue_line_key_b,
    double precision downstream_route_measure_b,
    ltree wscode_ltree_b,
    ltree localcode_ltree_b
   )

For linear comparisions - provided two sets of blue_line_key, downtream_route_measure and watershed codes,
(a and b), compare the values and return TRUE when the values for b are upstream
of the values for a.

*/

CREATE OR REPLACE FUNCTION FWA_Upstream(
    wscode_ltree_a ltree,
    localcode_ltree_a ltree,
    wscode_ltree_b ltree,
    localcode_ltree_b ltree
)

RETURNS boolean AS $$

SELECT
  -- Simple case, where watershed code and local code of (a) are equivalent.
  -- Return TRUE for all records in (b) that are children of (a)
    (wscode_ltree_a = localcode_ltree_a AND
    wscode_ltree_b <@ wscode_ltree_a)

  -- Where watershed code and local code of (a) are not equivalent, more
  -- comparison is required - the local codes must be compared:
  OR
    (
      wscode_ltree_a != localcode_ltree_a
      AND
      wscode_ltree_b <@ wscode_ltree_a
      AND
      (
       -- tributaries: watershed code of b > local code of a, and watershed code
       -- of b is not a child of local code a
          (wscode_ltree_b > localcode_ltree_a AND NOT
           wscode_ltree_b <@ localcode_ltree_a)
          OR
       -- side channels, higher up on the same stream:
       -- b is the same watershed code as a, but with larger local code
          (wscode_ltree_b = wscode_ltree_a AND
          localcode_ltree_b >= localcode_ltree_a)
      )
  )

$$
language 'sql' immutable parallel safe;


CREATE OR REPLACE FUNCTION fwa_upstream(
    blue_line_key_a integer,
    downstream_route_measure_a double precision,
    wscode_ltree_a ltree,
    localcode_ltree_a ltree,
    blue_line_key_b integer,
    downstream_route_measure_b double precision,
    wscode_ltree_b ltree,
    localcode_ltree_b ltree,
    tolerance double precision default .001
)

RETURNS boolean AS $$

SELECT
  -- b is a child of a, always
  wscode_ltree_b <@ wscode_ltree_a AND

    -- conditional upstream join logic, based on whether watershed codes are equivalent
  (
    CASE
       -- first, consider simple case - streams where wscode and localcode are equivalent
       WHEN
          wscode_ltree_a = localcode_ltree_a AND
          (
              -- on the same stream with equivalent blkeys and a larger measure
              -- (plus fudge factor)
              (blue_line_key_b = blue_line_key_a AND
               downstream_route_measure_a + tolerance < downstream_route_measure_b)

              -- Additionaly, include segments with equivalent codes but different blkeys.
              -- This is rare (n=762), covering the case of selecting upstream of a
              -- distributary. I'm not sure why they are included, results don't look good
              -- so commenting out for now.

              -- OR
              --(blue_line_key_b != blue_line_key_a)
          )
       THEN TRUE

       -- next, the more complicated case - where wscode and localcode are not equal
       WHEN wscode_ltree_a != localcode_ltree_a AND
          (
           -- higher up the blue line (plus fudge factor)
              (blue_line_key_b = blue_line_key_a AND
               downstream_route_measure_a + tolerance < downstream_route_measure_b)
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
        ELSE FALSE
    END
  )
$$
language 'sql' immutable parallel safe;