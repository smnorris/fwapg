.PHONY: all clean_targets clean_db

# Note that watersheds and streams are not included in this list,
# they get special treatment
TABLES_SOURCE = fwa_assessment_watersheds_poly \
	fwa_bays_and_channels_poly \
	fwa_coastlines_sp \
	fwa_edge_type_codes \
	fwa_glaciers_poly \
	fwa_islands_poly \
	fwa_lakes_poly \
	fwa_linear_boundaries_sp \
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

TABLES_TEST = fwa_lakes_poly fwa_rivers_poly

# Make all targets
all: .db $(TABLES_TEST) #db $(SOURCE_TABLES) fwa_stream_networks_sp fwa_watersheds_poly

clean_targets:
	rm -Rf $(TABLES_TEST)

clean_db:
	 for table in $(TABLES_TEST); do \
          psql -c "DROP TABLE temp.$$table"; \
        done

# Add required extensions and functions to db
# * the database must already exist *
.db:
	psql -c "CREATE EXTENSION IF NOT EXISTS postgis"
	psql -c "CREATE EXTENSION IF NOT EXISTS ltree"
	psql -c "CREATE EXTENSION IF NOT EXISTS intarray"
	psql -c "CREATE SCHEMA IF NOT EXISTS whse_basemapping"
	touch .db


FWA.gpkg:
	wget --trust-server-names -qN https://www.hillcrestgeo.ca/outgoing/public/fwapg/FWA.zip
	unzip FWA.zip


$(TABLES_TEST): .db FWA.gpkg
	psql -f sql/tables_source/$@.sql
	ogr2ogr \
		-f PostgreSQL \
		-update \
		-append \
		--config PG_USE_COPY YES \
		"PG:host=$(PGHOST) user=$(PGUSER) dbname=$(PGDATABASE) port=$(PGPORT) active_schema=temp" \
		-preserve_fid \
		test.gpkg \
		$@
	touch $@


# streams
# - loaded to temp table
# - measure added to geom on load to output table
# - index after load for some speed gains
fwa_stream_networks_sp: db FWA.gpkg
	ogr2ogr \
		-f PostgreSQL \
		"PG:host=$(PGHOST) user=$(PGUSER) dbname=$(PGDATABASE) port=$(PGPORT) active_schema=temp" \
		-nlt LINESTRING \
		-nln $@_load \
		-s_srs EPSG:3005 \
		-t_srs EPSG:3005 \
		-lco GEOMETRY_NAME=geom \
		-dim XYZ \
		-lco SPATIAL_INDEX=NONE \
		-lco FID=LINEAR_FEATURE_ID \
		-lco FID64=TRUE \
		FWA.gpkg \
		$@.sql
	psql -f sql/tables_source/$@.sql
	psql -c "DROP TABLE whse_basemapping.fwa_stream_networks_sp_load"
	touch $@


# watersheds
# - create the spatial index after load for some speed gains
fwa_watersheds_poly: db FWA.gpkg
	ogr2ogr \
		-f PostgreSQL \
		"PG:host=$(PGHOST) user=$(PGUSER) dbname=$(PGDATABASE) port=$(PGPORT) active_schema=temp" \
		-nlt MULTIPOLYGON \
		-nln $@ \
		-s_srs EPSG:3005 \
		-t_srs EPSG:3005 \
		-lco GEOMETRY_NAME=geom \
		-dim XY \
		-lco SPATIAL_INDEX=NONE \
		-lco FID=WATERSHED_FEATURE_ID \
		FWA.gpkg \
		$@
	psql -f sql/tables_source/$@.sql
	touch $@


# rather than generating them (slow), download pre-generated lookup tables
fwa_assessment_watersheds_lut: db
	wget https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_assessment_watersheds_lut.csv.zip
	unzip fwa_assessment_watersheds_lut.csv.zip
	psql -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_lut
	(watershed_feature_id integer PRIMARY KEY,
	assmnt_watershed_id integer,
	watershed_group_code text,
	watershed_group_id integer)"
	psql -c "\copy whse_basemapping.fwa_assessment_watersheds_lut FROM 'fwa_assessment_watersheds_lut.csv' delimiter ',' csv header"
	psql -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_lut (assmnt_watershed_id)"
	rm fwa_assessment_watersheds_lut.csv.zip
	rm fwa_assessment_watersheds_lut.csv
	touch fwa_assessment_watersheds_lut

fwa_assessment_watersheds_streams_lut: db
	wget https://hillcrestgeo.ca/outgoing/public/fwapg/fwa_assessment_watersheds_streams_lut.csv.zip
	unzip fwa_assessment_watersheds_streams_lut.csv.zip
	psql -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_streams_lut
	(watershed_feature_id integer PRIMARY KEY,
	assmnt_watershed_id integer,
	watershed_group_code text,
	watershed_group_id integer)"
	psql -c "\copy whse_basemapping.fwa_assessment_watersheds_streams_lut FROM 'fwa_assessment_watersheds_streams_lut.csv' delimiter ',' csv header"
	psql -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_streams_lut (watershed_feature_id)"
	rm fwa_assessment_watersheds_streams_lut.csv.zip
	rm fwa_assessment_watersheds_streams_lut.csv


# create additional value added tables
$(TABLES_VALUEADDED): $(TABLES_SOURCE)
	psql -f sql/tables_valueadded/$@.sql
	touch $@

