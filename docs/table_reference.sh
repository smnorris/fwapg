#!/bin/bash

# build table reference for value added tables
echo "# Table reference"
echo -en '\n'

# value added tables
for table in approx_borders \
  assessment_watersheds_lut \
  assessment_watersheds_streams_lut \
  basins_poly \
  bcboundary \
  named_streams \
  streams_watersheds_lut \
  waterbodies \
  waterbodies_upstream_area \
  watersheds_upstream_area \

do
    echo "## whse_basemapping.fwa_$table"
    echo -en '\n'
    psql $DATABASE_URL -AtX -P border=0,footer=no -c "\dt+ whse_basemapping.fwa_$table" | awk -F"|" '{print $8}'
    echo -en '\n'
    echo "| Column | Type | Description |"
    echo "|--------|------|-------------|"
    psql $DATABASE_URL -AtX -P border=0,footer=no -c "\d+ whse_basemapping.fwa_$table" | awk -F"|" '{ print "| `"$1"` | `"$2"` | "$8" |"}'
    echo -en '\n'
done


# streams view
# (don't bother documenting the individual discharge etc tables)
for view in  streams_vw \

do
    echo "## whse_basemapping.fwa_$view"
    echo -en '\n'
    psql $DATABASE_URL -AtX -P border=0,footer=no -c "\dv+ whse_basemapping.fwa_$view" | awk -F"|" '{print $7}'
    echo -en '\n'
    echo "| Column | Type | Description |"
    echo "|--------|------|-------------|"
    psql $DATABASE_URL -AtX -P border=0,footer=no -c "\d+ whse_basemapping.fwa_$view" | awk -F"|" '{ print "| `"$1"` | `"$2"` | "$7" |"}'
    echo -en '\n'
done