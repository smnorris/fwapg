-- Crude tests, all should return true

-- watershed code comparisons
SELECT FWA_Upstream(
  '100.100000'::ltree,
  '100.100000'::ltree,
  '100.100000.000100'::ltree,
  '100.100000.000100'::ltree
) as result;

SELECT FWA_Upstream(
  '100.100000.000100'::ltree,
  '100.100000.000100'::ltree,
  '100.100000'::ltree,
  '100.100000'::ltree
) = false as result;

SELECT FWA_Upstream(
  '930.079351'::ltree,
  '930.079351.290329'::ltree,
  '930.079351.500724'::ltree,
  '930.079351.500724'::ltree
) as result;

SELECT FWA_Upstream(
  '930.079351'::ltree,
  '930.079351.290329'::ltree,
  '930.079351.290329'::ltree,
  '930.079351.290329'::ltree
) = false as result;

-- watershed code and meausre comparisons
SELECT FWA_Upstream(
    354133645,
    100,
    '930.079351'::ltree,
    '930.079351'::ltree,
    354133645,
    150,
    '930.079351'::ltree,
    '930.079351'::ltree
) as result;

SELECT FWA_Upstream(
    354133645,
    100,
    '930.079351'::ltree,
    '930.079351'::ltree,
    354133645,
    75,
    '930.079351'::ltree,
    '930.079351'::ltree
) = false as result;

SELECT FWA_Upstream(
    354133645,
    100,
    '930.079351'::ltree,
    '930.079351'::ltree,
    354133645,
    1900,
    '930.079351'::ltree,
    '930.079351.500724'::ltree
) as result;

SELECT FWA_Upstream(
    354133645,
    100,
    '930.079351'::ltree,
    '930.079351'::ltree,
    354131334,
    50,
    '930.079351.500724'::ltree,
    '930.079351.500724'::ltree
) as result;

SELECT FWA_Upstream(
    354133645,
    1900,
    '930.079351'::ltree,
    '930.079351.500724'::ltree,
    354131334,
    50,
    '930.079351.500724'::ltree,
    '930.079351.500724'::ltree
) is false as result;

-- try comparing a line to a point, the point is upstream of the line
-- if its measure is > than the lines upstream measure
SELECT FWA_Upstream(
    354133645,
    100,
    150,
    '930.079351'::ltree,
    '930.079351'::ltree,
    354133645,
    155,
    '930.079351'::ltree,
    '930.079351'::ltree
) as result;

-- a point on a line is not upstream of that line
SELECT FWA_Upstream(
    354133645,
    100,
    110,
    '930.079351'::ltree,
    '930.079351'::ltree,
    354133645,
    105,
    '930.079351'::ltree,
    '930.079351'::ltree
) is false as result;

-- tolerance is less than distance between measures, result is true
SELECT FWA_Upstream(
    354133645,
    100,
    '930.079351'::ltree,
    '930.079351'::ltree,
    354133645,
    101,
    '930.079351'::ltree,
    '930.079351'::ltree,
    False,
    .1
) as result;

-- tolerance is greater than distance between measures, result is false
SELECT FWA_Upstream(
    354133645,
    100,
    '930.079351'::ltree,
    '930.079351'::ltree,
    354133645,
    101,
    '930.079351'::ltree,
    '930.079351'::ltree,
    False,
    2
) is false as result;

-- We say that distributary branches are not upstream of one another.
SELECT FWA_Upstream(
  356327050,
  10,
  '100.458399.191116.121473'::ltree,
  '100.458399.191116.121473'::ltree,
  356000802,
  12,
  '100.458399.191116.121473'::ltree,
  '100.458399.191116.121473'::ltree
) is false as result;

/*
-- Find features with equivalent codes and non equal blkeys provincially
-- that would be similar to above test. (I'm presuming these are all distributaries)
SELECT * FROM
(SELECT wscode_ltree, localcode_ltree, count(distinct blue_line_key) as n
FROM whse_basemapping.fwa_stream_networks_sp
WHERE wscode_ltree = localcode_ltree
GROUP BY wscode_ltree, localcode_ltree
ORDER BY wscode_ltree, localcode_ltree)
as f WHERE n > 1;
*/

-- test point b at midpoint of line a
SELECT FWA_Upstream(
    354133645,
    10,
    20,
    '930.079351'::ltree,
    '930.079351'::ltree,
    354133645,
    15,
    '930.079351'::ltree,
    '930.079351'::ltree
) is false as result;

-- test point b at midpoint of line a, where returning equivalents
-- note that while these features are in the same spot, we don't consider them
-- equivalent
SELECT FWA_Upstream(
    354133645,
    10,
    20,
    '930.079351'::ltree,
    '930.079351'::ltree,
    354133645,
    15,
    '930.079351'::ltree,
    '930.079351'::ltree,
    True,
    .01
) is false as result;

-- up the equivalence tolerance, this returns true
-- for the same features
SELECT FWA_Upstream(
    354133645,
    10,
    20,
    '930.079351'::ltree,
    '930.079351'::ltree,
    354133645,
    15,
    '930.079351'::ltree,
    '930.079351'::ltree,
    True,
    5
) as result;

-- a more typical equivalency
SELECT FWA_Upstream(
    354133645,
    10,
    20,
    '930.079351'::ltree,
    '930.079351'::ltree,
    354133645,
    20.05,
    '930.079351'::ltree,
    '930.079351'::ltree,
    True,
    .1
) as result;

-- make sure we get the same result where wscode!=localcode
SELECT
FWA_Upstream(
    356533255,
    803.1354507440105,
    '300.602565.854327.993941.902282.132363.875881.788793'::ltree,
    '300.602565.854327.993941.902282.132363.875881.788793.103982'::ltree,
    356533255,
    803.136,
    '300.602565.854327.993941.902282.132363.875881.788793'::ltree,
    '300.602565.854327.993941.902282.132363.875881.788793.103982'::ltree,
    True,
    .1
) as result;

-- finally, not a true false test, but make sure that indexes are being used
-- This should be extremely fast (~14ms with indexes, 54s without)
SELECT
  ROUND((SUM(ST_Length(geom)) / 1000)::numeric, 2) as sooke_basin
FROM whse_basemapping.fwa_stream_networks_sp a
WHERE FWA_Upstream(354153927, 10, '930.023810'::ltree, '930.023810'::ltree, a.blue_line_key, a.downstream_route_measure, a.wscode_ltree, a.localcode_ltree);
