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
	fwa_waterbodies

TABLES_SOURCE_TARGETS := $(addprefix .make/,$(TABLES_SOURCE))
TABLES_VALUEADDED_TARGETS := $(addprefix .make/,$(TABLES_VALUEADDED))

ALL_TARGETS = .make/db \
	data/fwa.gpkg \
	$(TABLES_SOURCE_TARGETS) \
	.make/fwa_stream_networks_sp \
	.make/fwa_watersheds_poly \
	.make/fwa_linear_boundaries_sp \
	.make/fwa_fixdata \
	.make/fwa_fixtypes \
	.make/fwa_wbdhu12 \
	.make/fwa_hydrosheds \
	$(TABLES_VALUEADDED_TARGETS) \
	.make/fwa_streams_watersheds_lut \
	.make/fwa_waterbodies_upstream_area \
	.make/fwa_watersheds_upstream_area \
	.make/fwa_assessment_watersheds_lut \
	.make/fwa_assessment_watersheds_streams_lut \
	.make/fwa_stream_order_parent \
	.make/fwa_functions

# provide db connection param to psql and ensure scripts stop on error
PSQL_CMD = psql $(DATABASE_URL) -v ON_ERROR_STOP=1

# Kludge to geth the OGR to work with the container that was built and being
# run in openshift... To address this issue:
# https://github.com/OSGeo/gdal/issues/4570
DATABASE_URL_OGR=$(DATABASE_URL)?application_name=foo

# get list of watershed groups
GROUPS = $(shell $(PSQL_CMD) -AtX -c "SELECT watershed_group_code FROM whse_basemapping.fwa_watershed_groups_poly")

all: $(ALL_TARGETS)

# clean make targets only
clean_targets:
	rm -Rf $(ALL_TARGETS)

# clean out (drop) all loaded and derived tables and functions
clean_db:
	$(PSQL_CMD) -f sql/misc/drop_all.sql

# Add required extensions, schemas to db
# ** the database must already exist **
.make/db:
	mkdir -p .make
	$(PSQL_CMD) -c "CREATE EXTENSION IF NOT EXISTS postgis"
	$(PSQL_CMD) -c "CREATE EXTENSION IF NOT EXISTS ltree"
	$(PSQL_CMD) -c "CREATE EXTENSION IF NOT EXISTS intarray"
	$(PSQL_CMD) -c "CREATE SCHEMA IF NOT EXISTS whse_basemapping"
	$(PSQL_CMD) -c 'CREATE SCHEMA IF NOT EXISTS usgs'
	$(PSQL_CMD) -c 'CREATE SCHEMA IF NOT EXISTS hydrosheds'
	$(PSQL_CMD) -c "CREATE SCHEMA IF NOT EXISTS postgisftw"	  # for fwapg featureserv functions
	touch $@

data/fwa.gpkg:
	mkdir -p data
	wget -O - --trust-server-names -qN https://nrs.objectstore.gov.bc.ca/dzzrch/fwa.gpkg.gz | gunzip > ./data/fwa.gpkg

# load basic/smaller tables from fwa.gpkg to whse_basemapping schema
$(TABLES_SOURCE_TARGETS): .make/db data/fwa.gpkg
	$(PSQL_CMD) -f sql/tables/source/$(subst .make/,,$@).sql
	ogr2ogr \
		-f PostgreSQL \
		-update \
		-append \
		-nln whse_basemapping$(subst .make/,.,$@) \
		--config PG_USE_COPY YES \
		PG:$(DATABASE_URL_OGR)  \
		-preserve_fid \
		-dialect SQLITE \
		-sql "SELECT * FROM $(subst .make/,,$@)" \
		data/fwa.gpkg
	touch $@

