#!/bin/bash
set -euxo pipefail

ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nln fwa_edge_type_codes \
  FWA.gpkg \
  FWA_EDGE_TYPE_CODES
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nln fwa_streams_20k_50k \
  -lco FID=STREAM_20K_50K_ID \
  -lco FID64=TRUE \
  FWA.gpkg \
  FWA_STREAMS_20K_50K
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nln fwa_waterbodies_20k_50k \
  -lco FID=WATERBODY_20K_50K_ID \
  FWA.gpkg \
  FWA_WATERBODIES_20K_50K
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nln fwa_waterbody_type_codes \
  FWA.gpkg \
  FWA_WATERBODY_TYPE_CODES
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nln fwa_watershed_type_codes \
  FWA.gpkg \
  FWA_WATERSHED_TYPE_CODES
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_assessment_watersheds_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=WATERSHED_FEATURE_ID \
  -dialect SQLITE \
  FWA.gpkg \
  FWA_ASSESSMENT_WATERSHEDS_POLY
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_bays_and_channels_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=BAY_AND_CHANNEL_ID \
  FWA.gpkg \
  FWA_BAYS_AND_CHANNELS_POLY
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTILINESTRING \
  -nln fwa_coastlines_sp \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=LINEAR_FEATURE_ID \
  -dialect SQLITE \
  FWA.gpkg \
  FWA_COASTLINES_SP
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_glaciers_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=WATERBODY_POLY_ID \
  -dialect SQLITE \
  FWA.gpkg \
  FWA_GLACIERS_POLY

ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_islands_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=ISLAND_ID \
  -dialect SQLITE \
  FWA.gpkg \
  FWA_ISLANDS_POLY

ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_lakes_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=WATERBODY_POLY_ID \
  -dialect SQLITE \
  FWA.gpkg \
  FWA_LAKES_POLY

ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_manmade_waterbodies_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=WATERBODY_POLY_ID \
  -dialect SQLITE \
  FWA.gpkg \
  FWA_MANMADE_WATERBODIES_POLY

ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOINT \
  -nln fwa_obstructions_sp \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=OBSTRUCTION_ID \
  -dialect SQLITE \
  FWA.gpkg \
  FWA_OBSTRUCTIONS_SP

ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_rivers_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=WATERBODY_POLY_ID \
  -dialect SQLITE \
  FWA.gpkg \
  FWA_RIVERS_POLY

ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_watershed_groups_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=WATERSHED_GROUP_ID \
  FWA.gpkg \
  FWA_WATERSHED_GROUPS_POLY
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_wetlands_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=WATERBODY_POLY_ID \
  -dialect SQLITE \
  FWA.gpkg \
  FWA_WETLANDS_POLY

ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_named_watersheds_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=NAMED_WATERSHED_ID \
  -dialect SQLITE \
  FWA.gpkg \
  FWA_NAMED_WATERSHEDS_POLY

ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTILINESTRING \
  -nln fwa_linear_boundaries_sp \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=LINEAR_FEATURE_ID \
  -dialect SQLITE \
  FWA.gpkg \
  FWA_LINEAR_BOUNDARIES_SP

ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_watersheds_poly \
  -t_srs EPSG:3005 \
  -lco SPATIAL_INDEX=NONE \
  -lco GEOMETRY_NAME=geom \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=WATERSHED_FEATURE_ID \
  -dialect SQLITE \
  FWA.gpkg \
  FWA_WATERSHEDS_POLY

ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt LINESTRING \
  -nln fwa_stream_networks_sp_load \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -dim XYZ \
  -s_srs EPSG:3005 \
  -lco SPATIAL_INDEX=NONE \
  -lco FID=LINEAR_FEATURE_ID \
  -lco FID64=TRUE \
  FWA.gpkg \
  FWA_STREAM_NETWORKS_SP

# Rather than running script 04_assmnt_wsds_lut.sh to create the fundamental wsd <-> asssessment wsd lookup
# (it takes a very long time), just download the lookup as csv
wget https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_assessment_watersheds_lut.csv.zip
wget https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_assessment_watersheds_streams_lut.csv.zip
unzip fwa_assessment_watersheds_lut.csv.zip
unzip fwa_assessment_watersheds_streams_lut.csv.zip

psql -c "DROP TABLE IF EXISTS whse_basemapping.fwa_assessment_watersheds_lut;"
psql -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_lut
(watershed_feature_id integer PRIMARY KEY,
assmnt_watershed_id integer,
watershed_group_code text,
watershed_group_id integer)"
psql -c "\copy whse_basemapping.fwa_assessment_watersheds_lut FROM 'fwa_assessment_watersheds_lut.csv' delimiter ',' csv header"
psql -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_lut (assmnt_watershed_id)"

psql -c "DROP TABLE IF EXISTS whse_basemapping.fwa_assessment_watersheds_streams_lut;"
psql -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_streams_lut
(watershed_feature_id integer PRIMARY KEY,
assmnt_watershed_id integer,
watershed_group_code text,
watershed_group_id integer)"
psql -c "\copy whse_basemapping.fwa_assessment_watersheds_streams_lut FROM 'fwa_assessment_watersheds_streams_lut.csv' delimiter ',' csv header"
psql -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_streams_lut (watershed_feature_id)"

rm fwa_assessment_watersheds_lut.csv.zip
rm fwa_assessment_watersheds_lut.csv

rm fwa_assessment_watersheds_streams_lut.csv.zip
rm fwa_assessment_watersheds_streams_lut.csv



echo 'Data load complete, consider removing FWA.gpkg to save disk space'
