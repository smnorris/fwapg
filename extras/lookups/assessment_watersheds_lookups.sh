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

# create and load output table
$PSQL -c "DROP TABLE IF EXISTS whse_basemapping.fwa_assessment_watersheds_lut;"
$PSQL -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_lut
(watershed_feature_id integer PRIMARY KEY,
assmnt_watershed_id integer,
watershed_group_code text,
watershed_group_id integer)"

for WSG in $WSGS
do
  echo 'Loading '$WSG
  psql -c "INSERT INTO whse_basemapping.fwa_assessment_watersheds_lut SELECT * FROM fwapg.fwa_assessment_watersheds_lut_"$WSG
done
$PSQL -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_lut (assmnt_watershed_id)"

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

$PSQL -c "DROP TABLE IF EXISTS whse_basemapping.fwa_assessment_watersheds_streams_lut;"
$PSQL -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_streams_lut
(linear_feature_id bigint primary key,
watershed_feature_id integer,
watershed_group_code text,
watershed_group_id integer);"

for WSG in $WSGS
do
  echo 'Loading '$WSG
  psql -c "INSERT INTO whse_basemapping.fwa_assessment_watersheds_streams_lut SELECT * FROM fwapg.fwa_assessment_watersheds_streams_lut_"$WSG
done
$PSQL -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_streams_lut (watershed_feature_id)"

# drop the temp tables
for WSG in $WSGS
do
  $PSQL -c "DROP TABLE fwapg.fwa_assessment_watersheds_streams_lut_"$WSG
done


# Above is almost comprehensive. One stream goes missing (it doesn't have the right watershed_group_code)
# SELECT
#   s.linear_feature_id
# FROM whse_basemapping.fwa_stream_networks_sp s
# LEFT OUTER JOIN whse_basemapping.fwa_assessment_watersheds_streams_lut l
# ON s.linear_feature_id = l.linear_feature_id
# WHERE s.edge_type != 6010
# AND l.linear_feature_id IS NULL;
#
#  linear_feature_id
# -------------------
#          832599689

$PSQL -c "INSERT INTO whse_basemapping.fwa_assessment_watersheds_streams_lut
   (linear_feature_id, watershed_feature_id, watershed_group_code, watershed_group_id)
    VALUES (832599689, 15559, 'TABR', 197)"


# dump lookups to file so they don't have to be regenerated every time a db is set up
$PSQL -c "\copy whse_basemapping.fwa_assessment_watersheds_streams_lut TO 'fwa_assessment_watersheds_streams_lut.csv' DELIMITER ',' CSV HEADER;"
$PSQL -c "\copy whse_basemapping.fwa_assessment_watersheds_lut TO 'fwa_assessment_watersheds_lut.csv' DELIMITER ',' CSV HEADER;"