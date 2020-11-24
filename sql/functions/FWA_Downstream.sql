/*
FWA_Downstream() - return features downstream.

Has two formats:

1. FWA_Downstream(
      ltree wscode_a,
      ltree localcode_a,
      ltree wscode_b,
      ltree localcode_b
   )

Used for polygon features (where blue_line_key and measures are not present).
Provided two sets of watershed/local codes (a and b), compare the codes and
return TRUE when the codes for b are downstream of the codes for a.

eg

# SELECT FWA_Downstream('100.100000.000100'::ltree, '100.100000.000100'::ltree,
                        '100.100000'::ltree, '100.100000'::ltree);
 fwa_downstream
--------------
 t
(1 row)


2. FWA_Downstream(
     integer blue_line_key_a,
     double precision downstream_route_measure_a,
     double precision upstream_route_measure_a,
     ltree wscode_ltree_a,
     ltree localcode_ltree_a,
     integer blue_line_key_b,
     double precision downstream_route_measure_b,
     ltree wscode_ltree_b,
     ltree localcode_ltree_b,
     double precision tolerance
   )

Used for linear features with blue_line_key and measure.
Provided two sets of blue_line_key, downtream_route_measure and watershed codes,
(a and b), compare the values and return TRUE when the values for b are downstream
of the values for a. The tolerance specifies how much to nudge measure a downstream
in order to avoid returning records in b with equivalent bluelinekey/measure.

3. FWA_Downstream(
     integer blue_line_key_a,
     double precision downstream_route_measure_a,
     ltree wscode_ltree_a,
     ltree localcode_ltree_a,
     integer blue_line_key_b,
     double precision downstream_route_measure_b,
     ltree wscode_ltree_b,
     ltree localcode_ltree_b,
     double precision tolerance
   )
Same as 2, but for comparing points only.
*/

CREATE OR REPLACE FUNCTION FWA_Downstream(
    wscode_ltree_a ltree,
    localcode_ltree_a ltree,
    wscode_ltree_b ltree,
    localcode_ltree_b ltree
)

RETURNS boolean AS $$

SELECT
-- watershed code a is a descendant of watershed code b
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
  )

$$
language 'sql' immutable parallel safe;



CREATE OR REPLACE FUNCTION FWA_Downstream(
    blue_line_key_a integer,
    downstream_route_measure_a double precision,
    upstream_route_measure_a double precision,
    wscode_ltree_a ltree,
    localcode_ltree_a ltree,
    blue_line_key_b integer,
    downstream_route_measure_b double precision,
    wscode_ltree_b ltree,
    localcode_ltree_b ltree,
    include_equivalents boolean default False,
    tolerance double precision default .001
)

RETURNS boolean AS $$



  SELECT

    CASE WHEN include_equivalents IS False THEN
    -- criteria 1 - on the same stream and lower down (minus tolerance/fudge factor)
    -- the tolerance value nudges record a down slightly so that equivalent/near equivalent features are not returned
        (
            blue_line_key_a = blue_line_key_b AND
            downstream_route_measure_b <= downstream_route_measure_a - tolerance

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

  ELSE

    -- criteria 1 - on the same stream and lower down or in the same position
    -- the tolerance value is how far the features can be apart to be considered at the same spot
    (
      blue_line_key_a = blue_line_key_b AND
      (
        downstream_route_measure_b < downstream_route_measure_a  OR
        abs(downstream_route_measure_a - downstream_route_measure_b) <= tolerance
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

END

$$
language 'sql' immutable parallel safe;

CREATE OR REPLACE FUNCTION FWA_Downstream(
    blue_line_key_a integer,
    downstream_route_measure_a double precision,
    wscode_ltree_a ltree,
    localcode_ltree_a ltree,
    blue_line_key_b integer,
    downstream_route_measure_b double precision,
    wscode_ltree_b ltree,
    localcode_ltree_b ltree,
    include_equivalents boolean default False,
    tolerance double precision default .001
)

RETURNS boolean AS $$

SELECT
  FWA_Downstream(
    blue_line_key_a,
    downstream_route_measure_a,
    downstream_route_measure_a,
    wscode_ltree_a,
    localcode_ltree_a,
    blue_line_key_b,
    downstream_route_measure_b,
    wscode_ltree_b,
    localcode_ltree_b,
    include_equivalents,
    tolerance
  )

$$
language 'sql' immutable parallel safe;
