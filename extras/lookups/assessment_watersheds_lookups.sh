# Create and load lookup tables relating fundamental watersheds and streams to assessment watersheds
# (for quickly relating the tables without needing overlays)

# assmnt watersheds to fundamental watersheds
psql -c "DROP TABLE IF EXISTS whse_basemapping.fwa_assessment_watersheds_lut;"
psql -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_lut
(watershed_feature_id integer PRIMARY KEY,
assmnt_watershed_id integer,
watershed_group_code text,
watershed_group_id integer)"

# load the data (this took 9hrs - there may be some speedups possible)
time psql -t -P border=0,footer=no \
-c "SELECT ''''||watershed_group_code||''''
    FROM whse_basemapping.fwa_watershed_groups_poly
    ORDER BY watershed_group_code" \
  | sed -e '$d' \
  | parallel psql -f sql/load_fwa_assessment_watersheds_lut.sql -v wsg={1}

psql -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_lut (assmnt_watershed_id)"


# assmnt watersheds to streams (this is faster, 30-40min)
psql -c "DROP TABLE IF EXISTS whse_basemapping.fwa_assessment_watersheds_streams_lut;"
psql -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_streams_lut
(linear_feature_id bigint primary key,
watershed_feature_id integer,
watershed_group_code text,
watershed_group_id integer);"

# load the data
time psql -t -P border=0,footer=no \
-c "SELECT ''''||watershed_group_code||''''
    FROM whse_basemapping.fwa_watershed_groups_poly
    ORDER BY watershed_group_code" \
  | sed -e '$d' \
  | parallel psql -f sql/load_fwa_assessment_watersheds_streams_lut.sql -v wsg={1}

psql -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_streams_lut (watershed_feature_id)"


# Above is almost comprehensive. One stream goes missing (it doesn't have the right watershed_group_code)
# SELECT
#   s.linear_feature_id
# FROM whse_basemapping.fwa_stream_networks_sp s
# LEFT OUTER JOIN whse_basemapping.fwa_assessment_watersheds_streams_lut l
# ON s.linear_feature_id = l.linear_feature_id
# WHERE s.edge_type != 6010
# AND l.linear_feature_id IS NULL;
#
#  linear_feature_id
# -------------------
#          832599689

psql -c "INSERT INTO whse_basemapping.fwa_assessment_watersheds_streams_lut
   (linear_feature_id, watershed_feature_id, watershed_group_code, watershed_group_id)
    VALUES (832599689, 15559, 'TABR', 197)"


# dump lookups to file so they don't have to be regenerated every time a db is set up
psql -c "\copy whse_basemapping.fwa_assessment_watersheds_streams_lut TO 'fwa_assessment_watersheds_streams_lut.csv' DELIMITER ',' CSV HEADER;"
psql -c "\copy whse_basemapping.fwa_assessment_watersheds_lut TO 'fwa_assessment_watersheds_lut.csv' DELIMITER ',' CSV HEADER;"