#!/bin/bash
set -euxo pipefail

PSQL="psql $DATABASE_URL -v ON_ERROR_STOP=1"

$PSQL -c "create schema if not exists psf"

ogr2ogr \
  -f PostgreSQL \
  "PG:$DATABASE_URL" \
  -t_srs EPSG:3005 \
  -lco OVERWRITE=YES \
  -lco SCHEMA=psf \
  -lco GEOMETRY_NAME=geom \
  -nln pse_conservation_units \
  pse_conservation_units.gdb \
  pse_conservation_units

$PSQL -f sql/cu_planarized.sql

# this is not optimized, takes ~3-5hrs
$PSQL -f sql/cu_streams.sql

# dump to file and upload to object storage
$PSQL -c "\copy whse_basemapping.fwa_streams_pse_conservation_units_lut TO 'fwa_streams_pse_conservation_units_lut.csv' DELIMITER ',' CSV HEADER;"
gzip fwa_streams_pse_conservation_units_lut.csv
echo 'fwa_streams_pse_conservation_units_lut.csv dumped to gzipped csv'
