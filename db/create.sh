#!/bin/bash
set -euxo pipefail

PSQL="psql $DATABASE_URL -v ON_ERROR_STOP=1"

# load extenstions, create schemas/tables
$PSQL -f sql/schema.sql

echo "ALTER DATABASE :db SET search_path TO public,whse_basemapping,usgs,hydrosheds" |
  $PSQL -v db=$(echo $DATABASE_URL | cut -d "/" -f 4)

# load functions
$PSQL -f sql/CDB_MakeHexagon.sql
$PSQL -f sql/ST_Safe_Repair.sql
$PSQL -f sql/FWA_Downstream.sql
$PSQL -f sql/FWA_DownstreamTrace.sql
$PSQL -f sql/FWA_Upstream.sql
$PSQL -f sql/FWA_huc12.sql
$PSQL -f sql/hydroshed.sql
$PSQL -f sql/FWA_SliceWatershedAtPoint.sql
$PSQL -f sql/FWA_WatershedAtMeasure.sql
$PSQL -f sql/FWA_WatershedHex.sql
$PSQL -f sql/FWA_WatershedStream.sql
$PSQL -f sql/FWA_UpstreamBorderCrossings.sql
$PSQL -f sql/FWA_IndexPoint.sql
$PSQL -f sql/FWA_LocateAlong.sql
$PSQL -f sql/FWA_LocateAlongInterval.sql
$PSQL -f sql/FWA_UpstreamTrace.sql
$PSQL -f sql/FWA_NetworkTrace.sql
$PSQL -f sql/FWA_NetworkTraceAgg.sql
$PSQL -f sql/postgisftw.sql  # pg_fs/pg_ts functions