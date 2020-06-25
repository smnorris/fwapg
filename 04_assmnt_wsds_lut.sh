# create a lookup relating fundamental watersheds to assessment watersheds,
# (for quickly relating the two tables without needing an overlay)

psql -c "DROP TABLE IF EXISTS whse_basemapping.fwa_assessment_watersheds_lut;"
psql -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_lut
(watershed_feature_id integer PRIMARY KEY,
assmnt_watershed_id integer,
watershed_group_code text,
watershed_group_id integer)"

# load the data (this took 9hrs - there may be some speedups possible!)
time psql -t -P border=0,footer=no \
-c "SELECT ''''||watershed_group_code||''''
    FROM whse_basemapping.fwa_watershed_groups_poly
    ORDER BY watershed_group_code" \
  | sed -e '$d' \
  | parallel psql -f sql/assessment_watersheds_lut.sql -v wsg={1}

psql -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_lut (assmnt_watershed_id)"