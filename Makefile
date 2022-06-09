.PHONY: all clean_targets clean_db

# provide db connection param to psql and ensure scripts stop on error
PSQL = psql $(DATABASE_URL) -v ON_ERROR_STOP=1

# Kludge to get the OGR to work with the container that was built and being
# run in openshift... To address this issue:
# https://github.com/OSGeo/gdal/issues/4570
DATABASE_URL_OGR=$(DATABASE_URL)?application_name=foo

# basic spatial tables that are easily downloadable via wfs
SPATIAL_TABLES = fwa_assessment_watersheds_poly \
	fwa_bays_and_channels_poly \
	fwa_coastlines_sp \
	fwa_glaciers_poly \
	fwa_islands_poly \
	fwa_lakes_poly \
	fwa_linear_boundaries_sp \
	fwa_manmade_waterbodies_poly \
	fwa_obstructions_sp \
	fwa_stream_networks_sp \
	fwa_rivers_poly \
	fwa_watersheds_poly \
	fwa_watershed_groups_poly \
	fwa_wetlands_poly
SPATIAL_TARGETS = $(addprefix .make/,$(SPATIAL_TABLES))
SPATIAL_LOAD = $(patsubst %,%_load,$(SPATIAL_TARGETS))

# code tables and 20k/50k lookup tables are not available via WFS
NON_SPATIAL_TABLES = fwa_edge_type_codes \
	fwa_streams_20k_50k \
	fwa_waterbodies_20k_50k \
	fwa_waterbody_type_codes \
	fwa_watershed_type_codes
NON_SPATIAL_TARGETS = $(addprefix .make/, $(NON_SPATIAL_TABLES))

# custom fwapg tables
VALUEADDED_TABLES = fwa_approx_borders \
	fwa_basins_poly \
	fwa_bcboundary \
	fwa_named_streams \
	fwa_waterbodies
VALUEADDED_TARGETS := $(addprefix .make/,$(VALUEADDED_TABLES))

WSG = $(shell cat wsg.txt)

ALL_TARGETS = .make/db \
	$(SPATIAL_TARGETS) \
	$(NON_SPATIAL_TARGETS) \
	.make/schema_swap \
	.make/wbdhu12 \
	.make/hydrosheds \
	$(VALUEADDED_TARGETS) \
	.make/fwa_functions \
	.make/fwa_streams_watersheds_lut \
	.make/fwa_stream_order_parent \
	.make/fwa_waterbodies_upstream_area \
	.make/fwa_watersheds_upstream_area \
	.make/fwa_assessment_watersheds_lut \
	.make/fwa_assessment_watersheds_streams_lut


all: $(ALL_TARGETS)

# clean make targets
clean_targets:
	rm -Rf .make
	rm -Rf data

# clean out (drop) all loaded and derived tables and functions
clean_db:
	$(PSQL) -f sql/misc/drop_all.sql

# Add required extensions, schemas to db
# ** the database must already exist **
.make/db:
	mkdir -p .make
	$(PSQL) -c "CREATE EXTENSION IF NOT EXISTS postgis"
	$(PSQL) -c "CREATE EXTENSION IF NOT EXISTS ltree"
	$(PSQL) -c "CREATE EXTENSION IF NOT EXISTS intarray"
	$(PSQL) -c "CREATE SCHEMA IF NOT EXISTS whse_basemapping"
	$(PSQL) -c 'CREATE SCHEMA IF NOT EXISTS usgs'
	$(PSQL) -c 'CREATE SCHEMA IF NOT EXISTS hydrosheds'
	$(PSQL) -c "CREATE SCHEMA IF NOT EXISTS postgisftw"	  # for fwapg featureserv functions
	$(PSQL) -c "CREATE SCHEMA IF NOT EXISTS fwapg"	      # for temp load tables, should be empty on completion of load
	$(PSQL) -f sql/functions/CDB_MakeHexagon.sql
	$(PSQL) -f sql/functions/ST_Safe_Repair.sql
	$(PSQL) -f sql/functions/FWA_Downstream.sql
	$(PSQL) -f sql/functions/FWA_Upstream.sql
	touch $@

# get WFS data
$(SPATIAL_LOAD): .make/db
	echo $@
	$(PSQL) -c "drop table if exists fwapg.$(subst .make/,,$@)"
	$(PSQL) -c "create unlogged table fwapg.$(subst .make/,,$@) (data jsonb not null)"
	bcdata cat -p 5000 -v -w 1 $(subst .make/,,whse_basemapping.$(subst _load,,$@)) | \
		$(PSQL) -c "COPY fwapg.$(subst .make/,,$@) (data) FROM STDIN;"
	touch $@

