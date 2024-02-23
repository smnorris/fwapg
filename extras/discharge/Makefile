.PHONY: all clean

PSQL = psql $(DATABASE_URL) -v ON_ERROR_STOP=1

TARGETS = data/baseflow.nc \
	data/runoff.nc \
	data/baseflow_yearsum_mean.nc \
	data/runoff_yearsum_mean.nc \
	data/discharge.nc \
	.make/discharge01_raster \
	.make/discharge02_load \
	.make/discharge03_wsd \
	fwa_stream_networks_discharge.gz

TABLES = fwapg.discharge01_raster \
	fwapg.discharge02_load \
	fwapg.discharge03_wsd \
	whse_basemapping.fwa_stream_networks_discharge

WSGS = $(shell $(PSQL) -AtX -c "SELECT DISTINCT b.watershed_group_code \
	FROM fwapg.discharge02_load a \
	INNER JOIN whse_basemapping.fwa_watersheds_poly b \
	ON a.watershed_feature_id = b.watershed_feature_id \
	ORDER BY b.watershed_group_code")

all: $(TARGETS)

## remove all generated files/tables
clean:
	rm -Rf $(TARGETS)
	# drop tables
	for table in $(TABLES) ; do \
		psql -c "DROP TABLE IF EXISTS $$table"; \
	done

## Download baseflow from PCIC
data/baseflow.nc:
	mkdir -p data
	curl -o $@ 'https://data.pacificclimate.org/data/hydro_model_out/allwsbc.TPS_gridded_obs_init.1945to2099.BASEFLOW.nc.nc?BASEFLOW$(shell echo '[13149:24105][][]'|jq -sRr @uri)'

## Download runoff from PCIC
data/runoff.nc:
	mkdir -p data
	curl -o $@ 'https://data.pacificclimate.org/data/hydro_model_out/allwsbc.TPS_gridded_obs_init.1945to2099.RUNOFF.nc.nc?RUNOFF$(shell echo '[13149:24105][][]'|jq -sRr @uri)'

## Create mean annual baseflow
data/baseflow_yearsum_mean.nc: data/baseflow.nc
	cdo -O -b F64 -timmean -yearsum $^ $@

## Create mean annual runoff
data/runoff_yearsum_mean.nc: data/runoff.nc
	cdo -O -b F64 -timmean -yearsum $^ $@

## Add baseflow and runoff to create mean annual discharge (MAD)
data/discharge.nc: data/runoff_yearsum_mean.nc data/baseflow_yearsum_mean.nc
	cdo -b F64 add $^ $@

## Load watershed discharge raster to postgres
.make/discharge01_raster: data/discharge.nc
	mkdir -p .make
	$(PSQL) -c "CREATE EXTENSION IF NOT EXISTS postgis_raster;"
	$(PSQL) -c "DROP TABLE IF EXISTS fwapg.discharge01_raster;"
	raster2pgsql data/discharge.nc fwapg.discharge01_raster -s 4326 | $(PSQL)
	touch $@

## overlay fundamental watersheds with discharge raster
.make/discharge02_load: .make/discharge01_raster
	$(PSQL) -c "CREATE TABLE IF NOT EXISTS fwapg.discharge02_load \
	( \
		watershed_feature_id integer primary key, \
		watershed_group_code text, \
		discharge_mm double precision \
	);"
	$(PSQL) -c "TRUNCATE fwapg.discharge02_load"
	# load PCIC study area (Fraser, Columbia, Peace)
	$(PSQL) -tXA \
	-c "SELECT DISTINCT watershed_group_code \
	    FROM whse_basemapping.fwa_assessment_watersheds_poly \
	    WHERE (wscode_ltree <@ '100'::ltree OR wscode_ltree <@ '300'::ltree OR wscode_ltree <@ '200'::ltree) \
	    ORDER BY watershed_group_code" | parallel $(PSQL) -f sql/discharge02_load.sql -v wsg={1}
	touch $@

# Transfer data from load table to discharge table
.make/discharge03_wsd: .make/discharge02_load
	# Calculates the area weighted annual average flow for each wsd (mad_mm) and coverts to cubic m per s (m3s)
	$(PSQL) -c "CREATE TABLE IF NOT EXISTS fwapg.discharge03_wsd \
	( \
	  watershed_feature_id integer, \
	  watershed_group_code text, \
	  mad_mm double precision, \
	  mad_m3s double precision \
	);"
	$(PSQL) -c "TRUNCATE fwapg.discharge03_wsd"
	parallel --jobs 5 $(PSQL) -f sql/discharge03_wsd.sql -v wsg={1} ::: $(WSGS)
	$(PSQL) -c "ANALYZE whse_basemapping.fwa_watersheds_upstream_area"
	touch $@

## For habitat modelling, it is easier if discharge is per-stream
fwa_stream_networks_discharge.gz: .make/discharge03_wsd
	# Transfer per-watershed discharge data to per-stream
	$(PSQL) -c "truncate whse_basemapping.fwa_stream_networks_discharge"
	for wsg in $(WSGS) ; do \
	  $(PSQL) -f sql/discharge.sql -v wsg=$$wsg ; \
	done
	$(PSQL) -c "drop table fwapg.discharge01_raster"
	$(PSQL) -c "drop table fwapg.discharge02_load"
	$(PSQL) -c "drop table fwapg.discharge03_wsd"
	$(PSQL) -c "\copy whse_basemapping.fwa_stream_networks_discharge TO 'fwa_stream_networks_discharge.csv' DELIMITER ',' CSV HEADER;"
	gzip fwa_stream_networks_discharge.csv
	echo 'Discharge processing complete, see whse_basemapping.fwa_stream_networks_discharge columns mad_mm, mad_m3s'