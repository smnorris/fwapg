#!/bin/bash
set -euxo pipefail

PSQL="psql $DATABASE_URL -v ON_ERROR_STOP=1"

WSGS=$($PSQL -tXA -c "SELECT DISTINCT watershed_group_code 
    FROM whse_basemapping.fwa_assessment_watersheds_poly 
    WHERE (wscode_ltree <@ '100'::ltree OR wscode_ltree <@ '300'::ltree OR wscode_ltree <@ '200'::ltree) 
    ORDER BY watershed_group_code")

## Download baseflow and runoff netcdf files from PCIC
mkdir -p data
curl -o data/baseflow.nc 'https://data.pacificclimate.org/data/hydro_model_out/allwsbc.TPS_gridded_obs_init.1945to2099.BASEFLOW.nc.nc?BASEFLOW'$(echo '[13149:24105][][]' | jq -sRr @uri)
curl -o data/runoff.nc 'https://data.pacificclimate.org/data/hydro_model_out/allwsbc.TPS_gridded_obs_init.1945to2099.RUNOFF.nc.nc?RUNOFF'$(echo '[13149:24105][][]' | jq -sRr @uri)

## Create mean annual baseflow, runoff with cdo
cdo -O -b F64 -timmean -yearsum data/baseflow.nc data/baseflow_yearsum_mean.nc
cdo -O -b F64 -timmean -yearsum data/runoff.nc data/runoff_yearsum_mean.nc
	
## Add baseflow and runoff to create mean annual discharge (MAD)
cdo -b F64 add data/runoff_yearsum_mean.nc data/baseflow_yearsum_mean.nc data/discharge.nc

## Load watershed discharge raster to postgres
$PSQL -c "CREATE EXTENSION IF NOT EXISTS postgis_raster;"
$PSQL -c "DROP TABLE IF EXISTS fwapg.discharge01_raster;"
raster2pgsql data/discharge.nc fwapg.discharge01_raster -s 4326 | $PSQL

## overlay fundamental watersheds with discharge raster
## (for PCIC study area: Fraser, Columbia, Peace)
$PSQL -c "CREATE TABLE IF NOT EXISTS fwapg.discharge02_load ( 
	watershed_feature_id integer primary key, 
	watershed_group_code text, 
	discharge_mm double precision);"

$PSQL -c "TRUNCATE fwapg.discharge02_load" # in case of re-runs
parallel $PSQL -f sql/discharge02_load.sql -v wsg={1} ::: $WSGS

# Transfer data from load table to discharge table,
# calculating the area weighted annual average flow for each wsd (mad_mm) and coverting to cubic m per s (m3s)
$PSQL -c "DROP TABLE IF EXISTS fwapg.discharge03_wsd"
$PSQL -c "CREATE UNLOGGED TABLE fwapg.discharge03_wsd ( 
  watershed_feature_id integer, 
  watershed_group_code text, 
  mad_mm double precision, 
  mad_m3s double precision 
);"

# We *should* be able to process every watershed group relatively quickly in parallel - there are no obvious locking events,
# this is just a bunch of inserts to an unindexed, unlogged table.
# But - postgres gets overwhelmed and creates LWLock:LockManager events - this slows everything to a crawl.
# the lwlock:lockmanager locks are still present with only 5 jobs, but do not hold things up too much.
# Presumably this is because the upstream select can be very large and the watersheds table has many indexes.
# pg18 may be better? https://postgres.ai/blog/20251008-postgres-marathon-2-004
# note that dropping the non-wscode/pk/geom indexes does not seem to help.
# As with all upstream queries, pre-aggregating data at given levels in the tree would help a lot - 
# but this query still completes in <1h, so pre-processing is not a high priority.
parallel --joblog discharge_log2.tsv --jobs 5 $PSQL -f sql/discharge03_wsd.sql -v wsg={1} ::: $WSGS
$PSQL -c "ANALYZE whse_basemapping.fwa_watersheds_upstream_area"

## For habitat modelling, it is easier if discharge is per-stream,
## transfer per-watershed discharge data to per-stream
$PSQL -c "truncate whse_basemapping.fwa_stream_networks_discharge"
for wsg in $WSGS; do 
  $PSQL -f sql/discharge.sql -v wsg=$wsg  
done
$PSQL -c "drop table fwapg.discharge01_raster"
$PSQL -c "drop table fwapg.discharge02_load"
$PSQL -c "drop table fwapg.discharge03_wsd"
$PSQL -c "\copy whse_basemapping.fwa_stream_networks_discharge TO 'fwa_stream_networks_discharge.csv' DELIMITER ',' CSV HEADER;"
gzip fwa_stream_networks_discharge.csv
echo 'Discharge processing complete, see whse_basemapping.fwa_stream_networks_discharge columns mad_mm, mad_m3s'