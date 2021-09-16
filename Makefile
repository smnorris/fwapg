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

TABLES_VALUEADDEDSCRIPTED = fwa_waterbodies_upstream_area \
	fwa_watersheds_upstream_area

TABLES_SOURCE_TARGETS := $(addprefix .,$(TABLES_SOURCE))
TABLES_VALUEADDED_TARGETS := $(addprefix .,$(TABLES_VALUEADDED))
TABLES_VALUEADDEDSCRIPTED_TARGETS := $(addprefix .,$(TABLES_VALUEADDEDSCRIPTED))

ALL_TARGETS = .db \
	data/FWA.gpkg \
	$(TABLES_SOURCE_TARGETS) \
	.fwa_stream_networks_sp \
	.fwa_watersheds_poly \
	.fwa_linear_boundaries_sp \
	.fwa_fixdata \
	.fwa_fixtypes \
	.fwa_wbdhu12 \
	.fwa_hydrosheds \
	$(TABLES_VALUEADDED_TARGETS) \
	$(TABLES_VALUEADDEDSCRIPTED_TARGETS) \
	.fwa_assessment_watersheds_lut \
	.fwa_assessment_watersheds_streams_lut \
	.fwa_functions

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
	$(PSQL_CMD) -c 'CREATE SCHEMA IF NOT EXISTS usgs'
	$(PSQL_CMD) -c 'CREATE SCHEMA IF NOT EXISTS hydrosheds'
	$(PSQL_CMD) -c "CREATE SCHEMA IF NOT EXISTS postgisftw"       # for fwapg featureserv functions
	#$(PSQL_CMD) -c "ALTER database "$(PGDATABASE)" SET search_path TO "$(PGUSER)", public, postgisftw;"
	touch .db


# get the latest FWA archive from hillcrestgeo.ca
data/FWA.gpkg:
	mkdir -p data
	wget --trust-server-names -qN https://www.hillcrestgeo.ca/outgoing/public/fwapg/FWA.zip -P data
	unzip data/FWA.zip -d data


# load basic/smaller tables from FWA.gpkg to whse_basemapping schema
$(TABLES_SOURCE_TARGETS): .db data/FWA.gpkg
	$(PSQL_CMD) -f sql/tables/source/$(subst .,,$@).sql
	ogr2ogr \
		-f PostgreSQL \
		-update \
		-append \
		--config PG_USE_COPY YES \
		$(PGOGR_SCHEMA) \
		-preserve_fid \
		data/FWA.gpkg \
		$(subst .,,$@)
	touch $@


# streams: for faster load of large table:
# - load to temp table
# - add measure to geom when copying data to output table
# - create indexes after load
.fwa_stream_networks_sp: .db data/FWA.gpkg
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
		-preserve_fid \
		data/FWA.gpkg \
		FWA_STREAM_NETWORKS_SP
	$(PSQL_CMD) -f sql/tables/source/fwa_stream_networks_sp.sql
	touch $@


# watersheds - for faster load of large table:
# - promote to multi on load
# - create indexes after load
.fwa_watersheds_poly: .db data/FWA.gpkg
	ogr2ogr \
		-f PostgreSQL \
		$(PGOGR_SCHEMA) \
		-nlt MULTIPOLYGON \
		-nln fwa_watersheds_poly \
		-lco GEOMETRY_NAME=geom \
		-dim XY \
		-lco SPATIAL_INDEX=NONE \
		-lco FID=WATERSHED_FEATURE_ID \
		-preserve_fid \
		data/FWA.gpkg \
		FWA_WATERSHEDS_POLY
	$(PSQL_CMD) -f sql/tables/source/fwa_watersheds_poly.sql
	touch $@


# linear boundaries - for faster load of large table:
# - promote to multi on load
# - create indexes after load
.fwa_linear_boundaries_sp: .db data/FWA.gpkg
	ogr2ogr \
		-f PostgreSQL \
		$(PGOGR_SCHEMA) \
		-nlt MULTILINESTRING \
		-nln fwa_linear_boundaries_sp \
		-lco GEOMETRY_NAME=geom \
		-dim XY \
		-lco SPATIAL_INDEX=NONE \
		-lco FID=LINEAR_FEATURE_ID \
		-preserve_fid \
		data/FWA.gpkg \
		FWA_LINEAR_BOUNDARIES_SP
	$(PSQL_CMD) -f sql/tables/source/fwa_linear_boundaries_sp.sql
	touch $@


