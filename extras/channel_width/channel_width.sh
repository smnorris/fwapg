#!/bin/bash
set -euxo pipefail

PSQL="psql $DATABASE_URL -v ON_ERROR_STOP=1"

# ============
# calculate channel width - measured / mapped / modelled
# ============

WSG=$($PSQL -AXt -c "SELECT DISTINCT watershed_group_code FROM whse_basemapping.fwa_watershed_groups_poly ORDER BY watershed_group_code")

# -----------------------------------------------------------------------------------------
# MEASURED
# -----------------------------------------------------------------------------------------
# load to fwapg schema, these are just used temporarily
bcdata bc2pg --schema fwapg WHSE_FISH.FISS_STREAM_SAMPLE_SITES_SP
bcdata bc2pg --schema fwapg WHSE_FISH.PSCIS_ASSESSMENT_SVW
# bcfishpass crossings should be separated from streams to make this much more efficient
curl -o fptwg.gpkg.zip https://nrs.objectstore.gov.bc.ca/bchamp/freshwater_fish_habitat_accessibility_MODEL.gpkg.zip
ogr2ogr \
	-f PostgreSQL \
	PG:$DATABASE_URL \
	-nln fwapg.pscis_crossings \
	-overwrite \
	-where "crossing_source = 'PSCIS'" \
	/vsizip/fptwg.gpkg.zip \
	crossings
rm fptwg.gpkg.zip
# match stream sample sites to streams
$PSQL -f sql/fiss_stream_sample_sites_events.sql
# Now load the measured channel widths where we have them, averaging measurements on the same stream
$PSQL -f sql/channel_width_measured.sql


# -----------------------------------------------------------------------------------------
# MAPPED
# -----------------------------------------------------------------------------------------
$PSQL -c "DROP TABLE IF EXISTS fwapg.channel_width_mapped;"
$PSQL -c "CREATE TABLE fwapg.channel_width_mapped ( \
  linear_feature_id bigint, \
  watershed_group_code text, \
  channel_width_mapped numeric, \
  cw_stddev numeric, \
  UNIQUE (linear_feature_id) );"
# load each watershed group seperately, in parallel
parallel $PSQL -f sql/channel_width_mapped.sql -v wsg={1} ::: $WSG
$PSQL -c "CREATE INDEX ON fwapg.channel_width_mapped (linear_feature_id)"


# -----------------------------------------------------------------------------------------
# REPORT - report on measured and mapped data points for generating the model
# -----------------------------------------------------------------------------------------
$PSQL -f sql/channel_width_analysis.sql
$PSQL --csv -c "SELECT * FROM fwapg.channel_width_analysis" > channel_width_analysis.csv


# -----------------------------------------------------------------------------------------
# MODELLED
# -----------------------------------------------------------------------------------------
# run the model as a single query, it is quick
$PSQL -f sql/channel_width_modelled.sql


# -----------------------------------------------------------------------------------------
# OUTPUT TABLE
# -----------------------------------------------------------------------------------------
# combine the measured/mapped/modelled data into a single table for easy relating to streams table
$PSQL -c "truncate whse_basemapping.fwa_stream_networks_channel_width;"
parallel $PSQL -f sql/channel_width.sql -v wsg={1} ::: $WSG
# dump output to file
$PSQL -c "\copy whse_basemapping.fwa_stream_networks_channel_width TO 'fwa_stream_networks_channel_width.csv' DELIMITER ',' CSV HEADER;"
gzip fwa_stream_networks_channel_width.csv
