.PHONY: all clean_targets clean_db


SHELL=/bin/bash

# provide db connection param to psql and ensure scripts stop on error
PSQL = psql $(DATABASE_URL) -v ON_ERROR_STOP=1

# Kludge to get the OGR to work with openshift container 
# To avoid this issue, use a newer gdal
# https://github.com/OSGeo/gdal/issues/4570
DATABASE_URL_OGR=$(DATABASE_URL)?application_name=foo

# tables downloadable via via wfs are defined in sql/tables/spatial
SPATIAL_BASIC=$(basename $(subst sql/tables/spatial/basic/,.make/,$(wildcard sql/tables/spatial/basic/fwa_*.sql)))
SPATIAL_LARGE=$(basename $(subst sql/tables/spatial/large/,.make/,$(wildcard sql/tables/spatial/large/fwa_*.sql)))

WSG = $(shell cat wsg.txt)

STREAM_TARGETS = $(addprefix .make/fwa_stream_networks_sp_, $(WSG))
WSD_TARGETS = $(addprefix .make/fwa_watersheds_poly_, $(WSG))
LBD_TARGETS = $(addprefix .make/fwa_linear_boundaries_sp_, $(WSG))

# tables not downloadable via wfs are defined in sql/tables/non_spatial
NON_SPATIAL_TARGETS=$(basename $(subst sql/tables/non_spatial/,.make/,$(wildcard sql/tables/non_spatial/fwa_*.sql)))

