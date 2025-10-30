#!/bin/bash
set -euxo pipefail

# ==============================================
# cache data to object storage for (much) faster downloads
# ==============================================

# --------------
# process single table sources, writing directly to object storage
# --------------
curl -o /tmp/FWA_BC.gdb.zip ftp://ftp.geobc.gov.bc.ca/sections/outgoing/bmgs/FWA_Public/FWA_BC.zip

ogr2ogr -f Parquet /vsis3/bchamp/fwapg/fwa_assessment_watersheds_poly.parquet \
    /tmp/FWA_BC.gdb.zip \
    -nln fwa_assessment_watersheds_poly \
    -lco FID=watershed_feature_id \
    -sql "SELECT
    CAST(WATERSHED_FEATURE_ID AS integer) AS watershed_feature_id,
    CAST(WATERSHED_GROUP_ID AS integer) AS watershed_group_id,
    WATERSHED_TYPE AS watershed_type,
    GNIS_ID_1 AS gnis_id_1,
    GNIS_NAME_1 AS gnis_name_1,
    GNIS_ID_2 AS gnis_id_2,
    GNIS_NAME_2 AS gnis_name_2,
    GNIS_ID_3 AS gnis_id_3,
    GNIS_NAME_3 AS gnis_name_3,
    WATERBODY_ID AS waterbody_id,
    WATERBODY_KEY AS waterbody_key,
    WATERSHED_KEY AS watershed_key,
    FWA_WATERSHED_CODE AS fwa_watershed_code,
    LOCAL_WATERSHED_CODE AS local_watershed_code,
    WATERSHED_GROUP_CODE AS watershed_group_code,
    LEFT_RIGHT_TRIBUTARY AS left_right_tributary,
    WATERSHED_ORDER AS watershed_order,
    WATERSHED_MAGNITUDE AS watershed_magnitude,
    LOCAL_WATERSHED_ORDER AS local_watershed_order,
    LOCAL_WATERSHED_MAGNITUDE AS local_watershed_magnitude,
    AREA_HA AS area_ha,
    FEATURE_CODE AS feature_code
  FROM FWA_ASSESSMENT_WATERSHEDS_POLY"

ogr2ogr -f Parquet /vsis3/bchamp/fwapg/fwa_bays_and_channels_poly.parquet \
    /tmp/FWA_BC.gdb.zip \
    -nln fwa_bays_and_channels_poly \
    -lco FID=bay_and_channel_id \
    -sql "SELECT
    CAST(BAY_AND_CHANNEL_ID AS integer) AS bay_and_channel_id,
    BAY_CHANNEL_TYPE AS bay_channel_type,
    GNIS_ID AS gnis_id,
    GNIS_NAME AS gnis_name,
    AREA_HA AS area_ha,
    FEATURE_CODE AS feature_code
  FROM FWA_BAYS_AND_CHANNELS_POLY"

ogr2ogr -f Parquet /vsis3/bchamp/fwapg/fwa_coastlines_sp.parquet \
    /tmp/FWA_BC.gdb.zip \
    -nln fwa_coastlines_sp \
    -lco FID=linear_feature_id \
    -explodecollections \
    -sql "SELECT
    CAST(LINEAR_FEATURE_ID AS integer) AS linear_feature_id,
    CAST(WATERSHED_GROUP_ID AS integer) AS watershed_group_id,
    EDGE_TYPE AS edge_type,
    BLUE_LINE_KEY AS blue_line_key,
    WATERSHED_KEY AS watershed_key,
    FWA_WATERSHED_CODE AS fwa_watershed_code,
    LOCAL_WATERSHED_CODE AS local_watershed_code,
    WATERSHED_GROUP_CODE AS watershed_group_code,
    DOWNSTREAM_ROUTE_MEASURE AS downstream_route_measure,
    LENGTH_METRE AS length_metre,
    FEATURE_SOURCE AS feature_source,
    FEATURE_CODE AS feature_code
  FROM FWA_COASTLINES_SP"

