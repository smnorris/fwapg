#!/bin/bash
set -euxo pipefail

PSQL="psql $DATABASE_URL -v ON_ERROR_STOP=1"
WSGS=$($PSQL -AXt -c "SELECT watershed_group_code FROM whse_basemapping.fwa_watershed_groups_poly order by watershed_group_code")

mkdir -p data

# ----------
# Download cached ClimateBC Normals 1991-2020 MAP raster from S3
# todo - is this available from climr db?
# ----------
wget --trust-server-names -qNP data https://bcfishpass.s3.us-west-2.amazonaws.com/MAP.tif

# ----------
# Derive MAP per fundamental watershed poly
# ----------
$PSQL -c "DROP TABLE IF EXISTS fwapg.mean_annual_precip_load_ply"
$PSQL -c "CREATE TABLE fwapg.mean_annual_precip_load_ply (watershed_feature_id integer PRIMARY KEY, watershed_group_code text, map numeric)"

# Extract geojsons of each watershed group from db, processing in parallel
parallel --no-run-if-empty \
  "echo 'Processing {1} '; \
  $PSQL -X -t -v wsg={1} <<< \"SELECT
    json_build_object(
      'type', 'FeatureCollection',
      'features', json_agg(ST_AsGeoJSON(t.*)::json)
    )
  FROM
    (
      SELECT
        watershed_feature_id,
        watershed_group_code,
        st_transform(geom,4326) as geom
      FROM whse_basemapping.fwa_watersheds_poly
      WHERE watershed_group_code = :'wsg'
    ) as t\" | \
    rio zonalstats \
        -r data/MAP.tif \
        --all-touched \
        --prefix 'map_' | \
    jq '.features[].properties | [.watershed_feature_id, .watershed_group_code, .map_mean]' | \
    jq -r --slurp '.[] | @csv' | \
    $PSQL -c \"\copy fwapg.mean_annual_precip_load_ply FROM STDIN delimiter ',' csv\"" ::: $WSGS


# ----------
# For watersheds with NULL MAP values output from above, try and get precip at a point in the poly
# ----------
$PSQL -c "DROP TABLE IF EXISTS fwapg.mean_annual_precip_load_pt"
$PSQL -c "CREATE TABLE fwapg.mean_annual_precip_load_pt (watershed_feature_id integer, watershed_group_code text, map numeric)"

$PSQL -t -c "SELECT
    json_build_object(
      'type', 'FeatureCollection',
      'features', json_agg(ST_AsGeoJSON(t.*)::json)
    )
    FROM (
      SELECT
        a.watershed_feature_id,
        b.watershed_group_code,
        st_transform(ST_PointOnSurface(b.geom),4326) as geom
      FROM fwapg.mean_annual_precip_load_ply a
      INNER JOIN whse_basemapping.fwa_watersheds_poly b
      ON a.watershed_feature_id = b.watershed_feature_id
      WHERE a.map IS NULL
    ) AS t" |
  rio -q pointquery -r data/MAP.tif | \
  jq '.features[].properties | [.watershed_feature_id, .watershed_group_code, .value]' | \
  jq -r --slurp '.[] | @csv' | \
  $PSQL -c "\copy fwapg.mean_annual_precip_load_pt FROM STDIN delimiter ',' csv"


# ----------
# Derive MAP for streams without an associated fundamental watershed poly (matching ws codes) 
# (these are mostly in rivers)
# ----------
#  Process these my getting MAP of at pointonsurface of the stream geometry (there are about 59k of these)
$PSQL -c "DROP TABLE IF EXISTS fwapg.mean_annual_precip_load_ln"
$PSQL -c "CREATE TABLE fwapg.mean_annual_precip_load_ln (wscode_ltree ltree, localcode_ltree ltree, watershed_group_code text, map numeric)"
$PSQL -t -c "SELECT
    json_build_object(
      'type', 'FeatureCollection',
      'features', json_agg(ST_AsGeoJSON(t.*)::json)
    )
    FROM (
    SELECT
      s.wscode_ltree,
      s.localcode_ltree,
      s.watershed_group_code,
      ST_Transform(ST_PointOnSurface(ST_Union(s.geom)), 4326) as geom
    FROM whse_basemapping.fwa_stream_networks_sp s
    LEFT OUTER JOIN whse_basemapping.fwa_watersheds_poly w
    ON s.wscode_ltree = w.wscode_ltree AND
      s.localcode_ltree = w.localcode_ltree AND
      s.watershed_group_code = w.watershed_group_code
    WHERE
      w.wscode_ltree IS NULL AND
      s.fwa_watershed_code NOT LIKE '999%'
    GROUP BY s.wscode_ltree, s.localcode_ltree, s.watershed_group_code
    ) as t" |
  rio -q pointquery -r data/MAP.tif | \
  jq '.features[].properties | [.wscode_ltree, .localcode_ltree, .watershed_group_code, .value]' | \
  jq -r --slurp '.[] | @csv' | \
  $PSQL -c "\copy fwapg.mean_annual_precip_load_ln FROM STDIN delimiter ',' csv"


# ----------
# Create the output table.
# ----------
# There can be some remenant duplicates in the source data, make sure it does not get included
# by adding a unique constraint on watershed codes
$PSQL -c "DROP TABLE IF EXISTS whse_basemapping.fwa_stream_networks_mean_annual_precip"
$PSQL -c "CREATE TABLE whse_basemapping.fwa_stream_networks_mean_annual_precip
(
  id serial primary key,
  wscode_ltree ltree,
  localcode_ltree ltree,
  watershed_group_code text,
  area bigint,
  map integer,
  map_upstream integer,
  UNIQUE (wscode_ltree, localcode_ltree)
);"

# Take data from the MAP load tables, average the MAP over the stream segment
# (watershed code / local code) and insert (along with area of fundamental watershed(s) associated with
# this stream segment) into the MAP table. Run the inserts per watershed group.
for WSG in $WSGS
do
  $PSQL -f sql/map.sql -v wsg="$WSG"
done

# index the table for upstream/downstream joins
$PSQL -c "CREATE INDEX ON whse_basemapping.fwa_stream_networks_mean_annual_precip USING GIST (wscode_ltree);"
$PSQL -c "CREATE INDEX ON whse_basemapping.fwa_stream_networks_mean_annual_precip USING BTREE (wscode_ltree);"
$PSQL -c "CREATE INDEX ON whse_basemapping.fwa_stream_networks_mean_annual_precip USING GIST (localcode_ltree);"
$PSQL -c "CREATE INDEX ON whse_basemapping.fwa_stream_networks_mean_annual_precip USING BTREE (localcode_ltree);"

# now calculate area-weighted avg MAP upstream of every stream segment
# loop through watershed groups, don't bother trying to update in parallel
for WSG in $WSGS
do
  $PSQL -X -v wsg="$WSG" < sql/map_upstream.sql
done

# optionally, drop the temp tables and source raster
$PSQL -c "DROP TABLE IF EXISTS fwapg.mean_annual_precip_load_ply"
$PSQL -c "DROP TABLE IF EXISTS fwapg.mean_annual_precip_load_pt"
$PSQL -c "DROP TABLE IF EXISTS fwapg.mean_annual_precip_load_ln"
rm data/MAP.tif*