#!/bin/bash
set -euxo pipefail

PSQL="psql $DATABASE_URL -v ON_ERROR_STOP=1"


# ---------------------
# load these directly from object storage parquet files
# ---------------------

tables=(
  assessment_watersheds_poly
  bays_and_channels_poly
  coastlines_sp
  glaciers_poly
  islands_poly
  lakes_poly
  manmade_waterbodies_poly
  named_point_features_sp
  named_watersheds_poly
  obstructions_sp
  rivers_poly
  watershed_groups_poly
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
    -dialect SQLite \
    -sql "SELECT * FROM fwa_$table ORDER BY RANDOM()" \
    /vsicurl/https://nrs.objectstore.gov.bc.ca/bchamp/fwapg/fwa_$table.parquet
done


# ---------------------
# for larger tables, download the file directly then load to postgres
# ---------------------

mkdir -p data
tables=(
  linear_boundaries_sp
  watersheds_poly
)
for table in "${tables[@]}"; do
  curl -o data/fwa_$table.parquet https://nrs.objectstore.gov.bc.ca/bchamp/fwapg/fwa_$table.parquet
  $PSQL -c "truncate whse_basemapping.fwa_$table"
  ogr2ogr \
    -f PostgreSQL \
    PG:$DATABASE_URL \
    --config PG_USE_COPY YES \
    -append \
    -update \
    -preserve_fid \
    -nln whse_basemapping.fwa_$table \
    -dialect SQLite \
    -sql "SELECT * FROM fwa_$table ORDER BY RANDOM()" \
    data/fwa_$table.parquet
done


# ---------------------
# streams are loaded to a temp table (for adding measures to the geometries)
# ---------------------

curl -o data/fwa_stream_networks_sp.parquet https://nrs.objectstore.gov.bc.ca/bchamp/fwapg/fwa_stream_networks_sp.parquet
$PSQL -c "drop table if exists fwapg.fwa_stream_networks_sp"
ogr2ogr \
  -f PostgreSQL \
  PG:$DATABASE_URL \
  --config PG_USE_COPY YES \
  -preserve_fid \
  -lco GEOMETRY_NAME=geom \
  -nln fwapg.fwa_stream_networks_sp \
  data/fwa_stream_networks_sp.parquet

$PSQL -f load/fwa_stream_networks_sp.sql  # load to output table


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

# clean up
$PSQL -c "VACUUM ANALYZE"