# load from jsonb to staging table and drop the load table
$(SPATIAL_TARGETS): $(SPATIAL_LOAD)
	$(PSQL) -f sql/tables/source/$(subst .make/,,$@).sql
	$(PSQL) -c "drop table if exists fwapg.$(subst .make/,,$@)_load"
	touch $@

# --
# -- code tables
# --
# can't seem to download directly with ogr2ogr /vsizip/vsicurl, so download the entire file with wget
data/FWA_BC.gdb.zip:
	mkdir -p data
	wget --trust-server-names -qN ftp://ftp.geobc.gov.bc.ca/sections/outgoing/bmgs/FWA_Public/FWA_BC.zip -P data
	mv data/FWA_BC.zip $@

$(NON_SPATIAL_TARGETS): data/FWA_BC.gdb.zip .make/db
	# load to temp fwapg schema
	ogr2ogr \
		-f PostgreSQL \
		PG:$(DATABASE_URL_OGR) \
		-nln $(subst .make/,fwapg.,$@)_load \
		data/FWA_BC.gdb.zip \
		$(shell echo $(subst .make/,,$@) | tr '[:lower:]' '[:upper:]')
	# create the target table
	$(PSQL) -f sql/tables/source/$(subst .make/,,$@).sql
	# drop the load table
	$(PSQL) -c "drop table fwapg.$(subst .make/,,$@)_load"
	touch $@

# apply fixes
.make/datafixes: .make/fwa_stream_networks_sp .make/fwa_obstructions_sp
	$(PSQL) -f sql/misc/datafixes.sql  # known FWA errors that may not yet be fixed in source
	touch $@

# go live by switching source fwa tables from staging fwapg schema to whse_basemapping
.make/schema_swap: $(SPATIAL_TARGETS) $(NON_SPATIAL_TARGETS)
	$(foreach tbl,$(subst .make/,,$^), $(PSQL) -c "drop table if exists whse_basemapping.$(tbl)";)
	$(foreach tbl,$(subst .make/,,$^), $(PSQL) -c "alter table fwapg.$(tbl) set schema whse_basemapping";)
	touch $@

# USA (lower 48) watersheds - USGS HU12 polygons
# note that this is possbile to download via /vsizip/vsicurl but a direct download seems faster
data/WBD_National_GDB.zip:
	mkdir -p data
	wget --trust-server-names -qN https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.zip -P data

# load washington, idaho, montana and alaska
.make/wbdhu12: .make/db data/WBD_National_GDB.zip
	$(PSQL) -c "drop table if exists usgs.wbdhu12"
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
		OR states LIKE '%%MT%%'" \
		data/WBD_National_GDB.zip
	# index the columns of interest
	$(PSQL) -c "CREATE INDEX ON usgs.wbdhu12 (huc12)"
	$(PSQL) -c "CREATE INDEX ON usgs.wbdhu12 (tohuc)"
	$(PSQL) -c "COMMENT ON TABLE usgs.wbdhu12 IS 'USGS National Watershed Boundary Dataset, HUC12 level. See https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.xml';"
	$(PSQL) -f sql/functions/FWA_huc12.sql
	touch $@