ogr2ogr -f Parquet /vsis3/bchamp/fwapg/fwa_glaciers_poly.parquet \
    /tmp/FWA_BC.gdb.zip \
    -nln fwa_glaciers_poly \
    -lco FID=waterbody_poly_id \
    -sql "SELECT
    CAST(WATERBODY_POLY_ID AS integer) AS waterbody_poly_id,
    CAST(WATERSHED_GROUP_ID AS integer) AS watershed_group_id,
    WATERBODY_TYPE AS waterbody_type,
    WATERBODY_KEY AS waterbody_key,
    AREA_HA AS area_ha,
    GNIS_ID_1 AS gnis_id_1,
    GNIS_NAME_1 AS gnis_name_1,
    GNIS_ID_2 AS gnis_id_2,
    GNIS_NAME_2 AS gnis_name_2,
    GNIS_ID_3 AS gnis_id_3,
    GNIS_NAME_3 AS gnis_name_3,
    BLUE_LINE_KEY AS blue_line_key,
    WATERSHED_KEY AS watershed_key,
    FWA_WATERSHED_CODE AS fwa_watershed_code,
    LOCAL_WATERSHED_CODE AS local_watershed_code,
    WATERSHED_GROUP_CODE AS watershed_group_code,
    LEFT_RIGHT_TRIBUTARY AS left_right_tributary,
    WATERBODY_KEY_50K AS waterbody_key_50k,
    WATERSHED_GROUP_CODE_50K AS watershed_group_code_50k,
    WATERBODY_KEY_GROUP_CODE_50K AS waterbody_key_group_code_50k,
    WATERSHED_CODE_50K AS watershed_code_50k,
    FEATURE_CODE AS feature_code
  FROM FWA_GLACIERS_POLY"

ogr2ogr -f Parquet /vsis3/bchamp/fwapg/fwa_islands_poly.parquet \
    /tmp/FWA_BC.gdb.zip \
    -nln fwa_islands_poly \
    -lco FID=island_id \
    -sql "SELECT
    CAST(ISLAND_ID AS integer) AS island_id,
    ISLAND_TYPE AS island_type,
    GNIS_ID_1 AS gnis_id_1,
    GNIS_NAME_1 AS gnis_name_1,
    GNIS_ID_2 AS gnis_id_2,
    GNIS_NAME_2 AS gnis_name_2,
    GNIS_ID_3 AS gnis_id_3,
    GNIS_NAME_3 AS gnis_name_3,
    FWA_WATERSHED_CODE AS fwa_watershed_code,
    LOCAL_WATERSHED_CODE AS local_watershed_code,
    AREA_HA AS area_ha,
    FEATURE_CODE AS feature_code
  FROM FWA_ISLANDS_POLY"

ogr2ogr -f Parquet /vsis3/bchamp/fwapg/fwa_lakes_poly.parquet \
    /tmp/FWA_BC.gdb.zip \
    -nln fwa_lakes_poly \
    -lco FID=waterbody_poly_id \
    -sql "SELECT
    CAST(WATERBODY_POLY_ID AS integer) AS waterbody_poly_id,
    CAST(WATERSHED_GROUP_ID AS integer) AS watershed_group_id,
    WATERBODY_TYPE AS waterbody_type,
    WATERBODY_KEY AS waterbody_key,
    AREA_HA AS area_ha,
    GNIS_ID_1 AS gnis_id_1,
    GNIS_NAME_1 AS gnis_name_1,
    GNIS_ID_2 AS gnis_id_2,
    GNIS_NAME_2 AS gnis_name_2,
    GNIS_ID_3 AS gnis_id_3,
    GNIS_NAME_3 AS gnis_name_3,
    BLUE_LINE_KEY AS blue_line_key,
    WATERSHED_KEY AS watershed_key,
    FWA_WATERSHED_CODE AS fwa_watershed_code,
    LOCAL_WATERSHED_CODE AS local_watershed_code,
    WATERSHED_GROUP_CODE AS watershed_group_code,
    LEFT_RIGHT_TRIBUTARY AS left_right_tributary,
    WATERBODY_KEY_50K AS waterbody_key_50k,
    WATERSHED_GROUP_CODE_50K AS watershed_group_code_50k,
    WATERBODY_KEY_GROUP_CODE_50K AS waterbody_key_group_code_50k,
    WATERSHED_CODE_50K AS watershed_code_50k,
    FEATURE_CODE AS feature_code
  FROM FWA_LAKES_POLY"

