#!/bin/bash
set -euxo pipefail

# build table reference for value added tables
echo "# Table reference" > 03_tables.md
echo -en '\n' >> 03_tables.md

for table in approx_borders \
  basins_poly \
  bcboundary \
  named_streams \
  streams_watersheds_lut \
  waterbodies \
  watershed_groups_subdivided
do
    echo "## whse_basemapping.fwa_$table" >> 03_tables.md
    echo -en '\n' >> 03_tables.md
    psql -AtX -P border=0,footer=no -c "\dt+ whse_basemapping.fwa_$table" | awk -F"|" '{print $7}' >> 03_tables.md
    echo -en '\n' >> 03_tables.md
    echo "| Column | Type | Description |" >> 03_tables.md
    echo "|--------|------|-------------|" >> 03_tables.md
    psql -AtX -P border=0,footer=no -c "\d+ whse_basemapping.fwa_$table" | awk -F"|" '{ print "| `"$1"` | `"$2"` | "$8" |"}' >> 03_tables.md
    echo -en '\n' >> 03_tables.md
done