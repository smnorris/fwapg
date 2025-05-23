.PHONY: all clean_targets clean_db

SHELL=/bin/bash

# provide db connection param to psql and ensure scripts stop on error
PSQL = psql $(DATABASE_URL) -v ON_ERROR_STOP=1

# process only groups noted in wsg.txt
GROUPS = $(shell cat wsg.txt)

SPATIAL=$(basename $(subst load/spatial/,.make/,$(wildcard load/spatial/fwa_*.sql)))
SPATIAL_CHUNKED=$(basename $(subst load/spatial_chunked/,.make/,$(wildcard load/spatial_chunked/fwa_*.sql)))
NON_SPATIAL=$(basename $(subst load/non_spatial/,.make/,$(wildcard load/non_spatial/fwa_*.sql)))
VALUE_ADDED=$(basename $(subst load/value_added/,.make/,$(wildcard load/value_added/*.sql)))
VALUE_ADDED_CHUNKED=$(basename $(subst load/value_added_chunked/,.make/,$(wildcard load/value_added_chunked/*.sql)))
EXTRAS=fwa_stream_networks_channel_width \
	fwa_stream_networks_discharge \
	fwa_assessment_watersheds_lut \
	fwa_assessment_watersheds_streams_lut \
	fwa_waterbodies_upstream_area \
	fwa_watersheds_upstream_area \
	fwa_stream_networks_mean_annual_precip


ALL_TARGETS = .make/db \
	$(SPATIAL_CHUNKED) \
	$(SPATIAL) \
	$(NON_SPATIAL) \
	.make/wbdhu12 \
	.make/hydrosheds \
	$(VALUE_ADDED) \
	$(VALUE_ADDED_CHUNKED) \
	.make/fwa_streams_watersheds_lut \
	.make/extras \
	.make/psf


all: $(ALL_TARGETS)

# clean make targets
clean_targets:
	rm -Rf .make
	rm -Rf data

clean_db:
	rm -Rf .make/db
	$(PSQL) -f db/clean.sql

# create extensions/schemas/tables/views/functions
.make/db:
	mkdir -p .make
	mkdir -p data
	cd db && ./create.sh && cd ..
	touch $@

# download
data/FWA_BC.gdb.zip: .make/db
	curl -o $@ https://nrs.objectstore.gov.bc.ca/bchamp/fwapg/FWA_BC.gdb.zip

data/FWA_LINEAR_BOUNDARIES_SP.gdb.zip: .make/db
	curl -o $@ https://nrs.objectstore.gov.bc.ca/bchamp/fwapg/FWA_LINEAR_BOUNDARIES_SP.gdb.zip

data/FWA_WATERSHEDS_POLY.gdb.zip: .make/db
	curl -o $@ https://nrs.objectstore.gov.bc.ca/bchamp/fwapg/FWA_WATERSHEDS_POLY.gdb.zip

data/FWA_STREAM_NETWORKS_SP.gdb.zip: .make/db
	curl -o $@ https://nrs.objectstore.gov.bc.ca/bchamp/fwapg/FWA_STREAM_NETWORKS_SP.gdb.zip

# load the larger tables per watershed group
.make/fwa_stream_networks_sp: data/FWA_STREAM_NETWORKS_SP.gdb.zip .make/db
	# drop/create load table
	$(PSQL) -c "drop table if exists fwapg.fwa_stream_networks_sp"
	bcdata bc2pg --db_url $(DATABASE_URL) --schema fwapg --schema_only -c 1 -t whse_basemapping.fwa_stream_networks_sp
	# load from file to staging table to target table
	for wsg in $(GROUPS) ; do \
		set -e ; $(PSQL) -c "truncate fwapg.fwa_stream_networks_sp" ; \
		set -e; ogr2ogr \
			-f PostgreSQL \
			PG:$(DATABASE_URL) \
			--config PG_USE_COPY YES \
			-nln fwapg.fwa_stream_networks_sp \
			-append \
			-update \
			data/FWA_STREAM_NETWORKS_SP.gdb.zip \
			$$wsg  ; \
		set -e ; $(PSQL) -f load/spatial_chunked/fwa_stream_networks_sp.sql -v wsg=$$wsg ; \
	done
	$(PSQL) -c "drop table fwapg.fwa_stream_networks_sp"
	$(PSQL) -c "vacuum analyze whse_basemapping.fwa_stream_networks_sp"
	# apply data fixes
	$(PSQL) -f load/fixes/fwa_stream_networks_sp.sql
	touch $@

.make/fwa_linear_boundaries_sp: data/FWA_LINEAR_BOUNDARIES_SP.gdb.zip .make/db
	$(PSQL) -c "drop table if exists fwapg.fwa_linear_boundaries_sp"
	bcdata bc2pg --db_url $(DATABASE_URL) --schema fwapg --schema_only -c 1 -t whse_basemapping.fwa_linear_boundaries_sp
	# load from file to staging table
	for wsg in $(GROUPS) ; do \
		set -e ; $(PSQL) -c "truncate fwapg.fwa_linear_boundaries_sp" ; \
		set -e; ogr2ogr \
			-f PostgreSQL \
			PG:$(DATABASE_URL) \
			--config PG_USE_COPY YES \
			-nln fwapg.fwa_linear_boundaries_sp \
			-append \
			-update \
			data/FWA_LINEAR_BOUNDARIES_SP.gdb.zip \
			$$wsg  ; \
		set -e ; $(PSQL) -f load/spatial_chunked/fwa_linear_boundaries_sp.sql -v wsg=$$wsg ; \
	done
	$(PSQL) -c "drop table fwapg.fwa_linear_boundaries_sp"
	$(PSQL) -c "vacuum analyze whse_basemapping.fwa_linear_boundaries_sp"
	touch $@

.make/fwa_watersheds_poly: data/FWA_WATERSHEDS_POLY.gdb.zip .make/db
	$(PSQL) -c "drop table if exists fwapg.fwa_watersheds_poly"
	bcdata bc2pg --db_url $(DATABASE_URL) --schema fwapg --schema_only -c 1 -t whse_basemapping.fwa_watersheds_poly
	# load from file to staging table
	for wsg in $(GROUPS) ; do \
		set -e ; $(PSQL) -c "truncate fwapg.fwa_watersheds_poly" ; \
		set -e; ogr2ogr \
			-f PostgreSQL \
			PG:$(DATABASE_URL) \
			--config PG_USE_COPY YES \
			-nln fwapg.fwa_watersheds_poly \
			-append \
			-update \
			data/FWA_WATERSHEDS_POLY.gdb.zip \
			$$wsg  ; \
		set -e ; $(PSQL) -f load/spatial_chunked/fwa_watersheds_poly.sql -v wsg=$$wsg ; \
	done
	$(PSQL) -c "drop table fwapg.fwa_watersheds_poly"
	$(PSQL) -c "vacuum analyze whse_basemapping.fwa_watersheds_poly"
	touch $@

# load smaller spatial tables from FWA_BC.gdb
.make/fwa_%: load/spatial/fwa_%.sql .make/db data/FWA_BC.gdb.zip
	# delete existing load table
	$(PSQL) -c "drop table if exists fwapg.$(subst .make/,,$@)"
	# create empty load table
	set -e; bcdata bc2pg --db_url $(DATABASE_URL) --schema fwapg --schema_only -c 1 -t $(subst .make/,,whse_basemapping.$@)
	set -e; ogr2ogr \
		-f PostgreSQL \
		PG:$(DATABASE_URL) \
		--config PG_USE_COPY YES \
		-nln fwapg.$(subst .make/,,$@) \
		-append \
		-update \
		-nlt PROMOTE_TO_MULTI \
		data/FWA_BC.gdb.zip \
		$(subst .make/,,$@)
	$(PSQL) -c "truncate whse_basemapping.$(subst .make/,,$@)"
	set -e ; $(PSQL) -f $<
	$(PSQL) -c "drop table if exists fwapg.$(subst .make/,,$@)"
	touch $@

# load non spatial tables
.make/fwa_%: load/non_spatial/fwa_%.sql data/FWA_BC.gdb.zip .make/db
	# load to temp fwapg schema
	ogr2ogr \
		-f PostgreSQL \
		PG:$(DATABASE_URL) \
		--config PG_USE_COPY YES \
		-nln $(subst .make/,fwapg.,$@) \
		data/FWA_BC.gdb.zip \
		$(shell echo $(subst .make/,,$@) | tr '[:lower:]' '[:upper:]')
	# clear any existing data from target then load from fwapg schema
	$(PSQL) -c "truncate whse_basemapping.$(subst .make/,,$@)"
	$(PSQL) -f $<
	# drop the load table
	$(PSQL) -c "drop table fwapg.$(subst .make/,,$@)"
	touch $@

# load value added tables that require just a single .sql script
.make/%: load/value_added/%.sql $(SPATIAL) $(SPATIAL_CHUNKED) $(NON_SPATIAL)
	$(PSQL) -c "truncate whse_basemapping.$(subst .make/,,$@)"
	$(PSQL) -f $<
	touch $@

# load chunked value added tables
.make/%: load/value_added_chunked/%.sql $(SPATIAL) $(SPATIAL_CHUNKED) $(NON_SPATIAL)
	$(PSQL) -c "truncate whse_basemapping.$(subst .make/,,$@)"
	for wsg in $(GROUPS) ; do \
		set -e ; $(PSQL) -f $< -v wsg=$$wsg ; \
	done
	touch $@

# USA (lower 48) watersheds - USGS HU12 polygons
# note that this is possbile to download via /vsizip/vsicurl but a direct download seems faster
data/WBD_National_GDB.zip:
	mkdir -p data
	curl -o data/WBD_National_GDB.zip \
	  https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.zip

# load washington, idaho, montana and alaska
.make/wbdhu12: data/WBD_National_GDB.zip
	$(PSQL) -c "truncate usgs.wbdhu12"
	ogr2ogr \
		-f PostgreSQL \
		PG:$(DATABASE_URL)  \
		--config PG_USE_COPY YES \
		-t_srs EPSG:3005 \
		-nln usgs.wbdhu12 \
		-append \
		-where "states LIKE '%%CN%%' \
		OR states LIKE '%%WA%%' \
		OR states LIKE '%%AK%%' \
		OR states LIKE '%%ID%%' \
		OR states LIKE '%%MT%%'" \
		data/WBD_National_GDB.zip \
		WBDHU12

	touch $@

# For YT, NWT, AB watersheds, use hydrosheds https://www.hydrosheds.org/
# Source hydrosheds shapefiles must be manually downloaded, this downloads a cached copy
.make/hydrosheds: .make/db
	# clear any existing data
	$(PSQL) -c "truncate hydrosheds.hybas_lev12_v1c"
	# Load cached data
	ogr2ogr \
		-f PostgreSQL \
		PG:$(DATABASE_URL) \
		--config PG_USE_COPY YES \
		-t_srs EPSG:3005 \
		-nln hydrosheds.hybas_lev12_v1c \
		-append \
		-update \
		-preserve_fid \
		-where "hybas_id is not null" \
		-nlt PROMOTE_TO_MULTI \
		/vsizip/vsicurl/https://nrs.objectstore.gov.bc.ca/bchamp/fwapg/hydrosheds.gpkg.zip
	touch $@

# rather than generating these lookups/datasets (scripts in /extras), download pre-generated data
.make/extras: .make/db
	for table in $(EXTRAS) ; do \
		echo $$table ;\
		set -e; $(PSQL) -c "truncate whse_basemapping.$$table" ; \
		set -e; $(PSQL) -c "\copy whse_basemapping.$$table FROM PROGRAM 'curl -s https://nrs.objectstore.gov.bc.ca/bchamp/fwapg/$$table.csv.gz | gunzip' delimiter ',' csv header" ; \
	done
	# materialize above to whse_basemapping.fwa_streams, holding the value-added data (for fast upstr/dnstr queries)
	$(PSQL) -f db/sql/extras.sql

# same with conservation unit to streams lookup table
.make/psf:
	echo "psf.pse_conservation_units_streams"
	$(PSQL) -c "truncate psf.pse_conservation_units_streams"
	$(PSQL) -c "\copy psf.pse_conservation_units_streams FROM PROGRAM 'curl -s https://nrs.objectstore.gov.bc.ca/bchamp/fwapg/pse_conservation_units_streams.csv.gz | gunzip' delimiter ',' csv header" ; \
	touch $@