ogr2ogr -f Parquet /vsis3/bchamp/fwapg/fwa_manmade_waterbodies_poly.parquet \
    /tmp/FWA_BC.gdb.zip \
    -nln fwa_manmade_waterbodies_poly \
    -lco FID=waterbody_poly_id \
    -sql "SELECT
    CAST(WATERBODY_POLY_ID AS integer) AS waterbody_poly_id,
    CAST(WATERSHED_GROUP_ID AS integer) AS watershed_group_id,
    WATERBODY_TYPE AS waterbody_type,
    WATERBODY_KEY AS waterbody_key,
    AREA_HA AS area_ha,
    GNIS_ID_1 AS gnis_id_1,
    GNIS_NAME_1 AS gnis_name_1,
    GNIS_ID_2 AS gnis_id_2,
    GNIS_NAME_2 AS gnis_name_2,
    GNIS_ID_3 AS gnis_id_3,
    GNIS_NAME_3 AS gnis_name_3,
    BLUE_LINE_KEY AS blue_line_key,
    WATERSHED_KEY AS watershed_key,
    FWA_WATERSHED_CODE AS fwa_watershed_code,
    LOCAL_WATERSHED_CODE AS local_watershed_code,
    WATERSHED_GROUP_CODE AS watershed_group_code,
    LEFT_RIGHT_TRIBUTARY AS left_right_tributary,
    WATERBODY_KEY_50K AS waterbody_key_50k,
    WATERSHED_GROUP_CODE_50K AS watershed_group_code_50k,
    WATERBODY_KEY_GROUP_CODE_50K AS waterbody_key_group_code_50k,
    WATERSHED_CODE_50K AS watershed_code_50k,
    FEATURE_CODE AS feature_code
  FROM FWA_MANMADE_WATERBODIES_POLY"

ogr2ogr -f Parquet /vsis3/bchamp/fwapg/fwa_named_point_features_sp.parquet \
    /tmp/FWA_BC.gdb.zip \
    -nln fwa_named_point_features_sp \
    -lco FID=named_point_feature_id \
    -sql "SELECT
    CAST(NAMED_POINT_FEATURE_ID AS integer) AS named_point_feature_id,
    GNIS_ID AS gnis_id,
    GNIS_NAME AS gnis_name,
    NAMED_FEATURE_TYPE AS named_feature_type,
    FEATURE_CODE AS feature_code
  FROM FWA_NAMED_POINT_FEATURES_SP"

ogr2ogr -f Parquet /vsis3/bchamp/fwapg/fwa_named_watersheds_poly.parquet \
    /tmp/FWA_BC.gdb.zip \
    -nln fwa_named_watersheds_poly \
    -lco FID=named_watershed_id \
    -sql "SELECT
       CAST(NAMED_WATERSHED_ID AS INTEGER) AS named_watershed_id,
       GNIS_ID AS gnis_id,
       GNIS_NAME AS gnis_name,
       BLUE_LINE_KEY AS blue_line_key,
       WATERSHED_KEY AS watershed_key,
       FWA_WATERSHED_CODE AS fwa_watershed_code,
       STREAM_ORDER AS stream_order,
       STREAM_MAGNITUDE AS stream_magnitude,
       AREA_HA AS area_ha,
       FEATURE_CODE AS feature_code
    FROM FWA_NAMED_WATERSHEDS_POLY"

ogr2ogr -f Parquet /vsis3/bchamp/fwapg/fwa_obstructions_sp.parquet \
    /tmp/FWA_BC.gdb.zip \
    -nln fwa_obstructions_sp \
    -lco FID=obstruction_id \
    -sql "SELECT
       CAST(OBSTRUCTION_ID AS INTEGER) AS obstruction_id,
       CAST(WATERSHED_GROUP_ID AS INTEGER) AS watershed_group_id,
       CAST(LINEAR_FEATURE_ID AS BIGINT) AS linear_feature_id,
       GNIS_ID AS gnis_id,
       GNIS_NAME AS gnis_name,
       OBSTRUCTION_TYPE AS obstruction_type,
       BLUE_LINE_KEY AS blue_line_key,
       WATERSHED_KEY AS watershed_key,
       FWA_WATERSHED_CODE AS fwa_watershed_code,
       LOCAL_WATERSHED_CODE AS local_watershed_code,
       WATERSHED_GROUP_CODE AS watershed_group_code,
       ROUTE_MEASURE AS route_measure,
       FEATURE_SOURCE AS feature_source,
       FEATURE_CODE AS feature_code
     FROM FWA_OBSTRUCTIONS_SP"

