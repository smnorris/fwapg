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

TABLES_TEST = fwa_lakes_poly fwa_rivers_poly

# Make all targets
all: .db $(TABLES_SOURCE) fwa_stream_networks_sp fwa_watersheds_poly #.fix_data .fix_types wdbhu12 hydrosheds .functions

clean_targets:
	rm -Rf $(TABLES_TEST)

clean_db:
	 for table in $(TABLES_TEST); do \
          psql -c "DROP TABLE whse_basemapping.$$table"; \
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

PGOGR_SCHEMA = "PG:host=$(PGHOST) user=$(PGUSER) dbname=$(PGDATABASE) port=$(PGPORT) active_schema=whse_basemapping"
PGOGR = "PG:host=$(PGHOST) user=$(PGUSER) dbname=$(PGDATABASE) port=$(PGPORT)"

$(TABLES_SOURCE): .db FWA.gpkg
	psql -f sql/tables/source/$@.sql
	ogr2ogr \
		-f PostgreSQL \
		-update \
		-append \
		--config PG_USE_COPY YES \
		$(PGOGR_SCHEMA) \
		-preserve_fid \
		FWA.gpkg \
		$@
	touch $@

# streams
# - loaded to temp table
# - measure added to geom on load to output table
# - index after load for some speed gains
fwa_stream_networks_sp: .db FWA.gpkg
	ogr2ogr \
		-f PostgreSQL \
		$(PGOGR_SCHEMA) \
		-nlt LINESTRING \
		-nln $@_load \
		-lco GEOMETRY_NAME=geom \
		-dim XYZ \
		-lco SPATIAL_INDEX=NONE \
		-lco FID=LINEAR_FEATURE_ID \
		-lco FID64=TRUE \
		FWA.gpkg \
		$@
	psql -f sql/tables/source/$@.sql
	touch $@

# watersheds - for faster load of large table:
# - promote to multi on load
# - create indexes after load
fwa_watersheds_poly: .db FWA.gpkg
	ogr2ogr \
		-f PostgreSQL \
		$(PGOGR_SCHEMA) \
		-nlt MULTIPOLYGON \
		-nln $@ \
		-lco GEOMETRY_NAME=geom \
		-dim XY \
		-lco SPATIAL_INDEX=NONE \
		-lco FID=WATERSHED_FEATURE_ID \
		FWA.gpkg \
		$@
	psql -f sql/tables/source/$@.sql
	touch $@

# linear boundaries - for faster load of large table:
# - promote to multi on load
# - create indexes after load
fwa_linear_boundaries_sp: db FWA.gpkg
	ogr2ogr \
		-f PostgreSQL \
		$(PGOGR_SCHEMA) \
		-nlt MULTILINESTRING \
		-nln $@ \
		-lco GEOMETRY_NAME=geom \
		-dim XY \
		-lco SPATIAL_INDEX=NONE \
		-lco FID=LINEAR_FEATURE_ID \
		FWA.gpkg \
		$@
	psql -f sql/tables/source/$@.sql
	touch $@

# apply fixes
.fix_data: fwa_stream_networks_sp
	psql -f sql/fixes/data.sql  # known errors that may not yet be fixed in source
	touch $@

.fix_types: $(TABLES_SOURCE)
	psql -f sql/fixes/types.sql # QGIS likes the geometry types to be uniform (sources are mixed singlepart/multipart)
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

# USA (lower 48) watersheds - USGS HU12 polygons
wdbhu12: .db
	wget https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/WBD/National/GDB/WBD_National_GDB.zip
	unzip WBD_National_GDB.zip
	psql -c 'CREATE SCHEMA IF NOT EXISTS usgs'
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
	psql -c "CREATE INDEX ON usgs.wbdhu12 (huc12)"
	psql -c "CREATE INDEX ON usgs.wbdhu12 (tohuc)"


# For YT, NWT, AB watersheds, use hydrosheds https://www.hydrosheds.org/
# Source shapefiles must be manually downloaded, so I've cached them here:
hydrosheds: .db
	wget https://www.hillcrestgeo.ca/outgoing/public/fwapg/hydrosheds.zip
	unzip hydrosheds.zip
	psql -c 'CREATE SCHEMA IF NOT EXISTS hydrosheds'
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
	psql -c "ALTER TABLE hydrosheds.hybas_na_lev12_v1c DROP COLUMN ogc_fid"
	psql -c "ALTER TABLE hydrosheds.hybas_ar_lev12_v1c DROP COLUMN ogc_fid"
	psql -c "ALTER TABLE hydrosheds.hybas_na_lev12_v1c RENAME TO hybas_lev12_v1c"
	psql -c "INSERT INTO hydrosheds.hybas_lev12_v1c SELECT * FROM hydrosheds.hybas_ar_lev12_v1c"
	psql -c "DROP TABLE hydrosheds.hybas_ar_lev12_v1c"
	psql -c "ALTER TABLE hydrosheds.hybas_lev12_v1c ALTER COLUMN hybas_id TYPE bigint;" # pk should be integer (ogr loads as numeric)
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