# For YT, NWT, AB watersheds, use hydrosheds https://www.hydrosheds.org/
# Source hydrosheds shapefiles must be manually downloaded, so I've cached them at hillcrestgeo
.make/hydrosheds: .make/db
	# Load _ar_ and _na_ shapefiles
	$(PSQL) -c "drop table if exists hydrosheds.hybas_ar_lev12_v1c"
	ogr2ogr \
		-f PostgreSQL \
		PG:$(DATABASE_URL_OGR) \
		-t_srs EPSG:3005 \
		-lco SCHEMA=hydrosheds \
		-lco GEOMETRY_NAME=geom \
		-nlt PROMOTE_TO_MULTI \
		/vsizip/vsicurl/https://www.hillcrestgeo.ca/outgoing/public/fwapg/hydrosheds.zip \
		hybas_ar_lev12_v1c
	$(PSQL) -c "drop table if exists hydrosheds.hybas_na_lev12_v1c"
	ogr2ogr \
		-f PostgreSQL \
		PG:$(DATABASE_URL_OGR) \
		-t_srs EPSG:3005 \
		-lco SCHEMA=hydrosheds \
		-lco GEOMETRY_NAME=geom \
		-nlt PROMOTE_TO_MULTI \
		/vsizip/vsicurl/https://www.hillcrestgeo.ca/outgoing/public/fwapg/hydrosheds.zip \
		hybas_na_lev12_v1c
	# combine _ar_ and _na_ into output table hybas_lev12_v1c
	$(PSQL) -c "ALTER TABLE hydrosheds.hybas_na_lev12_v1c DROP COLUMN ogc_fid"
	$(PSQL) -c "ALTER TABLE hydrosheds.hybas_ar_lev12_v1c DROP COLUMN ogc_fid"
	$(PSQL) -c "ALTER TABLE hydrosheds.hybas_na_lev12_v1c RENAME TO hybas_lev12_v1c"
	$(PSQL) -c "INSERT INTO hydrosheds.hybas_lev12_v1c SELECT * FROM hydrosheds.hybas_ar_lev12_v1c"
	$(PSQL) -c "DROP TABLE hydrosheds.hybas_ar_lev12_v1c"
	$(PSQL) -c "ALTER TABLE hydrosheds.hybas_lev12_v1c ALTER COLUMN hybas_id TYPE bigint;" # pk should be integer (ogr loads as numeric)
	$(PSQL) -c "ALTER TABLE hydrosheds.hybas_lev12_v1c ADD PRIMARY KEY (hybas_id)"
	$(PSQL) -c "CREATE INDEX ON hydrosheds.hybas_lev12_v1c (next_down)"
	$(PSQL) -c "COMMENT ON TABLE hydrosheds.hybas_lev12_v1c IS 'HydroBasins for North America from https://www.hydrosheds.org. See source for column documentation';"
	$(PSQL) -f sql/functions/FWA_hydroshed.sql
	touch $@

# create value added tables that require just single .sql script
$(VALUEADDED_TARGETS): $(BASIC_TARGETS)
	$(PSQL) -f sql/tables/value_added/$(subst .make/,,$@).sql
	touch $@

# create streams - watersheds lookup
.make/fwa_streams_watersheds_lut: .make/fwa_stream_networks_sp .make/fwa_watersheds_poly .make/fwa_watershed_groups_poly
	# create table
	$(PSQL) -c "drop table if exists whse_basemapping.fwa_streams_watersheds_lut"
	$(PSQL) -c "CREATE TABLE whse_basemapping.fwa_streams_watersheds_lut \
					(linear_feature_id bigint, watershed_feature_id integer);"
	# load data per group so inserts are in managable chunks
	for wsg in $(GROUPS) ; do \
		$(PSQL) -v wsg=$$wsg -f sql/tables/value_added/fwa_streams_watersheds_lut.sql ; \
	done
	# comment and index after load
	$(PSQL) -c "ALTER TABLE whse_basemapping.fwa_streams_watersheds_lut ADD PRIMARY KEY (linear_feature_id);"
	$(PSQL) -c "CREATE INDEX ON whse_basemapping.fwa_streams_watersheds_lut (watershed_feature_id);"
	$(PSQL) -c "COMMENT ON TABLE whse_basemapping.fwa_streams_watersheds_lut IS 'A convenience lookup for quickly relating streams and fundamental watersheds';"
	$(PSQL) -c "COMMENT ON COLUMN whse_basemapping.fwa_streams_watersheds_lut.linear_feature_id IS 'FWA stream segment unique identifier';"
	$(PSQL) -c "COMMENT ON COLUMN whse_basemapping.fwa_streams_watersheds_lut.watershed_feature_id IS 'FWA fundamental watershed unique identifer';"
	touch $@

# create a table holding the parent stream order of all streams (where possible)
.make/fwa_stream_order_parent: .make/fwa_stream_networks_sp
	# create table
	$(PSQL) -c "drop table if exists whse_basemapping.fwa_stream_order_parent"
	$(PSQL) -c "create table whse_basemapping.fwa_stream_order_parent \
		(blue_line_key integer primary key, stream_order_parent integer);"
	# load data per group so inserts are in managable chunks
	for wsg in $(GROUPS) ; do \
		$(PSQL) -v wsg=$$wsg -f sql/tables/value_added/fwa_stream_order_parent.sql ; \
	done
	# comment and index after load
	$(PSQL) -c "COMMENT ON TABLE whse_basemapping.fwa_stream_order_parent IS 'Streams (as blue_line_key) and the stream order of the stream they flow into';"
	$(PSQL) -c "COMMENT ON COLUMN whse_basemapping.fwa_stream_order_parent.blue_line_key IS 'FWA blue_line_key';"
	$(PSQL) -c "COMMENT ON COLUMN whse_basemapping.fwa_stream_order_parent.stream_order_parent IS 'The stream_order of the stream the blue_line_key flows into';"
	touch $@

