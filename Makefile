.PHONY: all clean_targets clean_db


SHELL=/bin/bash

# provide db connection param to psql and ensure scripts stop on error
PSQL = psql $(DATABASE_URL) -v ON_ERROR_STOP=1

# Kludge to get the OGR to work with openshift container 
# To avoid this issue, use a newer gdal
# https://github.com/OSGeo/gdal/issues/4570
DATABASE_URL_OGR=$(DATABASE_URL)?application_name=foo

# tables downloadable via via wfs are defined in sql/tables/spatial
SPATIAL_TARGETS=$(basename $(subst sql/tables/spatial/,.make/,$(wildcard sql/tables/spatial/fwa_*.sql)))

# tables not downloadable via wfs are defined in sql/tables/non_spatial
NON_SPATIAL_TARGETS=$(basename $(subst sql/tables/non_spatial/,.make/,$(wildcard sql/tables/non_spatial/*.sql)))

# custom fwapg tables
VALUE_ADDED_TARGETS=$(basename $(subst sql/tables/value_added/,.make/,$(wildcard sql/tables/value_added/*.sql)))

GROUPS = $(shell cat wsg.txt)

ALL_TARGETS = .make/db \
	$(SPATIAL_TARGETS) \
	$(NON_SPATIAL_TARGETS) \
	.make/wbdhu12 \
	.make/hydrosheds \
	$(VALUE_ADDED_TARGETS) \
	.make/fwa_stream_order_parent \
	.make/fwa_streams_watersheds_lut \
	.make/schema_swap \
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
	touch $@

# load spatial tables
.make/fwa_%: sql/tables/spatial/fwa_%.sql .make/db
	# delete existing load table
	set -e ;  $(PSQL) -c "drop table if exists fwapg.$(subst .make/,,$@)"
	# create empty load table
	set -e ; bcdata bc2pg --db_url $(DATABASE_URL) --schema fwapg --schema_only -t $(subst .make/,,whse_basemapping.$@)
	# load tables with many records per-watershed group, and use a 5k page for tables with large features 
	if [ $@ == '.make/fwa_stream_networks_sp' ] || \
		[ $@ == '.make/fwa_linear_boundaries_sp' ] || \
		[ $@ == '.make/fwa_watersheds_poly' ] ; then \
		for wsg in $(GROUPS) ; do \
			set -e ; bcdata bc2pg --db_url $(DATABASE_URL) --schema fwapg -t $(subst .make/,,whse_basemapping.$@) \
			--query "WATERSHED_GROUP_CODE='"$${wsg}"'" \
			--append ; \
		done; \
		for wsg in $(GROUPS) ; do \
			set -e ; $(PSQL) -f $< -v wsg=$$wsg ; \
		done \
	elif [ $@ == '.make/fwa_assessment_watersheds_poly' ] || \
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
# can't seem to download directly with ogr2ogr /vsizip/vsicurl, so download the entire file with wget
data/FWA_BC.gdb.zip:
	mkdir -p data
	wget --trust-server-names -qN ftp://ftp.geobc.gov.bc.ca/sections/outgoing/bmgs/FWA_Public/FWA_BC.zip -P data
	mv data/FWA_BC.zip $@

# load non spatial tables from file to staging schema (fwapg)
.make/%: sql/tables/non_spatial/%.sql data/FWA_BC.gdb.zip .make/db
	# load to temp fwapg schema
	ogr2ogr \
		-f PostgreSQL \
		PG:$(DATABASE_URL_OGR) \
		-nln $(subst .make/,fwapg.,$@)_load \
		data/FWA_BC.gdb.zip \
		$(shell echo $(subst .make/,,$@) | tr '[:lower:]' '[:upper:]')
	# create the target table
	$(PSQL) -f $<
	# drop the load table
	$(PSQL) -c "drop table fwapg.$(subst .make/,,$@)_load"
	touch $@

# apply fixes
.make/datafixes: sql/misc/datafixes.sql $(SPATIAL_TARGETS)
	$(PSQL) -f $<  # fix known FWA errors that may not yet be fixed in source
	touch $@

# create value added tables that require just a single .sql script
.make/%: sql/tables/value_added/%.sql $(SPATIAL_TARGETS) $(NON_SPATIAL_TARGETS) .make/datafixes
	$(PSQL) -f $<
	touch $@

# create streams - watersheds lookup
.make/fwa_streams_watersheds_lut: sql/tables/value_added_chunked/fwa_streams_watersheds_lut.sql .make/fwa_stream_networks_sp .make/fwa_watersheds_poly .make/fwa_watershed_groups_poly
	# create table
	$(PSQL) -c "drop table if exists fwapg.fwa_streams_watersheds_lut"
	$(PSQL) -c "CREATE TABLE fwapg.fwa_streams_watersheds_lut \
					(linear_feature_id bigint, watershed_feature_id integer);"
	# load data per group so inserts are in managable chunks
	for wsg in $(GROUPS) ; do \
		$(PSQL) -v wsg=$$wsg -f $< ; \
	done
	# comment and index after load
	$(PSQL) -c "ALTER TABLE fwapg.fwa_streams_watersheds_lut ADD PRIMARY KEY (linear_feature_id);"
	$(PSQL) -c "CREATE INDEX ON fwapg.fwa_streams_watersheds_lut (watershed_feature_id);"
	$(PSQL) -c "COMMENT ON TABLE fwapg.fwa_streams_watersheds_lut IS 'A convenience lookup for quickly relating streams and fundamental watersheds';"
	$(PSQL) -c "COMMENT ON COLUMN fwapg.fwa_streams_watersheds_lut.linear_feature_id IS 'FWA stream segment unique identifier';"
	$(PSQL) -c "COMMENT ON COLUMN fwapg.fwa_streams_watersheds_lut.watershed_feature_id IS 'FWA fundamental watershed unique identifer';"
	touch $@

# create a table holding the parent stream order of all streams (where possible)
.make/fwa_stream_order_parent: sql/tables/value_added_chunked/fwa_stream_order_parent.sql .make/fwa_stream_networks_sp
	# create table
	$(PSQL) -c "drop table if exists fwapg.fwa_stream_order_parent"
	$(PSQL) -c "create table fwapg.fwa_stream_order_parent \
		(blue_line_key integer primary key, stream_order_parent integer);"
	# load data per group so inserts are in managable chunks
	for wsg in $(GROUPS) ; do \
		$(PSQL) -v wsg=$$wsg -f $< ; \
	done
	# comment and index after load
	$(PSQL) -c "COMMENT ON TABLE fwapg.fwa_stream_order_parent IS 'Streams (as blue_line_key) and the stream order of the stream they flow into';"
	$(PSQL) -c "COMMENT ON COLUMN fwapg.fwa_stream_order_parent.blue_line_key IS 'FWA blue_line_key';"
	$(PSQL) -c "COMMENT ON COLUMN fwapg.fwa_stream_order_parent.stream_order_parent IS 'The stream_order of the stream the blue_line_key flows into';"
	touch $@

# switch non-spatial/value added tables from staging fwapg schema to whse_basemapping
.make/schema_swap: $(NON_SPATIAL_TARGETS) $(VALUE_ADDED_TARGETS) .make/fwa_streams_watersheds_lut .make/fwa_stream_order_parent
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
.make/fwa_functions: .make/schema_swap \
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
