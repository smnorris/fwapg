#!/bin/bash
set -euxo pipefail

PSQL="psql $DATABASE_URL -v ON_ERROR_STOP=1"

# a minimal bcfishpass load
# just wcrp watershed groups
WSD_GROUPS="ATNA BELA BONP BOWR BULK CARR COTR DRIR ELKR GUIC HORS LDEN LNIC LTRE MIDR MORR MSKE NECL NICL QUES SHUL STUL STUR SUST TAKL UDEN USHU USKE UTRE"
WSD_IN=$(echo "$WSD_GROUPS" | sed "s/ /','/g")
WSD_IN="'$WSD_IN'"

# ---------------------
# load provincial tables with column watershed_group_code
# do not bother loading per watershed group chunk, just select subset of records to load
# ---------------------
tables=(
  assessment_watersheds_poly
  lakes_poly
  manmade_waterbodies_poly
  rivers_poly
  watershed_groups_poly
  watersheds_xborder_poly
  wetlands_poly
)

for table in "${tables[@]}"; do
  $PSQL -c "truncate whse_basemapping.fwa_$table"
  ogr2ogr \
    -f PostgreSQL \
    PG:$DATABASE_URL \
    --config PG_USE_COPY YES \
    -append \
    -update \
    -preserve_fid \
    -nln whse_basemapping.fwa_$table \
    -where "WATERSHED_GROUP_CODE IN ($WSD_IN)" \
    /vsicurl/https://nrs.objectstore.gov.bc.ca/bchamp/fwapg/fwa_$table.parquet
done

# ---------------------
# streams are loaded to a temp table (for adding measures to the geometries)
# read each partition separately rather than using -where 
# (and using where on the partitioned data does not work unless downloading files or using /vsis3/)
# ---------------------
$PSQL -c "truncate whse_basemapping.fwa_stream_networks_sp;"
for WSG in $WSD_GROUPS; do
  ogr2ogr \
    -f PostgreSQL \
    PG:$DATABASE_URL \
    --config PG_USE_COPY YES \
    -preserve_fid \
    -overwrite \
    -lco GEOMETRY_NAME=geom \
    -nln fwapg.fwa_stream_networks_sp \
    /vsicurl/https://nrs.objectstore.gov.bc.ca/bchamp/fwapg/fwa_stream_networks_sp/$WSG.parquet
  $PSQL -f load/fwa_stream_networks_sp.sql  # load to output table, drop temp table
done

# ---------------------
# load non-spatial csv tables with COPY
# ---------------------
tables=(
  edge_type_codes
  streams_20k_50k
  waterbodies_20k_50k
  waterbody_type_codes
  watershed_type_codes
)
for table in "${tables[@]}"; do
  $PSQL -c "truncate whse_basemapping.fwa_$table"
  $PSQL -c "\copy whse_basemapping.fwa_$table FROM PROGRAM 'curl -s https://nrs.objectstore.gov.bc.ca/bchamp/fwapg/fwa_$table.csv.gz | gunzip' delimiter ',' csv header"
done

# ---------------------
# apply fixes that have not yet made it in to data source
# ---------------------
$PSQL -f fixes/fixes.sql

# ---------------------
# load smaller value added tables
# ---------------------
tables=(
  approx_borders
  basins_poly
  bcboundary
  named_streams
  stream_networks_order_max
  waterbodies
)
for table in "${tables[@]}"; do
  echo "Loading whse_basemapping.fwa_$table"
  $PSQL -f load/fwa_$table.sql
done

# ---------------------
# load larger value added tables
# ---------------------
tables=(
  stream_networks_order_parent
  streams_watersheds_lut
)
for table in "${tables[@]}"; do
  echo "Loading whse_basemapping.fwa_$table"
  $PSQL -c "truncate whse_basemapping.fwa_$table"
  for wsg in $WSD_GROUPS; do
    echo $wsg
    $PSQL -f load/fwa_$table.sql -v wsg=$wsg
  done
done

# ---------------------
# load xborder watersheds into the general watersheds table
# ---------------------
$PSQL -f load/fwa_watersheds_xborder_poly.sql

# ---------------------
# for larger lookups/datasets (generated via scripts in /extras), download cached pre-processed data)
# todo - cache these as parquet and load only groups of interest
# ---------------------
tables=(
  fwa_stream_networks_channel_width
  fwa_stream_networks_discharge
  fwa_assessment_watersheds_lut
  fwa_assessment_watersheds_streams_lut
  fwa_waterbodies_upstream_area
  fwa_watersheds_upstream_area
  fwa_stream_networks_mean_annual_precip
  fwa_streams_pse_conservation_units_lut
)
for table in "${tables[@]}"; do
  echo $table
  $PSQL -c "truncate whse_basemapping.$table"
  $PSQL -c "\copy whse_basemapping.$table FROM PROGRAM 'curl -s https://nrs.objectstore.gov.bc.ca/bchamp/fwapg/$table.csv.gz | gunzip' delimiter ',' csv header"
done

# materialize above data to whse_basemapping.fwa_streams, holding the value-added data (for fast upstr/dnstr queries)
$PSQL -f load/fwa_streams.sql

# clean up
$PSQL -c "VACUUM ANALYZE"