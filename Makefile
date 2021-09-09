.PHONY: all clean_targets clean_db

# Note that watersheds, streams, linear boundaries are not included in this list,
# they get special treatment
TABLES_SOURCE = fwa_assessment_watersheds_poly \
	fwa_bays_and_channels_poly \
	fwa_coastlines_sp \
	fwa_edge_type_codes \
	fwa_glaciers_poly \
	fwa_islands_poly \
	fwa_lakes_poly \
	fwa_manmade_waterbodies_poly \
	fwa_named_point_features_sp \
	fwa_named_watersheds_poly \
	fwa_obstructions_sp \
	fwa_rivers_poly \
	fwa_streams_20k_50k \
	fwa_waterbodies_20k_50k \
	fwa_waterbody_type_codes \
	fwa_watershed_groups_poly \
	fwa_watershed_type_codes \
	fwa_wetlands_poly

TABLES_VALUEADDED = fwa_approx_borders \
	fwa_basins_poly \
	fwa_bcboundary \
	fwa_named_streams \
	fwa_waterbodies \
	fwa_watershed_groups_subdivided

TABLES_SOURCE_TARGETS := $(addprefix .,$(TABLES_SOURCE))
TABLES_VALUEADDED_TARGETS := $(addprefix .,$(TABLES_VALUEADDED))
ALL_TARGETS = .db \
	FWA.gpkg \
	$(TABLES_SOURCE_TARGETS) \
	.fwa_stream_networks_sp \
	.fwa_watersheds_poly \
	.fwa_linear_boundaries_sp \
	.fix_data \
	.fix_types \
	.wdbhu12 \
	.hydrosheds \
	$(TABLES_VALUEADDED_TARGETS) \
	.functions

# shortcuts for ogr2ogr
PGOGR_SCHEMA = "PG:host=$(PGHOST) user=$(PGUSER) dbname=$(PGDATABASE) port=$(PGPORT) active_schema=whse_basemapping"
PGOGR = "PG:host=$(PGHOST) user=$(PGUSER) dbname=$(PGDATABASE) port=$(PGPORT)"

# Ensure psql stops on error so make script stops when there is a problem
PSQL_CMD = psql -v ON_ERROR_STOP=1

all: $(ALL_TARGETS)

# clean make targets only
clean_targets:
	rm -Rf $(ALL_TARGETS)


# clean out (drop) all loaded and derived tables and functions
clean_db:
	$(PSQL_CMD) -f sql/misc/drop_all.sql


# Add required extensions, schemas to db
# ** the database must already exist **
.db:
	$(PSQL_CMD) -c "CREATE EXTENSION IF NOT EXISTS postgis"
	$(PSQL_CMD) -c "CREATE EXTENSION IF NOT EXISTS ltree"
	$(PSQL_CMD) -c "CREATE EXTENSION IF NOT EXISTS intarray"
	$(PSQL_CMD) -c "CREATE SCHEMA IF NOT EXISTS whse_basemapping"
	$(PSQL_CMD) -c "CREATE SCHEMA IF NOT EXISTS postgisftw"       # for fwapg featureserv functions
	#$(PSQL_CMD) -c "ALTER database "$(PGDATABASE)" SET search_path TO "$(PGUSER)", public, postgisftw;"
	touch .db


# get the latest FWA archive from hillcrestgeo.ca
FWA.gpkg:
	wget --trust-server-names -qN https://www.hillcrestgeo.ca/outgoing/public/fwapg/FWA.zip
	unzip FWA.zip


# load basic/smaller tables from FWA.gpkg to whse_basemapping schema
$(TABLES_SOURCE_TARGETS): .db FWA.gpkg
	$(PSQL_CMD) -f sql/tables/source/$(subst .,,$@).sql
	ogr2ogr \
		-f PostgreSQL \
		-update \
		-append \
		--config PG_USE_COPY YES \
		$(PGOGR_SCHEMA) \
		-preserve_fid \
		FWA.gpkg \
		$(subst .,,$@)
	touch $@


# streams: for faster load of large table:
# - load to temp table
# - add measure to geom when copying data to output table
# - create indexes after load
.fwa_stream_networks_sp: .db FWA.gpkg
	ogr2ogr \
		-f PostgreSQL \
		$(PGOGR_SCHEMA) \
		-nlt LINESTRING \
		-nln fwa_stream_networks_sp_load \
		-lco GEOMETRY_NAME=geom \
		-dim XYZ \
		-lco SPATIAL_INDEX=NONE \
		-lco FID=LINEAR_FEATURE_ID \
		-lco FID64=TRUE \
		FWA.gpkg \
		FWA_STREAM_NETWORKS_SP
	$(PSQL_CMD) -f sql/tables/source/fwa_stream_networks_sp.sql
	touch $@


