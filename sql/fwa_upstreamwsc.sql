/*
FWA_UpstreamWSC(fwa_watershed_code_a, local_watershed_code_a,
                 fwa_watershed_code_b, local_watershed_code_b)

Provided two sets of watershed/local codes (a and b), compare the codes and
return TRUE when the codes for b are upstream of the codes for a.
Note that TRUE is returned if the codes are equivalent.

eg:

fwakit=# SELECT FWA_UpstreamWSC('100.100000'::ltree, '100.100000'::ltree,
                                '100.100000.000100'::ltree, '100.100000.000100'::ltree);
 fwa_upstream
--------------
 t
(1 row)

fwakit=# SELECT FWW_UpstreamWSC('100.100000'::ltree, '100.100000'::ltree,
                                '100.100000'::ltree, '100.100000'::ltree);
 fwa_upstream
--------------
 t
(1 row)

Note that this function currently has a very large performance cost -
the indexes may not be used - it does not get 'inlined'
*/

CREATE OR REPLACE FUNCTION fwa_upstreamwsc(
    wscode_ltree_a ltree,
    localcode_ltree_a ltree,
    wscode_ltree_b ltree,
    localcode_ltree_b ltree
)

RETURNS boolean AS $$

SELECT true
WHERE
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