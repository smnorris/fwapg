#!/bin/bash
set -euxo pipefail

# add third party functions - the Juno/lostgis / CartoDB
psql -f sql/functions/ST_Safe_Repair.sql
psql -f sql/functions/ST_Safe_Difference.sql
psql -f sql/functions/ST_Safe_Intersection.sql
psql -f sql/functions/CDB_MakeHexagon.sql

# add m / ltree / gradient / upstream route measuer values to streams
psql -f sql/data_load/create_fwa_stream_networks_sp.sql

# create additional convenience tables
psql -f sql/data_load/create_fwa_named_streams.sql
psql -f sql/data_load/create_fwa_waterbodies.sql
psql -f sql/data_load/create_fwa_watershed_groups_subdivided.sql
psql -f sql/data_load/create_fwa_basins_poly.sql
psql -f sql/data_load/create_fwa_approx_borders.sql

# index for speed, this takes some time
psql -f sql/data_load/create_indexes.sql

# add watershed codes to watershed groups table
psql -f sql/data_load/add_watershed_codes_wsg.sql

# load FWA functions
# As some of these live in postgisftw schema (for access via pg_featureserv),
# we add this schema to default search path for this database.
psql -c "ALTER database "$PGDATABASE" SET search_path TO "$PGUSER", public, topology, sde, postgisftw;"
psql -f sql/functions/FWA_IndexPoint.sql
psql -f sql/functions/FWA_Upstream.sql
psql -f sql/functions/FWA_Downstream.sql
psql -f sql/functions/FWA_LengthDownstream.sql
psql -f sql/functions/FWA_LengthInstream.sql
psql -f sql/functions/FWA_LengthUpstream.sql
psql -f sql/functions/FWA_UpstreamBorderCrossings.sql
psql -f sql/functions/FWA_SliceWatershedAtPoint.sql
psql -f sql/functions/FWA_WatershedExBC.sql
psql -f sql/functions/FWA_WatershedAtMeasure.sql
psql -f sql/functions/FWA_WatershedHex.sql
psql -f sql/functions/FWA_WatershedStream.sql

# apply some data fixes that have not yet made it into the warehouse
psql -f sql/data_fixes/fixes.sql