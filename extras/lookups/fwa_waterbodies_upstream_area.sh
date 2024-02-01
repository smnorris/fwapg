#!/bin/bash
set -euxo pipefail

psql -c "CREATE TABLE whse_basemapping.fwa_waterbodies_upstream_area
        (linear_feature_id bigint,
         upstream_lake_ha double precision,
         upstream_reservoir_ha double precision,
         upstream_wetland_ha double precision)"

# load watershed groups individually
# (calling this in parallel seems to grind things to a halt)
for WSG in $(psql -AtX -P border=0,footer=no \
  -c "SELECT watershed_group_code
      FROM whse_basemapping.fwa_watershed_groups_poly
      ORDER BY watershed_group_code
      ")
do
  echo 'Processing '$WSG
  psql -AX -v wsg=$WSG -f sql/tables/value_added/fwa_waterbodies_upstream_area.sql
done

psql -c "ALTER TABLE whse_basemapping.fwa_waterbodies_upstream_area ADD PRIMARY KEY (linear_feature_id)"

echo 'fwa_waterbodies_upstream_area loaded successfully'

psql -c "\copy whse_basemapping.fwa_waterbodies_upstream_area TO 'fwa_waterbodies_upstream_area.csv' DELIMITER ',' CSV HEADER;"
zip -r fwa_waterbodies_upstream_area.zip fwa_waterbodies_upstream_area.csv
rm fwa_waterbodies_upstream_area.csv
echo 'fwa_waterbodies_upstream_area dumped to zipped csv'