# streams: for faster load of large table:
# - load to temp table
# - add measure to geom when copying data to output table
# - create indexes after load
.make/fwa_stream_networks_sp: .make/db data/fwa.gpkg
	$(PSQL_CMD) -c "drop table if exists whse_basemapping.fwa_stream_networks_sp_load"
	ogr2ogr \
		-f PostgreSQL \
		PG:$(DATABASE_URL_OGR)  \
		-nlt LINESTRING \
		-nln whse_basemapping.fwa_stream_networks_sp_load \
		-lco GEOMETRY_NAME=geom \
		-lco OVERWRITE=YES \
		-dim XYZ \
		-lco SPATIAL_INDEX=NONE \
		-lco FID=LINEAR_FEATURE_ID \
		-lco FID64=TRUE \
		-preserve_fid \
		data/fwa.gpkg \
		FWA_STREAM_NETWORKS_SP
	$(PSQL_CMD) -f sql/tables/source/fwa_stream_networks_sp.sql
	touch $@


# watersheds - for faster load of large table:
# - promote to multi on load
# - create indexes after load
.make/fwa_watersheds_poly: .make/db data/fwa.gpkg
	$(PSQL_CMD) -c "drop table if exists whse_basemapping.fwa_watersheds_poly"
	ogr2ogr \
		-f PostgreSQL \
		PG:$(DATABASE_URL_OGR) \
		-nlt MULTIPOLYGON \
		-nln whse_basemapping.fwa_watersheds_poly \
		-lco GEOMETRY_NAME=geom \
		-dim XY \
		-lco SPATIAL_INDEX=NONE \
		-lco FID=WATERSHED_FEATURE_ID \
		-preserve_fid \
		-dialect SQLITE \
		-sql "SELECT * FROM FWA_WATERSHEDS_POLY ORDER BY RANDOM()" \
		data/fwa.gpkg
	$(PSQL_CMD) -f sql/tables/source/fwa_watersheds_poly.sql
	touch $@

# linear boundaries - for faster load of large table:
# - promote to multi on load
# - create indexes after load
.make/fwa_linear_boundaries_sp: .make/db data/fwa.gpkg
	$(PSQL_CMD) -c "drop table if exists whse_basemapping.fwa_linear_boundaries_sp"
	ogr2ogr \
		-f PostgreSQL \
		PG:$(DATABASE_URL_OGR)  \
		-nlt MULTILINESTRING \
		-nln whse_basemapping.fwa_linear_boundaries_sp \
		-lco GEOMETRY_NAME=geom \
		-dim XY \
		-lco SPATIAL_INDEX=NONE \
		-lco FID=LINEAR_FEATURE_ID \
		-preserve_fid \
		-dialect SQLITE \
		-sql "SELECT * FROM FWA_LINEAR_BOUNDARIES_SP ORDER BY RANDOM()" \
		data/fwa.gpkg
	$(PSQL_CMD) -f sql/tables/source/fwa_linear_boundaries_sp.sql
	touch $@

# apply fixes
.make/fwa_fixdata: .make/fwa_stream_networks_sp
	$(PSQL_CMD) -f sql/fixes/data.sql  # known errors that may not yet be fixed in source
	touch $@

.make/fwa_fixtypes: $(TABLES_SOURCE_TARGETS)
	$(PSQL_CMD) -f sql/fixes/types.sql # QGIS likes the geometry types to be uniform (sources are mixed singlepart/multipart)
	touch $@

# USA (lower 48) watersheds - USGS HU12 polygons
data/WBD_National_GDB.gdb:
	mkdir -p data
	wget --trust-server-names -qN https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.zip -P data
	unzip -qun data/WBD_National_GDB.zip -d data

# load washington, idaho, montana and alaska
.make/fwa_wbdhu12: .make/db data/WBD_National_GDB.gdb
	$(PSQL_CMD) -c "drop table if exists usgs.wbdhu12"
	ogr2ogr \
		-f PostgreSQL \
		PG:$(DATABASE_URL_OGR)  \
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
		OR states LIKE '%%MT%%' ORDER BY RANDOM()" \
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
	unzip -qun data/hydrosheds.zip -d data