#fwa_basins_poly: fwa_watershed_groups_poly
#	psql -f sql/tables_valueadded/fwa_basins_poly.sql
#	touch $@
#
#fwa_bcboundary: fwa_watershed_groups_poly
#	psql -f sql/tables_valueadded/fwa_bcboundary.sql
#	touch $@
#
#fwa_named_streams: fwa_stream_networks_sp
#	psql -f sql/tables_valueadded/fwa_named_streams.sql
#	touch $@
#
#fwa_waterbodies: fwa_lakes_poly fwa_glaciers_poly fwa_rivers_poly fwa_wetlands_poly fwa_manmade_waterbodies_poly
#	psql -f sql/tables_valueadded/fwa_waterbodies.sql
#	touch $@
#
#fwa_watershed_groups_subdivided: fwa_watershed_groups_poly
#	psql -f sql/tables_valueadded/fwa_watershed_groups_subdivided.sql
#	touch $@
#

# USA watershed - USGS HU12 polygons
wdbhu12: .db
	wget https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.zip
	unzip WBD_National_GDB.zip
	psql -c 'CREATE SCHEMA IF NOT EXISTS usgs'
	# ignore the various errors on load....
	ogr2ogr \
	  -f PostgreSQL \
	  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
	  -t_srs EPSG:3005 \
	  -lco SCHEMA=usgs \
	  -lco GEOMETRY_NAME=geom \
	  -nln wbdhu12 \
	  -nlt MULTIPOLYGON \
	  -dialect SQLITE \
	  -sql "SELECT * FROM WBDHU12 WHERE states LIKE '%%CN%%' OR states LIKE '%%WA%%' OR states LIKE '%%AK%%' OR states LIKE '%%ID%%' OR states LIKE '%%MT%%'" \
	  WBD_National_GDB.gdb
	# index the columns of interest
	psql -c "CREATE INDEX ON usgs.wbdhu12 (huc12)"
	psql -c "CREATE INDEX ON usgs.wbdhu12 (tohuc)"


# For Yukon, NWT, AB watersheds, use hydrosheds https://www.hydrosheds.org/
# source shapefiles must be manually downloaded from source, so I've cached them here:
hydrosheds: .db
	wget https://www.hillcrestgeo.ca/outgoing/public/fwapg/hydrosheds.zip
	unzip hydrosheds.zip

	psql -c 'CREATE SCHEMA IF NOT EXISTS hydrosheds'

	# Write to two tables and combine
	ogr2ogr \
	  -f PostgreSQL \
	  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
	  -lco OVERWRITE=YES \
	  -t_srs EPSG:3005 \
	  -lco SCHEMA=hydrosheds \
	  -lco GEOMETRY_NAME=geom \
	  -nlt PROMOTE_TO_MULTI \
	  hybas_ar_lev12_v1c/hybas_ar_lev12_v1c.shp
	ogr2ogr \
	  -f PostgreSQL \
	  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
	  -t_srs EPSG:3005 \
	  -lco OVERWRITE=YES \
	  -lco SCHEMA=hydrosheds \
	  -lco GEOMETRY_NAME=geom \
	  -nlt PROMOTE_TO_MULTI \
	  hybas_na_lev12_v1c/hybas_na_lev12_v1c.shp

	psql -c "ALTER TABLE hydrosheds.hybas_na_lev12_v1c DROP COLUMN ogc_fid"
	psql -c "ALTER TABLE hydrosheds.hybas_ar_lev12_v1c DROP COLUMN ogc_fid"

	psql -c "ALTER TABLE hydrosheds.hybas_na_lev12_v1c RENAME TO hybas_lev12_v1c"
	psql -c "INSERT INTO hydrosheds.hybas_lev12_v1c SELECT * FROM hydrosheds.hybas_ar_lev12_v1c"
	psql -c "DROP TABLE hydrosheds.hybas_ar_lev12_v1c"

	# ogr loads the pk as a numeric, switch to integer
	psql -c "ALTER TABLE hydrosheds.hybas_lev12_v1c ALTER COLUMN hybas_id TYPE bigint;"

	psql -c "ALTER TABLE hydrosheds.hybas_lev12_v1c ADD PRIMARY KEY (hybas_id)"
	psql -c "CREATE INDEX ON hydrosheds.hybas_lev12_v1c (next_down)"


# load FWA functions
.functions: $(TABLES_SOURCE) $(TABLES_VALUEADDED) hydrosheds wdbhu12
	# As some of these live in postgisftw schema (for access via pg_featureserv),
	# we add this schema to default search path for this database.
	psql -c "CREATE SCHEMA IF NOT EXISTS postgisftw"
	psql -c "ALTER database "$PGDATABASE" SET search_path TO "$PGUSER", public, topology, sde, postgisftw;"
	psql -f sql/functions/hydroshed.sql
	psql -f sql/functions/CDB_MakeHexagon.sql
	psql -f sql/functions/ST_Safe_Repair.sql
	psql -f sql/functions/ST_Safe_Difference.sql
	psql -f sql/functions/ST_Safe_Intersection.sql
	psql -f sql/functions/FWA_IndexPoint.sql
	psql -f sql/functions/FWA_Upstream.sql
	psql -f sql/functions/FWA_Downstream.sql
	psql -f sql/functions/FWA_LengthDownstream.sql
	psql -f sql/functions/FWA_LengthInstream.sql
	psql -f sql/functions/FWA_LengthUpstream.sql
	psql -f sql/functions/FWA_UpstreamBorderCrossings.sql
	psql -f sql/functions/FWA_SliceWatershedAtPoint.sql
	psql -f sql/functions/FWA_WatershedExBC.sql
	psql -f sql/functions/FWA_WatershedAtMeasure.sql
	psql -f sql/functions/FWA_WatershedHex.sql
	psql -f sql/functions/FWA_WatershedStream.sql
	psql -f sql/functions/FWA_LocateAlong.sql
	psql -f sql/functions/FWA_LocateAlongInterval.sql
	touch $@

# apply some data fixes that have not yet made it into the warehouse
.fixes: $(TABLES_SOURCE)
	psql -f sql/fixes/fixes.sql
	touch $@