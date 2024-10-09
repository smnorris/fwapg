set -euxo pipefail

PSQL="psql $DATABASE_URL -v ON_ERROR_STOP=1"
WSGS=$($PSQL -AXt -c "SELECT watershed_group_code FROM whse_basemapping.fwa_watershed_groups_poly")

$PSQL -c "drop table if exists whse_basemapping.fwa_stream_profiles"
$PSQL -c "create table whse_basemapping.fwa_stream_profiles (
  blue_line_key integer,
  downstream_route_measure double precision,
  upstream_route_measure double precision,
  downstream_elevation double precision,
  upstream_elevation double precision
 );
 "

parallel $PSQL -f sql/fwa_stream_profiles.sql -v wsg={1} ::: $WSGS