.make/fwa_hydrosheds: data/hybas_ar_lev12_v1c data/hybas_na_lev12_v1c
	# Load _ar_ and _na_ shapefiles
	$(PSQL_CMD) -c "drop table if exists hydrosheds.hybas_ar_lev12_v1c"
	ogr2ogr \
		-f PostgreSQL \
		PG:$(DATABASE_URL_OGR) \
		-t_srs EPSG:3005 \
		-lco SCHEMA=hydrosheds \
		-lco GEOMETRY_NAME=geom \
		-nlt PROMOTE_TO_MULTI \
		data/hybas_ar_lev12_v1c/hybas_ar_lev12_v1c.shp
	$(PSQL_CMD) -c "drop table if exists hydrosheds.hybas_na_lev12_v1c"
	ogr2ogr \
		-f PostgreSQL \
		PG:$(DATABASE_URL_OGR) \
		-t_srs EPSG:3005 \
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

# create value added tables that require just single .sql script
$(TABLES_VALUEADDED_TARGETS): $(TABLES_SOURCE_TARGETS)
	$(PSQL_CMD) -f sql/tables/value_added/$(subst .make/,,$@).sql
	touch $@

# create streams - watersheds lookup
.make/fwa_streams_watersheds_lut: .make/fwa_stream_networks_sp .make/fwa_watersheds_poly .make/fwa_watershed_groups_poly
	# create table
	$(PSQL_CMD) -c "drop table if exists whse_basemapping.fwa_streams_watersheds_lut"
	$(PSQL_CMD) -c "CREATE TABLE whse_basemapping.fwa_streams_watersheds_lut \
					(linear_feature_id bigint, watershed_feature_id integer);"
	# load data per group so inserts are in managable chunks
	for wsg in $(GROUPS) ; do \
		$(PSQL_CMD) -v wsg=$$wsg -f sql/tables/value_added/fwa_streams_watersheds_lut.sql ; \
	done
	# comment and index after load
	$(PSQL_CMD) -c "ALTER TABLE whse_basemapping.fwa_streams_watersheds_lut ADD PRIMARY KEY (linear_feature_id);"
	$(PSQL_CMD) -c "CREATE INDEX ON whse_basemapping.fwa_streams_watersheds_lut (watershed_feature_id);"
	$(PSQL_CMD) -c "COMMENT ON TABLE whse_basemapping.fwa_streams_watersheds_lut IS 'A convenience lookup for quickly relating streams and fundamental watersheds';"
	$(PSQL_CMD) -c "COMMENT ON COLUMN whse_basemapping.fwa_streams_watersheds_lut.linear_feature_id IS 'FWA stream segment unique identifier';"
	$(PSQL_CMD) -c "COMMENT ON COLUMN whse_basemapping.fwa_streams_watersheds_lut.watershed_feature_id IS 'FWA fundamental watershed unique identifer';"
	touch $@

# create a table holding the parent stream order of all streams (where possible)
.make/fwa_stream_order_parent: .make/fwa_stream_networks_sp
	# create table
	$(PSQL_CMD) -c "drop table if exists whse_basemapping.fwa_stream_order_parent"
	$(PSQL_CMD) -c "create table whse_basemapping.fwa_stream_order_parent \
		(blue_line_key integer primary key, stream_order_parent integer);"
	# load data per group so inserts are in managable chunks
	for wsg in $(GROUPS) ; do \
		$(PSQL_CMD) -v wsg=$$wsg -f sql/tables/value_added/fwa_stream_order_parent.sql ; \
	done
	# comment and index after load
	$(PSQL_CMD) -c "COMMENT ON TABLE whse_basemapping.fwa_stream_order_parent IS 'Streams (as blue_line_key) and the stream order of the stream they flow into';"
	$(PSQL_CMD) -c "COMMENT ON COLUMN whse_basemapping.fwa_stream_order_parent.blue_line_key IS 'FWA blue_line_key';"
	$(PSQL_CMD) -c "COMMENT ON COLUMN whse_basemapping.fwa_stream_order_parent.stream_order_parent IS 'The stream_order of the stream the blue_line_key flows into';"
	touch $@

