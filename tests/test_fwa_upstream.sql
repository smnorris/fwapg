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
