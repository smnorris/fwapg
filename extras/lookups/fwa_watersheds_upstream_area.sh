#!/bin/bash
set -euxo pipefail

PSQL="psql $DATABASE_URL -v ON_ERROR_STOP=1"
WSGS=$($PSQL -AXt -c "SELECT watershed_group_code FROM whse_basemapping.fwa_watershed_groups_poly")

# load watershed groups individually into seperate tables in fwapg schema
parallel $PSQL -XA -v wsg={1} -f sql/fwa_watersheds_upstream_area.sql ::: $WSGS

# combine temp tables into output table
$PSQL -c "truncate whse_basemapping.fwa_watersheds_upstream_area;"
for WSG in $WSGS
do
  echo 'Loading '$WSG
  $PSQL -c "INSERT INTO whse_basemapping.fwa_watersheds_upstream_area SELECT * FROM fwapg.fwa_watersheds_upstream_area_"$WSG
done
$PSQL -c "ANALYZE whse_basemapping.fwa_watersheds_upstream_area"

# drop the temp tables
for WSG in $WSGS
do
  $PSQL -c "DROP TABLE fwapg.fwa_watersheds_upstream_area_"$WSG
done

echo 'fwa_watersheds_upstream_area loaded successfully'

$PSQL -c "\copy whse_basemapping.fwa_watersheds_upstream_area TO 'fwa_watersheds_upstream_area.csv' DELIMITER ',' CSV HEADER;"
gzip fwa_watersheds_upstream_area.csv
echo 'fwa_watersheds_upstream_area dumped to zipped csv'
