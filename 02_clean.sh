#!/bin/bash
set -euxo pipefail

# add m / ltree / gradient / upstream route measuer values to streams
psql -f sql/create_fwa_stream_networks_sp.sql

# index for speed, this takes some time
psql -f sql/create_indexes.sql

# add watershed codes to watershed groups table
psql -f sql/add_watershed_codes_wsg.sql

# create additional convenience tables
psql -f sql/create_fwa_named_streams.sql
psql -f sql/create_fwa_waterbodies.sql
psql -f sql/create_fwa_watershed_groups_subdivided.sql
psql -f sql/create_fwa_basins_poly.sql

# up and downstream functions
psql -f sql/fwa_upstream.sql
psql -f sql/fwa_downstream.sql

# linear functions
psql -f sql/fwa_lengthdownstream.sql
psql -f sql/fwa_lengthinstream.sql
psql -f sql/fwa_lengthupstream.sql

# watershed functions
psql -f sql/create_fwa_approx_borders.sql
psql -f sql/CDB_MakeHexagon.sql
psql -f sql/fwa_upstreambordercrossings.sql
psql -f sql/fwa_slicewatershedatpoint.sql

psql -f sql/fwa_watershedexbc.sql
psql -f sql/fwa_watershedrefined.sql
psql -f sql/fwa_watershedhex.sql
psql -f sql/fwa_watershedstream.sql

# apply some fixes that have not yet made it into the warehouse
psql -f sql/fixes.sql