# apply fixes
.fwa_fixdata: .fwa_stream_networks_sp
	$(PSQL_CMD) -f sql/fixes/data.sql  # known errors that may not yet be fixed in source
	touch $@


.fwa_fixtypes: $(TABLES_SOURCE_TARGETS)
	$(PSQL_CMD) -f sql/fixes/types.sql # QGIS likes the geometry types to be uniform (sources are mixed singlepart/multipart)
	touch $@


# USA (lower 48) watersheds - USGS HU12 polygons
data/WBD_National_GDB.gdb:
	mkdir -p data
	wget --trust-server-names -qN https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.zip -P data
	unzip data/WBD_National_GDB.zip -d data

# load washington, idaho, montana and alaska
.fwa_wbdhu12: .db data/WBD_National_GDB.gdb
	ogr2ogr \
		-f PostgreSQL \
		$(PGOGR) \
		-t_srs EPSG:3005 \
		-lco SCHEMA=usgs \
		-lco GEOMETRY_NAME=geom \
		-nln wbdhu12 \
		-nlt MULTIPOLYGON \
		-dialect SQLITE \
		-sql "SELECT * FROM WBDHU12 \
		WHERE states LIKE '%%CN%%' \
		OR states LIKE '%%WA%%' \
		OR states LIKE '%%AK%%' \
		OR states LIKE '%%ID%%' \
		OR states LIKE '%%MT%%'" \
		data/WBD_National_GDB.gdb
	# index the columns of interest
	$(PSQL_CMD) -c "CREATE INDEX ON usgs.wbdhu12 (huc12)"
	$(PSQL_CMD) -c "CREATE INDEX ON usgs.wbdhu12 (tohuc)"
	$(PSQL_CMD) -c "COMMENT ON TABLE usgs.wbdhu12 IS 'USGS National Watershed Boundary Dataset, HUC12 level. See https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.xml';"
	touch $@


# For YT, NWT, AB watersheds, use hydrosheds https://www.hydrosheds.org/
# Source shapefiles must be manually downloaded, so I've cached them here:
data/hybas_ar_lev12_v1c:
	wget --trust-server-names -qN https://www.hillcrestgeo.ca/outgoing/public/fwapg/hydrosheds.zip -P data
	unzip data/hydrosheds.zip -d data

.fwa_hydrosheds: data/hybas_ar_lev12_v1c data/hybas_na_lev12_v1c
	# Load _ar_ and _na_ shapefiles
	ogr2ogr \
		-f PostgreSQL \
		$(PGOGR) \
		-lco OVERWRITE=YES \
		-t_srs EPSG:3005 \
		-lco SCHEMA=hydrosheds \
		-lco GEOMETRY_NAME=geom \
		-nlt PROMOTE_TO_MULTI \
		data/hybas_ar_lev12_v1c/hybas_ar_lev12_v1c.shp
	ogr2ogr \
		-f PostgreSQL \
		$(PGOGR) \
		-t_srs EPSG:3005 \
		-lco OVERWRITE=YES \
		-lco SCHEMA=hydrosheds \
		-lco GEOMETRY_NAME=geom \
		-nlt PROMOTE_TO_MULTI \
		data/hybas_na_lev12_v1c/hybas_na_lev12_v1c.shp
	# combine _ar_ and _na_ into output table hybas_lev12_v1c
	$(PSQL_CMD) -c "ALTER TABLE hydrosheds.hybas_na_lev12_v1c DROP COLUMN ogc_fid"
	$(PSQL_CMD) -c "ALTER TABLE hydrosheds.hybas_ar_lev12_v1c DROP COLUMN ogc_fid"
	$(PSQL_CMD) -c "ALTER TABLE hydrosheds.hybas_na_lev12_v1c RENAME TO hybas_lev12_v1c"
	$(PSQL_CMD) -c "INSERT INTO hydrosheds.hybas_lev12_v1c SELECT * FROM hydrosheds.hybas_ar_lev12_v1c"
	$(PSQL_CMD) -c "DROP TABLE hydrosheds.hybas_ar_lev12_v1c"
	$(PSQL_CMD) -c "ALTER TABLE hydrosheds.hybas_lev12_v1c ALTER COLUMN hybas_id TYPE bigint;" # pk should be integer (ogr loads as numeric)
	$(PSQL_CMD) -c "ALTER TABLE hydrosheds.hybas_lev12_v1c ADD PRIMARY KEY (hybas_id)"
	$(PSQL_CMD) -c "CREATE INDEX ON hydrosheds.hybas_lev12_v1c (next_down)"
	$(PSQL_CMD) -c "COMMENT ON TABLE hydrosheds.hybas_lev12_v1c IS 'HydroBasins for North America from https://www.hydrosheds.org. See source for column documentation';"
	touch $@