# custom fwapg tables
VALUE_ADDED_TARGETS=$(basename $(subst sql/tables/value_added/,.make/,$(wildcard sql/tables/value_added/*.sql)))

GROUPS = $(shell cat wsg.txt)

ALL_TARGETS = .make/db \
	$(SPATIAL_LARGE) \
	$(SPATIAL_BASIC) \
	$(NON_SPATIAL_TARGETS) \
	.make/wbdhu12 \
	.make/hydrosheds \
	$(VALUE_ADDED_TARGETS) \
	.make/fwa_streams_watersheds_lut \
	.make/fwa_functions \
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
.make/db: sql/functions/FWA_Downstream.sql sql/functions/FWA_Upstream.sql sql/tables/spatial/schema.sql
	mkdir -p .make
	$(PSQL) -c "CREATE EXTENSION IF NOT EXISTS postgis with schema public"
	$(PSQL) -c "CREATE EXTENSION IF NOT EXISTS ltree with schema public"
	$(PSQL) -c "CREATE EXTENSION IF NOT EXISTS intarray with schema public"
	$(PSQL) -c "CREATE SCHEMA IF NOT EXISTS whse_basemapping"
	$(PSQL) -c 'CREATE SCHEMA IF NOT EXISTS usgs'
	$(PSQL) -c 'CREATE SCHEMA IF NOT EXISTS hydrosheds'
	$(PSQL) -c "CREATE SCHEMA IF NOT EXISTS postgisftw"	  # for fwapg featureserv functions
	$(PSQL) -c "CREATE SCHEMA IF NOT EXISTS fwapg"	      # for temp load tables, should be empty on completion of load
	$(PSQL) -f sql/functions/CDB_MakeHexagon.sql
	$(PSQL) -f sql/functions/ST_Safe_Repair.sql
	$(PSQL) -f sql/functions/FWA_Downstream.sql
	$(PSQL) -f sql/functions/FWA_Upstream.sql
	$(PSQL) -f sql/tables/spatial/schema.sql              
	$(PSQL) -f sql/tables/non_spatial/schema.sql          
	touch $@

# spell out the loading of streams/linear boundaries/watersheds per wsg
# create load tables for larger spatial tables
.make/spatial_large_load: .make/db
	# delete existing load tables
	$(PSQL) -c "drop table if exists fwapg.fwa_stream_networks_sp"
	$(PSQL) -c "drop table if exists fwapg.fwa_linear_boundaries_sp"
	$(PSQL) -c "drop table if exists fwapg.fwa_watersheds_poly"
	# create empty load tables
	bcdata bc2pg --db_url $(DATABASE_URL) --schema fwapg --schema_only -t whse_basemapping.fwa_stream_networks_sp
	bcdata bc2pg --db_url $(DATABASE_URL) --schema fwapg --schema_only -t whse_basemapping.fwa_linear_boundaries_sp
	bcdata bc2pg --db_url $(DATABASE_URL) --schema fwapg --schema_only -t whse_basemapping.fwa_watersheds_poly
	touch $@

$(STREAM_TARGETS): .make/spatial_large_load
	$(PSQL) -c "delete from fwapg.fwa_stream_networks_sp where watershed_group_code = '$(subst .make/fwa_stream_networks_sp_,,$@)'"
	# load to staging schema
	bcdata bc2pg --db_url $(DATABASE_URL) -t \
		--schema fwapg \
		--query "WATERSHED_GROUP_CODE = '$(subst .make/fwa_stream_networks_sp_,,$@)'" \
		--append \
		whse_basemapping.fwa_stream_networks_sp
	touch $@

$(LBD_TARGETS): .make/spatial_large_load
	$(PSQL) -c "delete from fwapg.fwa_linear_boundaries_sp where watershed_group_code = '$(subst .make/fwa_linear_boundaries_sp_,,$@)'"
	# load to staging schema
	bcdata bc2pg --db_url $(DATABASE_URL) -t \
		--schema fwapg \
		--query "WATERSHED_GROUP_CODE = '$(subst .make/fwa_linear_boundaries_sp_,,$@)'" \
		--append \
		whse_basemapping.fwa_linear_boundaries_sp
	touch $@

$(WSD_TARGETS): .make/spatial_large_load
	$(PSQL) -c "delete from fwapg.fwa_watersheds_poly where watershed_group_code = '$(subst .make/fwa_linear_boundaries_sp_,,$@)'"
	# load to staging schema
	bcdata bc2pg --db_url $(DATABASE_URL) -t \
		--schema fwapg \
		--query "WATERSHED_GROUP_CODE = '$(subst .make/fwa_watersheds_poly_,,$@)'" \
		--append \
		whse_basemapping.fwa_watersheds_poly
	touch $@

# copy data from fwapg to whse_basemapping
.make/fwa_stream_networks_sp: $(STREAM_TARGETS)
	# build the lookups
	$(PSQL) -f sql/tables/temp/fwa_stream_order_max.sql
	$(PSQL) -c "drop table if exists fwapg.fwa_stream_order_parent"
	$(PSQL) -c "create table fwapg.fwa_stream_order_parent \
		(blue_line_key integer primary key, stream_order_parent integer);"
	for wsg in $(GROUPS) ; do \
		$(PSQL) -v wsg=$$wsg -f sql/tables/temp/fwa_stream_order_parent.sql ; \
	done
	# load data per group so inserts are in managable chunks
	for wsg in $(GROUPS) ; do \
		set -e ; $(PSQL) -f sql/tables/spatial/large/fwa_stream_networks_sp.sql -v wsg=$$wsg ; \
	done
	$(PSQL) -c "drop table fwapg.fwa_stream_order_parent"
	$(PSQL) -c "drop table fwapg.fwa_stream_order_max"
	$(PSQL) -c "drop table fwapg.fwa_stream_networks_sp"
	$(PSQL) -c "vacuum analyze whse_basemapping.fwa_stream_networks_sp"
	# apply data fixes
	$(PSQL) -f sql/misc/fixes_fwa_stream_networks_sp.sql
	touch $@

.make/fwa_linear_boundaries_sp: $(LBD_TARGETS)
	for wsg in $(GROUPS) ; do \
		set -e ; $(PSQL) -f sql/tables/spatial/large/fwa_linear_boundaries_sp.sql -v wsg=$$wsg ; \
	done
	$(PSQL) -c "drop table fwapg.fwa_linear_boundaries_sp"
	$(PSQL) -c "vacuum analyze whse_basemapping.fwa_linear_boundaries_sp"
	touch $@

.make/fwa_watersheds_poly: $(WSD_TARGETS)
	for wsg in $(GROUPS) ; do \
		set -e ; $(PSQL) -f sql/tables/spatial/large/fwa_watersheds_poly.sql -v wsg=$$wsg ; \
	done
	$(PSQL) -c "drop table fwapg.fwa_watersheds_poly"
	$(PSQL) -c "vacuum analyze whse_basemapping.fwa_watersheds_poly"
	touch $@

# load spatial tables with not so many records. Requires loading streams first because local code for
# obstacles comes from streams
.make/fwa_%: sql/tables/spatial/basic/fwa_%.sql .make/fwa_stream_networks_sp
	# delete existing load table
	$(PSQL) -c "drop table if exists fwapg.$(subst .make/,,$@)"
	# create empty load table
	bcdata bc2pg --db_url $(DATABASE_URL) --schema fwapg --schema_only -t $(subst .make/,,whse_basemapping.$@)
	# load these tables with larger features in smaller chunks to save memory
	if [ $@ == '.make/fwa_assessment_watersheds_poly' ] || \
		[ $@ == '.make/fwa_named_watersheds_poly' ] || \
		[ $@ == '.make/fwa_watershed_groups_poly' ] || \
		[ $@ == '.make/fwa_wetlands_poly' ] ; then \
		set -e ; bcdata bc2pg --db_url $(DATABASE_URL) --schema fwapg --append -p 5000 -t $(subst .make/,,whse_basemapping.$@) ; \
		$(PSQL) -c "truncate whse_basemapping.$(subst .make/,,$@)" ; \
		set -e ; $(PSQL) -f $< ; \
	else \
		set -e ; bcdata bc2pg --db_url $(DATABASE_URL) --schema fwapg --append -t $(subst .make/,,whse_basemapping.$@) ; \
		$(PSQL) -c "truncate whse_basemapping.$(subst .make/,,$@)" ; \
		set -e ; $(PSQL) -f $< ; \
	fi
	$(PSQL) -c "drop table if exists fwapg.$(subst .make/,,$@)"
	touch $@

# get non spatial data from FTP
# file name is not quite right for direct access via /vsizip/vsicurl - download the entire file with wget
data/FWA_BC.gdb.zip:
	mkdir -p data
	wget --trust-server-names -qN ftp://ftp.geobc.gov.bc.ca/sections/outgoing/bmgs/FWA_Public/FWA_BC.zip -P data
	mv data/FWA_BC.zip $@

# load non spatial tables 
.make/fwa_%: sql/tables/non_spatial/fwa_%.sql data/FWA_BC.gdb.zip .make/db
	# load to temp fwapg schema
	ogr2ogr \
		-f PostgreSQL \
		PG:$(DATABASE_URL_OGR) \
		-nln $(subst .make/,fwapg.,$@) \
		data/FWA_BC.gdb.zip \
		$(shell echo $(subst .make/,,$@) | tr '[:lower:]' '[:upper:]')
	# clear any existing data from target then load from fwapg schema
	$(PSQL) -c "truncate whse_basemapping.$(subst .make/,,$@)"
	$(PSQL) -f $<
	# drop the load table
	$(PSQL) -c "drop table fwapg.$(subst .make/,,$@)"
	touch $@

# create value added tables that require just a single .sql script
.make/%: sql/tables/value_added/%.sql $(SPATIAL_BASIC) $(SPATIAL_LARGE) $(NON_SPATIAL_TARGETS)
	$(PSQL) -f $<
	touch $@

# create streams - watersheds lookup
.make/fwa_streams_watersheds_lut: sql/tables/value_added_chunked/fwa_streams_watersheds_lut.sql .make/fwa_stream_networks_sp .make/fwa_watersheds_poly .make/fwa_watershed_groups_poly
	# create table
	$(PSQL) -c "drop table if exists whse_basemapping.fwa_streams_watersheds_lut"
	$(PSQL) -c "CREATE TABLE whse_basemapping.fwa_streams_watersheds_lut \
					(linear_feature_id bigint, watershed_feature_id integer);"
	# load data per group so inserts are in managable chunks
	for wsg in $(GROUPS) ; do \
		$(PSQL) -v wsg=$$wsg -f $< ; \
	done
	# comment and index after load
	$(PSQL) -c "ALTER TABLE whse_basemapping.fwa_streams_watersheds_lut ADD PRIMARY KEY (linear_feature_id);"
	$(PSQL) -c "CREATE INDEX ON whse_basemapping.fwa_streams_watersheds_lut (watershed_feature_id);"
	$(PSQL) -c "COMMENT ON TABLE whse_basemapping.fwa_streams_watersheds_lut IS 'A convenience lookup for quickly relating streams and fundamental watersheds';"
	$(PSQL) -c "COMMENT ON COLUMN whse_basemapping.fwa_streams_watersheds_lut.linear_feature_id IS 'FWA stream segment unique identifier';"
	$(PSQL) -c "COMMENT ON COLUMN whse_basemapping.fwa_streams_watersheds_lut.watershed_feature_id IS 'FWA fundamental watershed unique identifer';"
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
		-where "states LIKE '%%CN%%' \
		OR states LIKE '%%WA%%' \
		OR states LIKE '%%AK%%' \
		OR states LIKE '%%ID%%' \
		OR states LIKE '%%MT%%'" \
		data/WBD_National_GDB.zip \
		WBDHU12
	# index the columns of interest
	$(PSQL) -c "CREATE INDEX ON usgs.wbdhu12 (huc12)"
	$(PSQL) -c "CREATE INDEX ON usgs.wbdhu12 (tohuc)"
	$(PSQL) -c "COMMENT ON TABLE usgs.wbdhu12 IS 'USGS National Watershed Boundary Dataset, HUC12 level. See https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.xml';"
	$(PSQL) -f sql/functions/FWA_huc12.sql
	touch $@

# For YT, NWT, AB watersheds, use hydrosheds https://www.hydrosheds.org/
# Source hydrosheds shapefiles must be manually downloaded, so I've cached them at hillcrestgeo
.make/hydrosheds: .make/db
	# drop existing merged table
	$(PSQL) -c "drop table if exists hydrosheds.hybas_lev12_v1c"
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
	$(PSQL) -f sql/functions/FWA_hydroshed.sql  # internal function, requires hydroshed id as input
	$(PSQL) -f sql/functions/hydroshed.sql      # published function, point as (x, y, srid) as input
	touch $@

# additional FWA functions
.make/fwa_functions: $(SPATIAL_BASIC) $(SPATIAL_LARGE) $(NON_SPATIAL_TARGETS) $(VALUE_ADDED_TARGETS) .make/fwa_streams_watersheds_lut \
	.make/hydrosheds \
	.make/wbdhu12
	$(PSQL) -f sql/functions/FWA_SliceWatershedAtPoint.sql
	$(PSQL) -f sql/functions/FWA_WatershedAtMeasure.sql
	$(PSQL) -f sql/functions/FWA_WatershedHex.sql
	$(PSQL) -f sql/functions/FWA_WatershedStream.sql
	$(PSQL) -f sql/functions/FWA_UpstreamBorderCrossings.sql
	$(PSQL) -f sql/functions/FWA_IndexPoint.sql
	$(PSQL) -f sql/functions/FWA_LocateAlong.sql
	$(PSQL) -f sql/functions/FWA_LocateAlongInterval.sql
	touch $@

# rather than generating these lookups (slow), download pre-generated data
.make/fwa_waterbodies_upstream_area: .make/db
	wget --trust-server-names -qN https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_waterbodies_upstream_area.zip -P data
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
	wget --trust-server-names -qN https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_watersheds_upstream_area.zip -P data
	unzip -qun data/fwa_watersheds_upstream_area.zip -d data
	$(PSQL) -c "drop table if exists whse_basemapping.fwa_watersheds_upstream_area"
	$(PSQL) -c "CREATE TABLE whse_basemapping.fwa_watersheds_upstream_area \
		(watershed_feature_id integer primary key, \
		upstream_area_ha double precision );"
	$(PSQL) -c "\copy whse_basemapping.fwa_watersheds_upstream_area FROM 'data/fwa_watersheds_upstream_area.csv' delimiter ',' csv header"
	touch $@

.make/fwa_assessment_watersheds_lut: .make/db
	wget --trust-server-names -qN https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_assessment_watersheds_lut.csv.zip -P data
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
	wget --trust-server-names -qN https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_assessment_watersheds_streams_lut.csv.zip -P data
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
