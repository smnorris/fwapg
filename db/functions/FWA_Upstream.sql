/*
FWA_Upstream() - return features upstream.

Has three formats:

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

For comparing point locations along the routes. Provided two sets of blue_line_key, downtream_route_measure and watershed codes,
(a and b), compare the values and return TRUE when the values for b are upstream
of the values for a.

3. FWA_Upstream(
    integer blue_line_key_a,
    double precision downstream_route_measure_a,
    double precision upstream_route_measure_a,
    ltree wscode_ltree_a,
    ltree localcode_ltree_a,
    integer blue_line_key_b,
    double precision downstream_route_measure_b,
    ltree wscode_ltree_b,
    ltree localcode_ltree_b
   )

Provided downstream and upstream measures for a, and downstream measure for b,
return TRUE when the values for b are upstream of the values for a.

*/


-- watershed code comparison only
CREATE OR REPLACE FUNCTION whse_basemapping.FWA_Upstream(
    wscode_ltree_a ltree,
    localcode_ltree_a ltree,
    wscode_ltree_b ltree,
    localcode_ltree_b ltree
)

RETURNS boolean AS $$

SET search_path TO public,whse_basemapping,usgs,hydrosheds;

SELECT
  -- Simple case, where watershed code and local code of (a) are equivalent.
  -- Return TRUE for all records in (b) that are children of (a)
    (wscode_ltree_a = localcode_ltree_a AND
    wscode_ltree_b <@ wscode_ltree_a AND
    localcode_ltree_b <@ localcode_ltree_a) -- checking local codes is redundant but this ensures invalid local codes are not matched

  -- Where watershed code and local code of (a) are not equivalent and wsc of b is child of wsc a,
  -- more comparison is required - the local codes must be compared.
  OR
    (
      wscode_ltree_a != localcode_ltree_a AND
      wscode_ltree_b <@ wscode_ltree_a AND
      (
       -- tributaries:
       --   - wsc of b is bigger than local code of a - the trib is upstream
       --   - wsc of b is not a child of local code a - exclude trib at the same position
       --   - local code b is child of wsc a (this should be true anyway but a check handles invalid codes)
          (wscode_ltree_b > localcode_ltree_a AND NOT
           wscode_ltree_b <@ localcode_ltree_a AND
           localcode_ltree_b <@ wscode_ltree_a AND
           localcode_ltree_b > localcode_ltree_a
      )
          OR
       -- side channels (higher up on the same stream)
       --
       --   - wsc of b is the same as wsc of a
       --   - local code b is larger than local code of a
          (
            wscode_ltree_b = wscode_ltree_a AND
            localcode_ltree_b >= localcode_ltree_a
          )

      )
  )

$$
language 'sql' immutable parallel safe;


-- linear comparisons
CREATE OR REPLACE FUNCTION whse_basemapping.FWA_Upstream(
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

RETURNS boolean language sql set search_path = public AS $$


SELECT
  -- b is a child of a, always
  wscode_ltree_b <@ wscode_ltree_a AND

    -- conditional upstream join logic, based on whether watershed codes are equivalent
  (
    CASE
       -- first, consider simple case - streams where wscode and localcode are equivalent
       WHEN include_equivalents IS False AND
          wscode_ltree_a = localcode_ltree_a AND
          (
              -- upstream tribs
              (blue_line_key_b != blue_line_key_a) OR

              -- on same blue line
              (blue_line_key_b = blue_line_key_a AND
               downstream_route_measure_b >= upstream_route_measure_a + tolerance)
          )
          -- exclude distributaries with equivalent codes and different blkeys
          AND NOT (
            wscode_ltree_a = wscode_ltree_b AND
            localcode_ltree_a = localcode_ltree_b AND
            blue_line_key_a != blue_line_key_b
          )
       THEN TRUE

       -- next, the more complicated case - where wscode and localcode are not equal
       WHEN include_equivalents IS False AND
         wscode_ltree_a != localcode_ltree_a AND
          (
                -- on same blue line
              (blue_line_key_b = blue_line_key_a AND
               downstream_route_measure_b >= upstream_route_measure_a + tolerance)
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

      -- run the same process, but return true for locations at the same measure
      -- (within tolerance)
       WHEN include_equivalents IS True AND
          wscode_ltree_a = localcode_ltree_a AND
          (
              -- upstream tribs
              (blue_line_key_b != blue_line_key_a) OR

              -- on same blue line
              (blue_line_key_b = blue_line_key_a AND
               (downstream_route_measure_b > upstream_route_measure_a OR
                abs(upstream_route_measure_a - downstream_route_measure_b) <= tolerance)
              )
          )
          -- exclude distributaries with equivalent codes and different blkeys
          AND NOT (
            wscode_ltree_a = wscode_ltree_b AND
            localcode_ltree_a = localcode_ltree_b AND
            blue_line_key_a != blue_line_key_b
          )
       THEN TRUE

       -- next, the more complicated case - where wscode and localcode are not equal
       WHEN include_equivalents IS True AND
         wscode_ltree_a != localcode_ltree_a AND
          (
              -- on same blue line
              (blue_line_key_b = blue_line_key_a AND
               (downstream_route_measure_b > upstream_route_measure_a OR
                abs(upstream_route_measure_a - downstream_route_measure_b) <= tolerance)
              )
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
immutable parallel safe;


-- shortcut for points, dnstr measure a and upstr measure are equivalent
CREATE OR REPLACE FUNCTION whse_basemapping.FWA_Upstream(
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

RETURNS boolean language sql set search_path = public AS $$

SELECT
  whse_basemapping.FWA_Upstream(
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
immutable parallel safe;


--COMMENT ON FUNCTION FWA_Upstream IS 'Compare input watershed codes and/or linear positions A and B, return TRUE if codes/positions A are upstream of codes/positions B';