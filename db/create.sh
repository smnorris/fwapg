#!/bin/bash
set -euxo pipefail

PSQL="psql $DATABASE_URL -v ON_ERROR_STOP=1"

$PSQL -f sql/schemas.sql
$PSQL -f sql/extensions.sql

echo "ALTER DATABASE :db SET search_path TO public,whse_basemapping,usgs,hydrosheds" |
  $PSQL -v db=$(echo $DATABASE_URL | cut -d "/" -f 4)

$PSQL -f sql/tables.sql
$PSQL -f sql/views.sql
$PSQL -f sql/functions/CDB_MakeHexagon.sql
$PSQL -f sql/functions/ST_Safe_Repair.sql
$PSQL -f sql/functions/FWA_Downstream.sql
$PSQL -f sql/functions/FWA_DownstreamTrace.sql
$PSQL -f sql/functions/FWA_Upstream.sql
$PSQL -f sql/functions/huc12.sql
$PSQL -f sql/functions/hydroshed.sql
$PSQL -f sql/functions/FWA_SliceWatershedAtPoint.sql
$PSQL -f sql/functions/FWA_WatershedAtMeasure.sql
$PSQL -f sql/functions/FWA_WatershedHex.sql
$PSQL -f sql/functions/FWA_WatershedStream.sql
$PSQL -f sql/functions/FWA_UpstreamBorderCrossings.sql
$PSQL -f sql/functions/FWA_IndexPoint.sql
$PSQL -f sql/functions/FWA_LocateAlong.sql
$PSQL -f sql/functions/FWA_LocateAlongInterval.sql
$PSQL -f sql/functions/FWA_UpstreamTrace.sql
$PSQL -f sql/functions/postgisftw.sql  # pg_fs/pg_ts functions