ogr2ogr -f Parquet /vsis3/bchamp/fwapg/fwa_rivers_poly.parquet \
    /tmp/FWA_BC.gdb.zip \
    -nln fwa_rivers_poly \
    -lco FID=waterbody_poly_id \
    -sql "SELECT
    CAST(WATERBODY_POLY_ID AS integer) AS waterbody_poly_id,
    CAST(WATERSHED_GROUP_ID AS integer) AS watershed_group_id,
    WATERBODY_TYPE AS waterbody_type,
    WATERBODY_KEY AS waterbody_key,
    AREA_HA AS area_ha,
    GNIS_ID_1 AS gnis_id_1,
    GNIS_NAME_1 AS gnis_name_1,
    GNIS_ID_2 AS gnis_id_2,
    GNIS_NAME_2 AS gnis_name_2,
    GNIS_ID_3 AS gnis_id_3,
    GNIS_NAME_3 AS gnis_name_3,
    BLUE_LINE_KEY AS blue_line_key,
    WATERSHED_KEY AS watershed_key,
    FWA_WATERSHED_CODE AS fwa_watershed_code,
    LOCAL_WATERSHED_CODE AS local_watershed_code,
    WATERSHED_GROUP_CODE AS watershed_group_code,
    LEFT_RIGHT_TRIBUTARY AS left_right_tributary,
    WATERBODY_KEY_50K AS waterbody_key_50k,
    WATERSHED_GROUP_CODE_50K AS watershed_group_code_50k,
    WATERBODY_KEY_GROUP_CODE_50K AS waterbody_key_group_code_50k,
    WATERSHED_CODE_50K AS watershed_code_50k,
    FEATURE_CODE AS feature_code
  FROM FWA_RIVERS_POLY"

ogr2ogr -f Parquet /vsis3/bchamp/fwapg/fwa_watershed_groups_poly.parquet \
    /tmp/FWA_BC.gdb.zip \
    -nln fwa_watershed_groups_poly \
    -lco FID=watershed_group_id \
    -sql "SELECT
       CAST(WATERSHED_GROUP_ID AS INTEGER) AS watershed_group_id,
       WATERSHED_GROUP_CODE AS watershed_group_code,
       WATERSHED_GROUP_NAME AS watershed_group_name,
       AREA_HA AS area_ha,
       FEATURE_CODE AS feature_code
     FROM FWA_WATERSHED_GROUPS_POLY"

ogr2ogr -f Parquet /vsis3/bchamp/fwapg/fwa_wetlands_poly.parquet \
    /tmp/FWA_BC.gdb.zip \
    -nln fwa_wetlands_poly \
    -lco FID=waterbody_poly_id \
    -sql "SELECT
    CAST(WATERBODY_POLY_ID AS integer) AS waterbody_poly_id,
    CAST(WATERSHED_GROUP_ID AS integer) AS watershed_group_id,
    WATERBODY_TYPE AS waterbody_type,
    WATERBODY_KEY AS waterbody_key,
    AREA_HA AS area_ha,
    GNIS_ID_1 AS gnis_id_1,
    GNIS_NAME_1 AS gnis_name_1,
    GNIS_ID_2 AS gnis_id_2,
    GNIS_NAME_2 AS gnis_name_2,
    GNIS_ID_3 AS gnis_id_3,
    GNIS_NAME_3 AS gnis_name_3,
    BLUE_LINE_KEY AS blue_line_key,
    WATERSHED_KEY AS watershed_key,
    FWA_WATERSHED_CODE AS fwa_watershed_code,
    LOCAL_WATERSHED_CODE AS local_watershed_code,
    WATERSHED_GROUP_CODE AS watershed_group_code,
    LEFT_RIGHT_TRIBUTARY AS left_right_tributary,
    WATERBODY_KEY_50K AS waterbody_key_50k,
    WATERSHED_GROUP_CODE_50K AS watershed_group_code_50k,
    WATERBODY_KEY_GROUP_CODE_50K AS waterbody_key_group_code_50k,
    WATERSHED_CODE_50K AS watershed_code_50k,
    FEATURE_CODE AS feature_code
  FROM FWA_WETLANDS_POLY"


# --------------
# process multi table sources
# - download source
# - convert each wsg to parquet
# - write single parquet to object storage
# --------------

WSD_GROUPS=$(ogr2ogr -f CSV /vsistdout/ \
  /vsis3/bchamp/fwapg/fwa_watershed_groups_poly.parquet \
  -sql "select distinct watershed_group_code from fwa_watershed_groups_poly order by watershed_group_code" | tail -n +2
)

