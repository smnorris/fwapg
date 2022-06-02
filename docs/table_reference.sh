#!/bin/bash

# build table reference for value added tables
echo "# Table reference"
echo -en '\n'

for table in approx_borders \
  basins_poly \
  bcboundary \
  named_streams \
  streams_watersheds_lut \
  waterbodies
do
    echo "## whse_basemapping.fwa_$table"
    echo -en '\n'
    psql -AtX -P border=0,footer=no -c "\dt+ whse_basemapping.fwa_$table" | awk -F"|" '{print $7}'
    echo -en '\n'
    echo "| Column | Type | Description |"
    echo "|--------|------|-------------|"
    psql -AtX -P border=0,footer=no -c "\d+ whse_basemapping.fwa_$table" | awk -F"|" '{ print "| `"$1"` | `"$2"` | "$8" |"}'
    echo -en '\n'
done