# create additional value added tables
$(TABLES_VALUEADDED_TARGETS): $(TABLES_SOURCE_TARGETS)
	$(PSQL_CMD) -f sql/tables/value_added/$(subst .,,$@).sql
	touch $@

# build value added tables that are created with shell scripts rather than direct sql calls
$(TABLES_VALUEADDEDSCRIPTED_TARGETS): $(TABLES_SOURCE_TARGETS)
	scripts/$(subst .,,$@).sh
	touch $@


# load FWA functions
.fwa_functions: $(TABLES_SOURCE_TARGETS) $(TABLES_VALUEADDED_TARGETS) \
	.fwa_stream_networks_sp \
	.fwa_watersheds_poly \
	.fwa_linear_boundaries_sp \
	.fwa_fixtypes \
	.fwa_fixdata \
	.fwa_hydrosheds \
	.fwa_wbdhu12
	# todo - these 3 funcs can be removed with pg13/postgis3.1
	$(PSQL_CMD) -f sql/functions/CDB_MakeHexagon.sql
	$(PSQL_CMD) -f sql/functions/ST_Safe_Repair.sql
	$(PSQL_CMD) -f sql/functions/ST_Safe_Difference.sql

	$(PSQL_CMD) -f sql/functions/FWA_Downstream.sql
	$(PSQL_CMD) -f sql/functions/FWA_huc12.sql
	$(PSQL_CMD) -f sql/functions/FWA_hydroshed.sql
	$(PSQL_CMD) -f sql/functions/FWA_IndexPoint.sql
	$(PSQL_CMD) -f sql/functions/FWA_LocateAlong.sql
	$(PSQL_CMD) -f sql/functions/FWA_LocateAlongInterval.sql
	$(PSQL_CMD) -f sql/functions/FWA_SliceWatershedAtPoint.sql
	$(PSQL_CMD) -f sql/functions/FWA_Upstream.sql
	$(PSQL_CMD) -f sql/functions/FWA_UpstreamBorderCrossings.sql
	$(PSQL_CMD) -f sql/functions/FWA_WatershedAtMeasure.sql
	$(PSQL_CMD) -f sql/functions/FWA_WatershedHex.sql
	$(PSQL_CMD) -f sql/functions/FWA_WatershedStream.sql
	touch $@


# rather than generating them (slow), download pre-generated lookup tables
.fwa_assessment_watersheds_lut: .db
	wget https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_assessment_watersheds_lut.csv.zip -P data
	unzip data/fwa_assessment_watersheds_lut.csv.zip -d data
	$(PSQL_CMD) -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_lut \
	(watershed_feature_id integer PRIMARY KEY, \
	assmnt_watershed_id integer, \
	watershed_group_code text, \
	watershed_group_id integer)"
	$(PSQL_CMD) -c "\copy whse_basemapping.fwa_assessment_watersheds_lut FROM 'data/fwa_assessment_watersheds_lut.csv' delimiter ',' csv header"
	$(PSQL_CMD) -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_lut (assmnt_watershed_id)"
	touch $@


.fwa_assessment_watersheds_streams_lut: .db
	wget https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_assessment_watersheds_streams_lut.csv.zip -P data
	unzip data/fwa_assessment_watersheds_streams_lut.csv.zip -d data
	$(PSQL_CMD) -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_streams_lut \
	(watershed_feature_id integer PRIMARY KEY, \
	assmnt_watershed_id integer, \
	watershed_group_code text, \
	watershed_group_id integer)"
	$(PSQL_CMD) -c "\copy whse_basemapping.fwa_assessment_watersheds_streams_lut FROM 'data/fwa_assessment_watersheds_streams_lut.csv' delimiter ',' csv header"
	$(PSQL_CMD) -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_streams_lut (watershed_feature_id)"
	touch $@
