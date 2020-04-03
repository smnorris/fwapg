#!/bin/bash
set -euxo pipefail

# add m values to streams before indexing
psql -f sql/add_m.sql

# index for speed, this takes some time
psql -f sql/create_indexes.sql

# create additional convenience tables
# this query does not complete with latest FWA data
#psql -f sql/create_fwa_assessment_watersheds_streams.sql
psql -f sql/create_fwa_named_streams.sql
psql -f sql/create_fwa_waterbodies.sql
psql -f sql/create_fwa_watershed_groups_subdivided.sql

# linear functions
psql -f sql/fwa_upstreamwsc.sql
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