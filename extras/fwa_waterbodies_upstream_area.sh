#!/bin/bash
set -euxo pipefail

# create output table
psql -c "drop table if exists whse_basemapping.fwa_waterbodies_upstream_area"

psql -c "CREATE TABLE whse_basemapping.fwa_waterbodies_upstream_area
        (linear_feature_id bigint primary key,
         upstream_lake_ha double precision,
         upstream_reservoir_ha double precision,
         upstream_wetland_ha double precision)"

# load watershed groups individually
# (calling this in parallel seems to grind things to a halt)
for WSG in $(psql -AtX -P border=0,footer=no \
  -c "SELECT watershed_group_code
      FROM whse_basemapping.fwa_watershed_groups_poly
      ORDER BY watershed_group_code")
do
  echo 'Processing '$WSG
  psql -AX -v wsg=$WSG -f sql/fwa_waterbodies_upstream_area.sql
done

psql -c "ALTER TABLE whse_basemapping.fwa_waterbodies_upstream_area ADD PRIMARY KEY (linear_feature_id)"

echo 'All done, see whse_basemapping.fwa_waterbodies_upstream_area'

