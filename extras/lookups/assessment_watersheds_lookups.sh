#!/bin/bash
set -euxo pipefail

# Create and load lookup tables relating fundamental watersheds and streams to assessment watersheds
# (for quickly relating the tables without needing overlays)

PSQL="psql $DATABASE_URL -v ON_ERROR_STOP=1"
WSGS=$($PSQL -AXt -c "SELECT watershed_group_code FROM whse_basemapping.fwa_watershed_groups_poly")


# -----------------------------
# join assessment watersheds to fundamental watersheds
# -----------------------------

# run the analysis per watershed group
parallel $PSQL -f sql/fwa_assessment_watersheds_lut.sql -v wsg={1} ::: $WSGS

$PSQL -c "truncate whse_basemapping.fwa_assessment_watersheds_lut;"
for WSG in $WSGS
do
  echo 'Loading '$WSG
  $PSQL -c "INSERT INTO whse_basemapping.fwa_assessment_watersheds_lut SELECT * FROM fwapg.fwa_assessment_watersheds_lut_"$WSG
done

# drop the temp tables
for WSG in $WSGS
do
  $PSQL -c "DROP TABLE fwapg.fwa_assessment_watersheds_lut_"$WSG
done


# -----------------------------
# join assessment watersheds to streams
# -----------------------------

# run the analysis per watershed group
parallel $PSQL -f sql/fwa_assessment_watersheds_streams_lut.sql -v wsg={1} ::: $WSGS

$PSQL -c "truncate whse_basemapping.fwa_assessment_watersheds_streams_lut;"
for WSG in $WSGS
do
  echo 'Loading '$WSG
  $PSQL -c "INSERT INTO whse_basemapping.fwa_assessment_watersheds_streams_lut SELECT * FROM fwapg.fwa_assessment_watersheds_streams_lut_"$WSG
done
$PSQL -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_streams_lut (watershed_feature_id)"

# drop the temp tables
for WSG in $WSGS
do
  $PSQL -c "DROP TABLE fwapg.fwa_assessment_watersheds_streams_lut_"$WSG
done


# dump lookups to file so they don't have to be regenerated every time a db is set up
$PSQL -c "\copy whse_basemapping.fwa_assessment_watersheds_streams_lut TO 'fwa_assessment_watersheds_streams_lut.csv' DELIMITER ',' CSV HEADER;"
$PSQL -c "\copy whse_basemapping.fwa_assessment_watersheds_lut TO 'fwa_assessment_watersheds_lut.csv' DELIMITER ',' CSV HEADER;"

gzip fwa_assessment_watersheds_streams_lut.csv
gzip fwa_assessment_watersheds_lut.csv
