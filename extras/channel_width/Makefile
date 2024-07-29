# --------
# calculate channel width - measured / mapped / modelled
# --------

.PHONY: all clean

# point psql to db and stop on errors
PSQL=psql $(DATABASE_URL) -v ON_ERROR_STOP=1

WSG = $(shell $(PSQL) -AtX -c "SELECT watershed_group_code FROM whse_basemapping.fwa_watershed_groups_poly ORDER BY watershed_group_code")

GENERATED_FILES = .make/channel_width_measured \
	.make/channel_width_mapped \
	channel_width_analysis.csv \
	.make/channel_width_modelled \
	fwa_stream_networks_channel_width.gz

GENERATED_TABLES =  whse_fish.fiss_stream_sample_sites_sp\
	fwapg.channel_width_measured \
	fwapg.channel_width_mapped \
	fwapg.channel_width_analysis \
	fwapg.channel_width_modelled

all: $(GENERATED_FILES)

# --------
# MEASURED
# --------
.make/channel_width_measured: sql/channel_width_measured.sql sql/fiss_stream_sample_sites_events.sql
	mkdir -p .make
	# load to fwapg schema, these are just used temporarily
	bcdata bc2pg --schema fwapg WHSE_FISH.FISS_STREAM_SAMPLE_SITES_SP
	bcdata bc2pg --schema fwapg WHSE_FISH.PSCIS_ASSESSMENT_SVW
	# bcfishpass crossings should be separated from streams to make this much more efficient
	curl -o bcfishpass.gpkg.zip https://bcfishpass.s3.us-west-2.amazonaws.com/freshwater_fish_habitat_accessibility_MODEL.gpkg.zip
	ogr2ogr \
		-f PostgreSQL \
		PG:$(DATABASE_URL) \
		-nln fwapg.pscis_crossings \
		-overwrite \
		-where "crossing_source = 'PSCIS'" \
		/vsizip/bcfishpass.gpkg.zip \
		crossings
	rm bcfishpass.gpkg.zip
	# match stream sample sites to streams
	$(PSQL) -f sql/fiss_stream_sample_sites_events.sql
	# Now load the measured channel widths where we have them, averaging measurements on the same stream
	$(PSQL) -f sql/channel_width_measured.sql
	touch $@

# --------
# MAPPED
# --------
.make/channel_width_mapped:
	$(PSQL) -c "DROP TABLE IF EXISTS fwapg.channel_width_mapped;"
	$(PSQL) -c "CREATE TABLE fwapg.channel_width_mapped ( \
	  linear_feature_id bigint, \
	  watershed_group_code text, \
	  channel_width_mapped numeric, \
	  cw_stddev numeric, \
	  UNIQUE (linear_feature_id) );"
	# load each watershed group seperately, in parallel
	parallel $(PSQL) -f sql/channel_width_mapped.sql -v wsg={1} ::: $(WSG)
	$(PSQL) -c "CREATE INDEX ON fwapg.channel_width_mapped (linear_feature_id)"
	touch $@

# --------
# REPORT - report on measured and mapped data points for generating the model
# --------
channel_width_analysis.csv: .make/channel_width_mapped .make/channel_width_measured
	$(PSQL) -f sql/channel_width_analysis.sql
	psql2csv $(DATABASE_URL) "SELECT * FROM fwapg.channel_width_analysis" > channel_width_analysis.csv

# --------
# MODELLED
# --------
.make/channel_width_modelled: .make/channel_width_measured .make/channel_width_mapped sql/channel_width_modelled.sql
	# run the model as a single query, it doesn't take too long to process
	$(PSQL) -f sql/channel_width_modelled.sql
	touch $@

# --------
# OUTPUT TABLE
# --------
# combine the measured/mapped/modelled data into a single table for easy relating to streams table
fwa_stream_networks_channel_width.gz: .make/channel_width_modelled sql/channel_width.sql
	$(PSQL) -c "truncate whse_basemapping.fwa_stream_networks_channel_width;"
	parallel $(PSQL) -f sql/channel_width.sql -v wsg={1} ::: $(WSG)
	# dump output to file
	$(PSQL) -c "\copy whse_basemapping.fwa_stream_networks_channel_width TO 'fwa_stream_networks_channel_width.csv' DELIMITER ',' CSV HEADER;"
	gzip fwa_stream_networks_channel_width.csv


clean:
	rm -f .make
	# drop all temp target tables
	for table in $(GENERATED_TABLES); do \
		$(PSQL) -c "DROP TABLE IF EXISTS "$$table ;\
	done
	# drop the source tables
	$(PSQL) -c "drop table fwapg.fiss_stream_sample_sites_sp"
	$(PSQL) -c "drop table fwapg.pscis_assessment_svw"
