#!/bin/bash
set -euxo pipefail

PSQL="psql $DATABASE_URL -v ON_ERROR_STOP=1"
WSGS=$($PSQL -AXt -c "SELECT watershed_group_code FROM whse_basemapping.fwa_watershed_groups_poly")

# run the analysis per watershed group
parallel $PSQL -v wsg={1} -f sql/fwa_waterbodies_upstream_area.sql ::: $WSGS

# load temp per wsg tables to output table
$PSQL -c "DROP TABLE IF EXISTS whse_basemapping.fwa_waterbodies_upstream_area;
        CREATE TABLE whse_basemapping.fwa_waterbodies_upstream_area
        (linear_feature_id bigint,
         upstream_lake_ha double precision,
         upstream_reservoir_ha double precision,
         upstream_wetland_ha double precision)"

for WSG in $WSGS
do
  echo 'Loading '$WSG
  $PSQL -c "INSERT INTO whse_basemapping.fwa_waterbodies_upstream_area SELECT * FROM fwapg.fwa_waterbodies_upstream_area_"$WSG
done
$PSQL -c "ALTER TABLE whse_basemapping.fwa_waterbodies_upstream_area ADD PRIMARY KEY (linear_feature_id)"
$PSQL -c "ANALYZE whse_basemapping.fwa_waterbodies_upstream_area"

# drop the temp tables
for WSG in $WSGS
do
  $PSQL -c "DROP TABLE fwapg.fwa_waterbodies_upstream_area_"$WSG
done

echo 'fwa_waterbodies_upstream_area loaded successfully'

$PSQL -c "\copy whse_basemapping.fwa_waterbodies_upstream_area TO 'fwa_waterbodies_upstream_area.csv' DELIMITER ',' CSV HEADER;"
zip -r fwa_waterbodies_upstream_area.zip fwa_waterbodies_upstream_area.csv
rm fwa_waterbodies_upstream_area.csv
echo 'fwa_waterbodies_upstream_area dumped to zipped csv'