# load FWA functions
.make/fwa_functions: $(TABLES_SOURCE_TARGETS) $(TABLES_VALUEADDED_TARGETS) \
	.make/fwa_stream_networks_sp \
	.make/fwa_watersheds_poly \
	.make/fwa_linear_boundaries_sp \
	.make/fwa_fixtypes \
	.make/fwa_fixdata \
	.make/fwa_hydrosheds \
	.make/fwa_wbdhu12
	$(PSQL_CMD) -f sql/functions/CDB_MakeHexagon.sql
	$(PSQL_CMD) -f sql/functions/ST_Safe_Repair.sql
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

# rather than generating these lookups (slow), download pre-generated data
.make/fwa_waterbodies_upstream_area: .make/db
	wget https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_waterbodies_upstream_area.zip -P data
	unzip -qun data/fwa_waterbodies_upstream_area.zip -d data
	$(PSQL_CMD) -c "drop table if exists whse_basemapping.fwa_waterbodies_upstream_area"
	$(PSQL_CMD) -c "CREATE TABLE whse_basemapping.fwa_waterbodies_upstream_area \
		(linear_feature_id bigint primary key, \
		upstream_lake_ha double precision, \
		upstream_reservoir_ha double precision, \
		upstream_wetland_ha double precision)"
	$(PSQL_CMD) -c "\copy whse_basemapping.fwa_waterbodies_upstream_area FROM 'data/fwa_waterbodies_upstream_area.csv' delimiter ',' csv header"
	touch $@

.make/fwa_watersheds_upstream_area: .make/db
	wget https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_watersheds_upstream_area.zip -P data
	unzip -qun data/fwa_watersheds_upstream_area.zip -d data
	$(PSQL_CMD) -c "drop table if exists whse_basemapping.fwa_watersheds_upstream_area"
	$(PSQL_CMD) -c "CREATE TABLE whse_basemapping.fwa_watersheds_upstream_area \
		(watershed_feature_id integer primary key, \
		upstream_area_ha double precision );"
	$(PSQL_CMD) -c "\copy whse_basemapping.fwa_watersheds_upstream_area FROM 'data/fwa_watersheds_upstream_area.csv' delimiter ',' csv header"
	touch $@

.make/fwa_assessment_watersheds_lut: .make/db
	wget https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_assessment_watersheds_lut.csv.zip -P data
	unzip -qun data/fwa_assessment_watersheds_lut.csv.zip -d data
	$(PSQL_CMD) -c "drop table if exists whse_basemapping.fwa_assessment_watersheds_lut"
	$(PSQL_CMD) -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_lut \
	(watershed_feature_id integer PRIMARY KEY, \
	assmnt_watershed_id integer, \
	watershed_group_code text, \
	watershed_group_id integer)"
	$(PSQL_CMD) -c "\copy whse_basemapping.fwa_assessment_watersheds_lut FROM 'data/fwa_assessment_watersheds_lut.csv' delimiter ',' csv header"
	$(PSQL_CMD) -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_lut (assmnt_watershed_id)"
	touch $@

.make/fwa_assessment_watersheds_streams_lut: .make/db
	wget https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_assessment_watersheds_streams_lut.csv.zip -P data
	unzip -qun data/fwa_assessment_watersheds_streams_lut.csv.zip -d data
	$(PSQL_CMD) -c "drop table if exists whse_basemapping.fwa_assessment_watersheds_streams_lut"
	$(PSQL_CMD) -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_streams_lut \
	(linear_feature_id integer PRIMARY KEY, \
	assmnt_watershed_id integer, \
	watershed_group_code text, \
	watershed_group_id integer)"
	$(PSQL_CMD) -c "\copy whse_basemapping.fwa_assessment_watersheds_streams_lut FROM 'data/fwa_assessment_watersheds_streams_lut.csv' delimiter ',' csv header"
	$(PSQL_CMD) -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_streams_lut (linear_feature_id)"
	touch $@