# LINEAR BOUDNARIES
curl -o /tmp/FWA_LINEAR_BOUNDARIES_SP.gdb.zip ftp://ftp.geobc.gov.bc.ca/sections/outgoing/bmgs/FWA_Public/FWA_LINEAR_BOUNDARIES_SP.zip

mkdir -p data/fwa_linear_boundaries_sp

for WSG in $WSD_GROUPS;
do
  ogr2ogr -f Parquet data/fwa_linear_boundaries_sp/$WSG.parquet \
    /tmp/FWA_LINEAR_BOUNDARIES_SP.gdb.zip \
    -nln fwa_linear_boundaries_sp \
    -lco FID=linear_feature_id \
    -sql "SELECT
      CAST(LINEAR_FEATURE_ID AS bigint) as linear_feature_id,
      CAST(WATERSHED_GROUP_ID AS integer) as watershed_group_id,
      EDGE_TYPE AS edge_type,
      WATERBODY_KEY AS waterbody_key,
      BLUE_LINE_KEY AS blue_line_key,
      WATERSHED_KEY AS watershed_key,
      FWA_WATERSHED_CODE AS fwa_watershed_code,
      LOCAL_WATERSHED_CODE AS local_watershed_code,
      WATERSHED_GROUP_CODE AS watershed_group_code,
      DOWNSTREAM_ROUTE_MEASURE AS downstream_route_measure,
      LENGTH_METRE AS length_metre,
      FEATURE_SOURCE AS feature_source,
      FEATURE_CODE AS feature_code
    FROM $WSG"
done

ogr2ogr -f Parquet /vsis3/bchamp/fwapg/fwa_linear_boundaries_sp.parquet data/fwa_linear_boundaries_sp fwa_linear_boundaries_sp


# STREAM NETWORKS
curl -o /tmp/FWA_STREAM_NETWORKS_SP.gdb.zip ftp://ftp.geobc.gov.bc.ca/sections/outgoing/bmgs/FWA_Public/FWA_STREAM_NETWORKS_SP.zip
mkdir -p data/fwa_stream_networks_sp
for WSG in $WSD_GROUPS;
do
  ogr2ogr -f Parquet data/fwa_stream_networks_sp/$WSG.parquet \
    /tmp/FWA_STREAM_NETWORKS_SP.gdb.zip \
    -nln fwa_stream_networks_sp \
    -lco FID=linear_feature_id \
    -sql "SELECT
      CAST(LINEAR_FEATURE_ID AS bigint) as linear_feature_id,
      CAST(WATERSHED_GROUP_ID AS integer) as watershed_group_id,
      EDGE_TYPE as edge_type,
      BLUE_LINE_KEY as blue_line_key,
      WATERSHED_KEY as watershed_key,
      FWA_WATERSHED_CODE as fwa_watershed_code,
      LOCAL_WATERSHED_CODE as local_watershed_code,
      WATERSHED_GROUP_CODE as watershed_group_code,
      DOWNSTREAM_ROUTE_MEASURE as downstream_route_measure,
      LENGTH_METRE as length_metre,
      FEATURE_SOURCE as feature_source,
      GNIS_ID as gnis_id,
      GNIS_NAME as gnis_name,
      LEFT_RIGHT_TRIBUTARY as left_right_tributary,
      STREAM_ORDER as stream_order,
      STREAM_MAGNITUDE as stream_magnitude,
      WATERBODY_KEY as waterbody_key,
      BLUE_LINE_KEY_50K as blue_line_key_50k,
      WATERSHED_CODE_50K as watershed_code_50k,
      WATERSHED_KEY_50K as watershed_key_50k,
      WATERSHED_GROUP_CODE_50K as watershed_group_code_50k,
      GRADIENT as gradient,
      FEATURE_CODE as feature_code,
      UPSTREAM_ROUTE_MEASURE as upstream_route_measure
    FROM $WSG"
done

ogr2ogr -f Parquet /vsis3/bchamp/fwapg/fwa_stream_networks_sp.parquet data/fwa_stream_networks_sp fwa_stream_networks_sp


