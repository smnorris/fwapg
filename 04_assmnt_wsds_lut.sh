# create a lookup relating fundamental watersheds to assessment watersheds,
# (for quickly relating the two tables without needing an overlay)

psql -c "DROP TABLE IF EXISTS whse_basemapping.fwa_assessment_watersheds_lut;"
psql -c "CREATE TABLE whse_basemapping.fwa_assessment_watersheds_lut
(watershed_feature_id integer PRIMARY KEY,
assmnt_watershed_feature_id integer,
watershed_group_code text,
watershed_group_id integer)"

# load the data (this took 9hrs - there may be some speedups possible!)
time psql -t -P border=0,footer=no \
-c "SELECT ''''||watershed_group_code||''''
    FROM whse_basemapping.fwa_watershed_groups_poly
    ORDER BY watershed_group_code" \
  | sed -e '$d' \
  | parallel psql -f sql/assessment_watersheds_lut.sql -v wsg={1}


# Note that there are currently 11 fundamental watersheds that are missed with above query.
# This is due to edits of the watersheds, I have noted this with GeoBC - George will fix them.

# SELECT
#   w.watershed_feature_id,
#   l.assmnt_watershed_feature_id,
#   w.watershed_group_code
# FROM whse_basemapping.fwa_watersheds_poly w
# LEFT OUTER JOIN whse_basemapping.fwa_assessment_watersheds_lut l
# ON w.watershed_feature_id = l.watershed_feature_id
# WHERE l.assmnt_watershed_feature_id IS NULL;

# result: (10757763,8442818,9505820,7871010,10757737,7776650,8332110,7748584,10638500,10052632,9996583)

# insert them into the lookup
psql -c "INSERT INTO whse_basemapping.fwa_assessment_watersheds_lut
SELECT distinct on (a.watershed_feature_id)
  a.watershed_feature_id as watershed_feature_id,
  b.watershed_feature_id as assmnt_watershed_feature_id,
  a.watershed_group_code,
  a.watershed_group_id
FROM whse_basemapping.fwa_watersheds_poly a
INNER JOIN whse_basemapping.fwa_assessment_watersheds_poly b
ON st_intersects(a.geom, b.geom)
WHERE a.watershed_feature_id IN
(10757763,8442818,9505820,7871010,10757737,7776650,8332110,7748584,10638500,10052632,9996583)
AND st_area(st_intersection(a.geom, b.geom)) > 100
ORDER BY a.watershed_feature_id, st_area(st_intersection(a.geom, b.geom)) desc"

psql -c "CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_lut (assmnt_watershed_feature_id)"