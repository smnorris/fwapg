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
groups=$(ogr2ogr -f CSV /vsistdout/ \
  /vsis3/bchamp/fwapg/fwa_watershed_groups_poly.parquet \
  -sql "select distinct watershed_group_code from fwa_watershed_groups_poly order by watershed_group_code" | tail -n +2
)
for table in "${tables[@]}"; do
  echo "Loading whse_basemapping.fwa_$table"
  for wsg in $groups; do
    echo $wsg
    $PSQL -f load/fwa_$table.sql -v wsg=$wsg
  done
done

# ---------------------
# load watershed boundaries for washington, idaho, montana and alaska
# ---------------------
curl -o /tmp/WBD_National_GDB.zip \
    https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.zip
$PSQL -c "truncate usgs.wbdhu12"
ogr2ogr \
  -f PostgreSQL \
  PG:$DATABASE_URL  \
  --config PG_USE_COPY YES \
  -t_srs EPSG:3005 \
  -nln usgs.wbdhu12 \
  -append \
  -where "states LIKE '%%CN%%' \
  OR states LIKE '%%WA%%' \
  OR states LIKE '%%AK%%' \
  OR states LIKE '%%ID%%' \
  OR states LIKE '%%MT%%'" \
  /tmp/WBD_National_GDB.zip \
  WBDHU12

# ---------------------
# For YT, NWT, AB watersheds, use hydrosheds https://www.hydrosheds.org/
# As source hydrosheds shapefiles must be manually downloaded, this uses a cached copy
# ---------------------
$PSQL -c "truncate hydrosheds.hybas_lev12_v1c"
ogr2ogr \
  -f PostgreSQL \
  PG:$DATABASE_URL \
  --config PG_USE_COPY YES \
  -t_srs EPSG:3005 \
  -nln hydrosheds.hybas_lev12_v1c \
  -append \
  -update \
  -preserve_fid \
  -where "hybas_id is not null" \
  -nlt PROMOTE_TO_MULTI \
  /vsizip/vsicurl/https://nrs.objectstore.gov.bc.ca/bchamp/fwapg/hydrosheds.gpkg.zip

# ---------------------
# for larger lookups/datasets (generated via scripts in /extras), download cached pre-processed data
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
$PSQL -f db/sql/extras.sql


# clean up
$PSQL -c "VACUUM ANALYZE"