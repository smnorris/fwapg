-- Source data mixes multipart/singlepart types in these tables, so they are loaded to column of generic geometry type.
-- To avoid QGIS having to scan entire tables to determine geometry types, we prefer to have geometry types
-- set explicitly.
-- To fix, set all these tables to Multipart

UPDATE whse_basemapping.fwa_assessment_watersheds_poly SET geom = ST_Multi(geom);
ALTER TABLE whse_basemapping.fwa_assessment_watersheds_poly ALTER COLUMN geom SET DATA TYPE geometry(MULTIPOLYGON, 3005);

UPDATE whse_basemapping.fwa_bays_and_channels_poly SET geom = ST_Multi(geom);
ALTER TABLE whse_basemapping.fwa_bays_and_channels_poly ALTER COLUMN geom SET DATA TYPE geometry(MULTIPOLYGON, 3005);

UPDATE whse_basemapping.fwa_glaciers_poly SET geom = ST_Multi(geom);
ALTER TABLE whse_basemapping.fwa_glaciers_poly ALTER COLUMN geom SET DATA TYPE geometry(MULTIPOLYGON, 3005);

UPDATE whse_basemapping.fwa_lakes_poly SET geom = ST_Multi(geom);
ALTER TABLE whse_basemapping.fwa_lakes_poly ALTER COLUMN geom SET DATA TYPE geometry(MULTIPOLYGON, 3005);

UPDATE whse_basemapping.fwa_manmade_waterbodies_poly SET geom = ST_Multi(geom);
ALTER TABLE whse_basemapping.fwa_manmade_waterbodies_poly ALTER COLUMN geom SET DATA TYPE geometry(MULTILINESTRING, 3005);

UPDATE whse_basemapping.fwa_named_watersheds_poly SET geom = ST_Multi(geom);
ALTER TABLE whse_basemapping.fwa_named_watersheds_poly ALTER COLUMN geom SET DATA TYPE geometry(MULTILINESTRING, 3005);

UPDATE whse_basemapping.fwa_watershed_groups_poly SET geom = ST_Multi(geom);
ALTER TABLE whse_basemapping.fwa_watershed_groups_poly ALTER COLUMN geom SET DATA TYPE geometry(MULTILINESTRING, 3005);

UPDATE whse_basemapping.fwa_wetlands_poly SET geom = ST_Multi(geom);
ALTER TABLE whse_basemapping.fwa_wetlands_poly ALTER COLUMN geom SET DATA TYPE geometry(MULTILINESTRING, 3005);

UPDATE whse_basemapping.fwa_rivers_poly SET geom = ST_Multi(geom);
ALTER TABLE whse_basemapping.fwa_rivers_poly ALTER COLUMN geom SET DATA TYPE geometry(MULTIPOLYGON, 3005);
