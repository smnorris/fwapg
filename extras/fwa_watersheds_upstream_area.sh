#!/bin/bash
set -euxo pipefail

# create load table
psql -c "drop table if exists whse_basemapping.fwa_watersheds_upstream_area"
psql -c "create table whse_basemapping.fwa_watersheds_upstream_area
        (watershed_feature_id integer, upstream_area double precision);"

# load watershed groups individually
# (calling this in parallel seems to grind things to a halt)
for WSG in $(psql -AtX -P border=0,footer=no \
  -c "SELECT watershed_group_code
      FROM whse_basemapping.fwa_watershed_groups_poly
      ORDER BY watershed_group_code")
do
  echo 'Processing '$WSG
  psql -AX -v wsg=$WSG -f sql/fwa_watersheds_upstream_area.sql
done

psql -c "ALTER TABLE whse_basemapping.fwa_watersheds_upstream_area ADD PRIMARY KEY (watershed_feature_id)"

echo 'All done, see whse_basemapping.fwa_watersheds_upstream_area'