# additional FWA functions
.make/fwa_functions: .make/fwa_stream_networks_sp \
	.make/fwa_watersheds_poly \
	$(BASIC_TARGETS) \
	$(VALUEADDED_TARGETS) \
	.make/datafixes \
	.make/hydrosheds \
	.make/wbdhu12
	$(PSQL) -f sql/functions/FWA_SliceWatershedAtPoint.sql
	$(PSQL) -f sql/functions/FWA_WatershedAtMeasure.sql
	$(PSQL) -f sql/functions/FWA_WatershedHex.sql
	$(PSQL) -f sql/functions/FWA_WatershedStream.sql
	$(PSQL) -f sql/functions/FWA_UpstreamBorderCrossings.sql
	touch $@

# rather than generating these lookups (slow), download pre-generated data
.make/fwa_waterbodies_upstream_area: .make/db
	wget https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_waterbodies_upstream_area.zip -P data
	unzip -qun data/fwa_waterbodies_upstream_area.zip -d data
	$(PSQL) -c "drop table if exists whse_basemapping.fwa_waterbodies_upstream_area"
	$(PSQL) -c "CREATE TABLE whse_basemapping.fwa_waterbodies_upstream_area \
		(linear_feature_id bigint primary key, \
		upstream_lake_ha double precision, \
		upstream_reservoir_ha double precision, \
		upstream_wetland_ha double precision)"
	$(PSQL) -c "\copy whse_basemapping.fwa_waterbodies_upstream_area FROM 'data/fwa_waterbodies_upstream_area.csv' delimiter ',' csv header"
	touch $@

.make/fwa_watersheds_upstream_area: .make/db
	wget https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_watersheds_upstream_area.zip -P data
	unzip -qun data/fwa_watersheds_upstream_area.zip -d data
	$(PSQL) -c "drop table if exists whse_basemapping.fwa_watersheds_upstream_area"
	$(PSQL) -c "CREATE TABLE whse_basemapping.fwa_watersheds_upstream_area \
		(watershed_feature_id integer primary key, \
		upstream_area_ha double precision );"
	$(PSQL) -c "\copy whse_basemapping.fwa_watersheds_upstream_area FROM 'data/fwa_watersheds_upstream_area.csv' delimiter ',' csv header"
	touch $@

.make/fwa_assessment_watersheds_lut: .make/db
	wget https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_assessment_watersheds_lut.csv.zip -P data
	unzip -qun data/fwa_assessment_watersheds_lut.csv.zip -d data
	$(PSQL) -c "drop table if exists whse_basemapping.fwa_assessment_watersheds_lut"
	$(PSQL) -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_lut \
	(watershed_feature_id integer PRIMARY KEY, \
	assmnt_watershed_id integer, \
	watershed_group_code text, \
	watershed_group_id integer)"
	$(PSQL) -c "\copy whse_basemapping.fwa_assessment_watersheds_lut FROM 'data/fwa_assessment_watersheds_lut.csv' delimiter ',' csv header"
	$(PSQL) -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_lut (assmnt_watershed_id)"
	touch $@

.make/fwa_assessment_watersheds_streams_lut: .make/db
	wget https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_assessment_watersheds_streams_lut.csv.zip -P data
	unzip -qun data/fwa_assessment_watersheds_streams_lut.csv.zip -d data
	$(PSQL) -c "drop table if exists whse_basemapping.fwa_assessment_watersheds_streams_lut"
	$(PSQL) -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_streams_lut \
	(linear_feature_id integer PRIMARY KEY, \
	assmnt_watershed_id integer, \
	watershed_group_code text, \
	watershed_group_id integer)"
	$(PSQL) -c "\copy whse_basemapping.fwa_assessment_watersheds_streams_lut FROM 'data/fwa_assessment_watersheds_streams_lut.csv' delimiter ',' csv header"
	$(PSQL) -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_streams_lut (linear_feature_id)"
	touch $@