# watersheds - for faster load of large table:
# - promote to multi on load
# - create indexes after load
.fwa_watersheds_poly: .db FWA.gpkg
	ogr2ogr \
		-f PostgreSQL \
		$(PGOGR_SCHEMA) \
		-nlt MULTIPOLYGON \
		-nln fwa_watersheds_poly \
		-lco GEOMETRY_NAME=geom \
		-dim XY \
		-lco SPATIAL_INDEX=NONE \
		-lco FID=WATERSHED_FEATURE_ID \
		FWA.gpkg \
		FWA_WATERSHEDS_POLY
	$(PSQL_CMD) -f sql/tables/source/fwa_watersheds_poly.sql
	touch $@


# linear boundaries - for faster load of large table:
# - promote to multi on load
# - create indexes after load
.fwa_linear_boundaries_sp: .db FWA.gpkg
	ogr2ogr \
		-f PostgreSQL \
		$(PGOGR_SCHEMA) \
		-nlt MULTILINESTRING \
		-nln fwa_linear_boundaries_sp \
		-lco GEOMETRY_NAME=geom \
		-dim XY \
		-lco SPATIAL_INDEX=NONE \
		-lco FID=LINEAR_FEATURE_ID \
		FWA.gpkg \
		FWA_LINEAR_BOUNDARIES_SP
	$(PSQL_CMD) -f sql/tables/source/fwa_linear_boundaries_sp.sql
	touch $@


# apply fixes
.fix_data: .fwa_stream_networks_sp
	$(PSQL_CMD) -f sql/fixes/data.sql  # known errors that may not yet be fixed in source
	touch $@


.fix_types: $(TABLES_SOURCE_TARGETS)
	$(PSQL_CMD) -f sql/fixes/types.sql # QGIS likes the geometry types to be uniform (sources are mixed singlepart/multipart)
	touch $@


# USA (lower 48) watersheds - USGS HU12 polygons
.wdbhu12: .db
	wget https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.zip
	unzip WBD_National_GDB.zip
	$(PSQL_CMD) -c 'CREATE SCHEMA IF NOT EXISTS usgs'
	ogr2ogr \
		-f PostgreSQL \
		$(PGOGR) \
		-t_srs EPSG:3005 \
		-lco SCHEMA=usgs \
		-lco GEOMETRY_NAME=geom \
		-nln wbdhu12 \
		-nlt MULTIPOLYGON \
		-dialect SQLITE \
		-sql "SELECT * FROM WBDHU12
		WHERE states LIKE '%%CN%%'
		OR states LIKE '%%WA%%'
		OR states LIKE '%%AK%%'
		OR states LIKE '%%ID%%'
		OR states LIKE '%%MT%%'" \
		WBD_National_GDB.gdb 2> /dev/null # we can safely ignore the various errors/warnings on load
	# index the columns of interest
	$(PSQL_CMD) -c "CREATE INDEX ON usgs.wbdhu12 (huc12)"
	$(PSQL_CMD) -c "CREATE INDEX ON usgs.wbdhu12 (tohuc)"


# For YT, NWT, AB watersheds, use hydrosheds https://www.hydrosheds.org/
# Source shapefiles must be manually downloaded, so I've cached them here:
.hydrosheds: .db
	wget https://www.hillcrestgeo.ca/outgoing/public/fwapg/hydrosheds.zip
	unzip hydrosheds.zip
	$(PSQL_CMD) -c 'CREATE SCHEMA IF NOT EXISTS hydrosheds'
	# Load _ar_ and _na_ shapefiles
	ogr2ogr \
		-f PostgreSQL \
		$(PGOGR) \
		-lco OVERWRITE=YES \
		-t_srs EPSG:3005 \
		-lco SCHEMA=hydrosheds \
		-lco GEOMETRY_NAME=geom \
		-nlt PROMOTE_TO_MULTI \
		hybas_ar_lev12_v1c/hybas_ar_lev12_v1c.shp
	ogr2ogr \
		-f PostgreSQL \
		$(PGOGR) \
		-t_srs EPSG:3005 \
		-lco OVERWRITE=YES \
		-lco SCHEMA=hydrosheds \
		-lco GEOMETRY_NAME=geom \
		-nlt PROMOTE_TO_MULTI \
		hybas_na_lev12_v1c/hybas_na_lev12_v1c.shp
	# combine _ar_ and _na_ into output table hybas_lev12_v1c
	$(PSQL_CMD) -c "ALTER TABLE hydrosheds.hybas_na_lev12_v1c DROP COLUMN ogc_fid"
	$(PSQL_CMD) -c "ALTER TABLE hydrosheds.hybas_ar_lev12_v1c DROP COLUMN ogc_fid"
	$(PSQL_CMD) -c "ALTER TABLE hydrosheds.hybas_na_lev12_v1c RENAME TO hybas_lev12_v1c"
	$(PSQL_CMD) -c "INSERT INTO hydrosheds.hybas_lev12_v1c SELECT * FROM hydrosheds.hybas_ar_lev12_v1c"
	$(PSQL_CMD) -c "DROP TABLE hydrosheds.hybas_ar_lev12_v1c"
	$(PSQL_CMD) -c "ALTER TABLE hydrosheds.hybas_lev12_v1c ALTER COLUMN hybas_id TYPE bigint;" # pk should be integer (ogr loads as numeric)
	$(PSQL_CMD) -c "ALTER TABLE hydrosheds.hybas_lev12_v1c ADD PRIMARY KEY (hybas_id)"
	$(PSQL_CMD) -c "CREATE INDEX ON hydrosheds.hybas_lev12_v1c (next_down)"


