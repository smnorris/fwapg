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
SELECT fwa_upstream(
    354133645,
    100,
    '930.079351'::ltree,
    '930.079351'::ltree,
    354133645,
    150,
    '930.079351'::ltree,
    '930.079351'::ltree
) as result;

SELECT fwa_upstream(
    354133645,
    100,
    '930.079351'::ltree,
    '930.079351'::ltree,
    354133645,
    75,
    '930.079351'::ltree,
    '930.079351'::ltree
) = false as result;

SELECT fwa_upstream(
    354133645,
    100,
    '930.079351'::ltree,
    '930.079351'::ltree,
    354133645,
    1900,
    '930.079351'::ltree,
    '930.079351.500724'::ltree
) as result;

SELECT fwa_upstream(
    354133645,
    100,
    '930.079351'::ltree,
    '930.079351'::ltree,
    354131334,
    50,
    '930.079351.500724'::ltree,
    '930.079351.500724'::ltree
) as result;

SELECT fwa_upstream(
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
SELECT fwa_upstream(
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
SELECT fwa_upstream(
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

-- distributaries aren't upstream
SELECT fwa_upstream(
  356327050,
  10,
  '100.458399.191116.121473'::ltree,
  '100.458399.191116.121473'::ltree,
  356000802,
  12,
  '100.458399.191116.121473'::ltree,
  '100.458399.191116.121473'::ltree
) is false as result;
