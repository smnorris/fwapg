#!/bin/bash
set -euxo pipefail

psql -c "CREATE SCHEMA if not exists temp;"

# load watershed groups individually into seperate tables in temp schema
psql -AtX -P border=0,footer=off -c "SELECT watershed_group_code
      FROM whse_basemapping.fwa_watershed_groups_poly
      ORDER BY watershed_group_code" |
parallel psql -XA -v wsg={} -f sql/fwa_watersheds_upstream_area.sql

# combine temp tables into output table
psql -c "CREATE TABLE whse_basemapping.fwa_watersheds_upstream_area
        (watershed_feature_id integer primary key, upstream_area double precision);"

for WSG in $(psql -AtX -P border=0,footer=no \
  -c "SELECT watershed_group_code
      FROM whse_basemapping.fwa_watershed_groups_poly
      ORDER BY watershed_group_code
      ")
do
  echo 'Loading '$WSG
  psql -c "INSERT INTO whse_basemapping.fwa_watersheds_upstream_area SELECT * FROM temp.fwa_watersheds_upstream_area_"$WSG
done
psql -c "ANALYZE whse_basemapping.fwa_watersheds_upstream_area"

# drop the temp tables
for WSG in $(psql -AtX -P border=0,footer=no \
  -c "SELECT watershed_group_code
      FROM whse_basemapping.fwa_watershed_groups_poly
      ORDER BY watershed_group_code
      ")
do
  psql -c "DROP TABLE temp.fwa_watersheds_upstream_area_"$WSG
done

echo 'fwa_watersheds_upstream_area loaded successfully'