# create additional value added tables
$(TABLES_VALUEADDED): $(TABLES_SOURCE_TARGETS) \
	.fwa_stream_networks_sp \
	.fwa_watersheds_poly \
	.fwa_linear_boundaries_sp \
	.fix_types \
	.fix_data
	$(PSQL_CMD) -f sql/tables_valueadded/$@.sql
	touch $@


# load FWA functions
.functions: $(TABLES_SOURCE_TARGETS) $(TABLES_VALUEADDED_TARGETS) \
	.fwa_stream_networks_sp \
	.fwa_watersheds_poly \
	.fwa_linear_boundaries_sp \
	.fix_types \
	.fix_data \
	.hydrosheds \
	.wdbhu12
	$(PSQL_CMD) -f sql/functions/hydroshed.sql
	$(PSQL_CMD) -f sql/functions/CDB_MakeHexagon.sql
	$(PSQL_CMD) -f sql/functions/ST_Safe_Repair.sql
	$(PSQL_CMD) -f sql/functions/ST_Safe_Difference.sql
	$(PSQL_CMD) -f sql/functions/ST_Safe_Intersection.sql
	$(PSQL_CMD) -f sql/functions/FWA_IndexPoint.sql
	$(PSQL_CMD) -f sql/functions/FWA_Upstream.sql
	$(PSQL_CMD) -f sql/functions/FWA_Downstream.sql
	$(PSQL_CMD) -f sql/functions/FWA_LengthDownstream.sql
	$(PSQL_CMD) -f sql/functions/FWA_LengthInstream.sql
	$(PSQL_CMD) -f sql/functions/FWA_LengthUpstream.sql
	$(PSQL_CMD) -f sql/functions/FWA_UpstreamBorderCrossings.sql
	$(PSQL_CMD) -f sql/functions/FWA_SliceWatershedAtPoint.sql
	$(PSQL_CMD) -f sql/functions/FWA_WatershedExBC.sql
	$(PSQL_CMD) -f sql/functions/FWA_WatershedAtMeasure.sql
	$(PSQL_CMD) -f sql/functions/FWA_WatershedHex.sql
	$(PSQL_CMD) -f sql/functions/FWA_WatershedStream.sql
	$(PSQL_CMD) -f sql/functions/FWA_LocateAlong.sql
	$(PSQL_CMD) -f sql/functions/FWA_LocateAlongInterval.sql
	touch $@


# rather than generating them (slow), download pre-generated lookup tables
.fwa_assessment_watersheds_lut: db
	wget https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_assessment_watersheds_lut.csv.zip
	unzip fwa_assessment_watersheds_lut.csv.zip
	$(PSQL_CMD) -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_lut
	(watershed_feature_id integer PRIMARY KEY,
	assmnt_watershed_id integer,
	watershed_group_code text,
	watershed_group_id integer)"
	$(PSQL_CMD) -c "\copy whse_basemapping.fwa_assessment_watersheds_lut FROM 'fwa_assessment_watersheds_lut.csv' delimiter ',' csv header"
	$(PSQL_CMD) -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_lut (assmnt_watershed_id)"
	rm fwa_assessment_watersheds_lut.csv.zip
	rm fwa_assessment_watersheds_lut.csv
	touch $@


.fwa_assessment_watersheds_streams_lut: db
	wget https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_assessment_watersheds_streams_lut.csv.zip
	unzip fwa_assessment_watersheds_streams_lut.csv.zip
	$(PSQL_CMD) -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_streams_lut
	(watershed_feature_id integer PRIMARY KEY,
	assmnt_watershed_id integer,
	watershed_group_code text,
	watershed_group_id integer)"
	$(PSQL_CMD) -c "\copy whse_basemapping.fwa_assessment_watersheds_streams_lut FROM 'fwa_assessment_watersheds_streams_lut.csv' delimiter ',' csv header"
	$(PSQL_CMD) -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_streams_lut (watershed_feature_id)"
	rm fwa_assessment_watersheds_streams_lut.csv.zip
	rm fwa_assessment_watersheds_streams_lut.csv
	touch $@