# WATERSHEDS
curl -o /tmp/FWA_WATERSHEDS_POLY.gdb.zip ftp://ftp.geobc.gov.bc.ca/sections/outgoing/bmgs/FWA_Public/FWA_WATERSHEDS_POLY.zip
mkdir -p data/fwa_watersheds_poly
for WSG in $WSD_GROUPS;
do
  ogr2ogr -f Parquet data/fwa_watersheds_poly/$WSG.parquet \
    /tmp/FWA_WATERSHEDS_POLY.gdb.zip \
    -nln fwa_watersheds_poly \
    -lco FID=watershed_feature_id \
    -sql "SELECT
      CAST(WATERSHED_FEATURE_ID AS INTEGER) AS watershed_feature_id,
      CAST(WATERSHED_GROUP_ID AS INTEGER) AS watershed_group_id,
      WATERSHED_TYPE AS watershed_type,
      GNIS_ID_1 AS gnis_id_1,
      GNIS_NAME_1 AS gnis_name_1,
      GNIS_ID_2 AS gnis_id_2,
      GNIS_NAME_2 AS gnis_name_2,
      GNIS_ID_3 AS gnis_id_3,
      GNIS_NAME_3 AS gnis_name_3,
      WATERBODY_ID AS waterbody_id,
      WATERBODY_KEY AS waterbody_key,
      WATERSHED_KEY AS watershed_key,
      FWA_WATERSHED_CODE AS fwa_watershed_code,
      LOCAL_WATERSHED_CODE AS local_watershed_code,
      WATERSHED_GROUP_CODE AS watershed_group_code,
      LEFT_RIGHT_TRIBUTARY AS left_right_tributary,
      WATERSHED_ORDER AS watershed_order,
      WATERSHED_MAGNITUDE AS watershed_magnitude,
      LOCAL_WATERSHED_ORDER AS local_watershed_order,
      LOCAL_WATERSHED_MAGNITUDE AS local_watershed_magnitude,
      AREA_HA AS area_ha,
      RIVER_AREA AS river_area,
      LAKE_AREA AS lake_area,
      WETLAND_AREA AS wetland_area,
      MANMADE_AREA AS manmade_area,
      GLACIER_AREA AS glacier_area,
      AVERAGE_ELEVATION AS average_elevation,
      AVERAGE_SLOPE AS average_slope,
      ASPECT_NORTH AS aspect_north,
      ASPECT_SOUTH AS aspect_south,
      ASPECT_WEST AS aspect_west,
      ASPECT_EAST AS aspect_east,
      ASPECT_FLAT AS aspect_flat,
      FEATURE_CODE AS feature_code
    FROM $WSG"
done

ogr2ogr -f Parquet /vsis3/bchamp/fwapg/fwa_watersheds_poly.parquet data/fwa_watersheds_poly fwa_watersheds_poly

# --------------
# make data public
# --------------
aws s3api put-object-acl --bucket bchamp --key fwapg/fwa_assessment_watersheds_poly.parquet --acl public-read
aws s3api put-object-acl --bucket bchamp --key fwapg/fwa_bays_and_channels_poly.parquet --acl public-read
aws s3api put-object-acl --bucket bchamp --key fwapg/fwa_coastlines_sp.parquet --acl public-read
aws s3api put-object-acl --bucket bchamp --key fwapg/fwa_glaciers_poly.parquet --acl public-read
aws s3api put-object-acl --bucket bchamp --key fwapg/fwa_islands_poly.parquet --acl public-read
aws s3api put-object-acl --bucket bchamp --key fwapg/fwa_lakes_poly.parquet --acl public-read
aws s3api put-object-acl --bucket bchamp --key fwapg/fwa_linear_boundaries_sp.parquet --acl public-read
aws s3api put-object-acl --bucket bchamp --key fwapg/fwa_manmade_waterbodies_poly.parquet --acl public-read
aws s3api put-object-acl --bucket bchamp --key fwapg/fwa_named_point_features_sp.parquet --acl public-read
aws s3api put-object-acl --bucket bchamp --key fwapg/fwa_named_watersheds_poly.parquet --acl public-read
aws s3api put-object-acl --bucket bchamp --key fwapg/fwa_obstructions_sp.parquet --acl public-read
aws s3api put-object-acl --bucket bchamp --key fwapg/fwa_rivers_poly.parquet --acl public-read
aws s3api put-object-acl --bucket bchamp --key fwapg/fwa_stream_networks_sp.parquet --acl public-read
aws s3api put-object-acl --bucket bchamp --key fwapg/fwa_watershed_groups_poly.parquet --acl public-read
aws s3api put-object-acl --bucket bchamp --key fwapg/fwa_watersheds_poly.parquet --acl public-read
aws s3api put-object-acl --bucket bchamp --key fwapg/fwa_wetlands_poly.parquet --acl public-read