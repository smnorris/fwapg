ALTER TABLE whse_basemapping.fwa_assessment_watersheds_poly ADD COLUMN wscode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
ALTER TABLE whse_basemapping.fwa_assessment_watersheds_poly ADD COLUMN localcode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly (gnis_name_1);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly (waterbody_id);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly (waterbody_key);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly (watershed_key);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly USING BTREE (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly USING GIST(geom);

CREATE INDEX ON whse_basemapping.fwa_bays_and_channels_poly (gnis_name);
CREATE INDEX ON whse_basemapping.fwa_bays_and_channels_poly USING GIST(geom);

ALTER TABLE whse_basemapping.fwa_coastlines_sp ADD COLUMN wscode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
ALTER TABLE whse_basemapping.fwa_coastlines_sp ADD COLUMN localcode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
CREATE INDEX ON whse_basemapping.fwa_coastlines_sp (edge_type);
CREATE INDEX ON whse_basemapping.fwa_coastlines_sp (blue_line_key);
CREATE INDEX ON whse_basemapping.fwa_coastlines_sp (watershed_key);
CREATE INDEX ON whse_basemapping.fwa_coastlines_sp (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_coastlines_sp USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_coastlines_sp USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_coastlines_sp USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_coastlines_sp USING BTREE (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_coastlines_sp USING GIST (geom);

ALTER TABLE whse_basemapping.fwa_glaciers_poly ADD COLUMN wscode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
ALTER TABLE whse_basemapping.fwa_glaciers_poly ADD COLUMN localcode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
CREATE INDEX ON whse_basemapping.fwa_glaciers_poly (blue_line_key);
CREATE INDEX ON whse_basemapping.fwa_glaciers_poly (watershed_key);
CREATE INDEX ON whse_basemapping.fwa_glaciers_poly (waterbody_key);
CREATE INDEX ON whse_basemapping.fwa_glaciers_poly (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_glaciers_poly (gnis_name_1);
CREATE INDEX ON whse_basemapping.fwa_glaciers_poly USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_glaciers_poly USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_glaciers_poly USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_glaciers_poly USING BTREE (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_glaciers_poly USING GIST (geom);

ALTER TABLE whse_basemapping.fwa_islands_poly ADD COLUMN wscode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
ALTER TABLE whse_basemapping.fwa_islands_poly ADD COLUMN localcode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
CREATE INDEX ON whse_basemapping.fwa_islands_poly (gnis_name_1);
CREATE INDEX ON whse_basemapping.fwa_islands_poly (gnis_name_2);
CREATE INDEX ON whse_basemapping.fwa_islands_poly USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_islands_poly USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_islands_poly USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_islands_poly USING BTREE (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_islands_poly USING GIST (geom);

ALTER TABLE whse_basemapping.fwa_lakes_poly ADD COLUMN wscode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
ALTER TABLE whse_basemapping.fwa_lakes_poly ADD COLUMN localcode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
CREATE INDEX ON whse_basemapping.fwa_lakes_poly (blue_line_key);
CREATE INDEX ON whse_basemapping.fwa_lakes_poly (watershed_key);
CREATE INDEX ON whse_basemapping.fwa_lakes_poly (waterbody_key);
CREATE INDEX ON whse_basemapping.fwa_lakes_poly (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_lakes_poly (gnis_name_1);
CREATE INDEX ON whse_basemapping.fwa_lakes_poly USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_lakes_poly USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_lakes_poly USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_lakes_poly USING BTREE (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_lakes_poly USING GIST (geom);

ALTER TABLE whse_basemapping.fwa_manmade_waterbodies_poly ADD COLUMN wscode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
ALTER TABLE whse_basemapping.fwa_manmade_waterbodies_poly ADD COLUMN localcode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly (blue_line_key);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly (watershed_key);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly (waterbody_key);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly (gnis_name_1);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly USING BTREE (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly USING GIST (geom);

ALTER TABLE whse_basemapping.fwa_wetlands_poly ADD COLUMN wscode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
ALTER TABLE whse_basemapping.fwa_wetlands_poly ADD COLUMN localcode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
CREATE INDEX ON whse_basemapping.fwa_wetlands_poly (blue_line_key);
CREATE INDEX ON whse_basemapping.fwa_wetlands_poly (watershed_key);
CREATE INDEX ON whse_basemapping.fwa_wetlands_poly (waterbody_key);
CREATE INDEX ON whse_basemapping.fwa_wetlands_poly (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_wetlands_poly (gnis_name_1);
CREATE INDEX ON whse_basemapping.fwa_wetlands_poly USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_wetlands_poly USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_wetlands_poly USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_wetlands_poly USING BTREE (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_wetlands_poly USING GIST (geom);

ALTER TABLE whse_basemapping.fwa_rivers_poly ADD COLUMN wscode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
ALTER TABLE whse_basemapping.fwa_rivers_poly ADD COLUMN localcode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
CREATE INDEX ON whse_basemapping.fwa_rivers_poly (blue_line_key);
CREATE INDEX ON whse_basemapping.fwa_rivers_poly (watershed_key);
CREATE INDEX ON whse_basemapping.fwa_rivers_poly (waterbody_key);
CREATE INDEX ON whse_basemapping.fwa_rivers_poly (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_rivers_poly (gnis_name_1);
CREATE INDEX ON whse_basemapping.fwa_rivers_poly USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_rivers_poly USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_rivers_poly USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_rivers_poly USING BTREE (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_rivers_poly USING GIST (geom);

ALTER TABLE whse_basemapping.fwa_obstructions_sp ADD COLUMN wscode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
ALTER TABLE whse_basemapping.fwa_obstructions_sp ADD COLUMN localcode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp (linear_feature_id);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp (blue_line_key);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp (watershed_key);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp (obstruction_type);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp (gnis_name);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp USING BTREE (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp USING GIST (geom);

CREATE INDEX ON whse_basemapping.fwa_watershed_groups_poly (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_watershed_groups_poly USING GIST (geom);

ALTER TABLE whse_basemapping.fwa_linear_boundaries_sp ADD COLUMN wscode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
ALTER TABLE whse_basemapping.fwa_linear_boundaries_sp ADD COLUMN localcode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
CREATE INDEX ON whse_basemapping.fwa_linear_boundaries_sp (edge_type);
CREATE INDEX ON whse_basemapping.fwa_linear_boundaries_sp (blue_line_key);
CREATE INDEX ON whse_basemapping.fwa_linear_boundaries_sp (watershed_key);
CREATE INDEX ON whse_basemapping.fwa_linear_boundaries_sp (waterbody_key);
CREATE INDEX ON whse_basemapping.fwa_linear_boundaries_sp (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_linear_boundaries_sp USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_linear_boundaries_sp USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_linear_boundaries_sp USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_linear_boundaries_sp USING BTREE (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_linear_boundaries_sp USING GIST (geom);

CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp (edge_type);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp (blue_line_key);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp (watershed_key);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp (waterbody_key);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp (gnis_name);
CREATE INDEX fwa_stream_networks_sp_wscode_ltree_gist_idx ON whse_basemapping.fwa_stream_networks_sp USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp USING BTREE (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp USING GIST (geom);

ALTER TABLE whse_basemapping.fwa_watersheds_poly ADD COLUMN wscode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
ALTER TABLE whse_basemapping.fwa_watersheds_poly ADD COLUMN localcode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
CREATE INDEX ON whse_basemapping.fwa_watersheds_poly (gnis_name_1);
CREATE INDEX ON whse_basemapping.fwa_watersheds_poly (waterbody_id);
CREATE INDEX ON whse_basemapping.fwa_watersheds_poly (waterbody_key);
CREATE INDEX ON whse_basemapping.fwa_watersheds_poly (watershed_key);
CREATE INDEX ON whse_basemapping.fwa_watersheds_poly (watershed_group_code);
CREATE INDEX fwa_watersheds_poly_wscode_ltree_gist_idx ON whse_basemapping.fwa_watersheds_poly USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_watersheds_poly USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_watersheds_poly USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_watersheds_poly USING BTREE (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_watersheds_poly USING GIST (geom);

ALTER TABLE whse_basemapping.fwa_named_watersheds_poly ADD COLUMN wscode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
CREATE INDEX ON whse_basemapping.fwa_named_watersheds_poly (gnis_name);
CREATE INDEX ON whse_basemapping.fwa_named_watersheds_poly (blue_line_key);
CREATE INDEX ON whse_basemapping.fwa_named_watersheds_poly (fwa_watershed_code);
CREATE INDEX ON whse_basemapping.fwa_named_watersheds_poly USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_named_watersheds_poly USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_named_watersheds_poly USING GIST (geom);

CREATE INDEX ON whse_basemapping.fwa_streams_20k_50k (watershed_group_id_20k);
CREATE INDEX ON whse_basemapping.fwa_streams_20k_50k (linear_feature_id_20k);
CREATE INDEX ON whse_basemapping.fwa_streams_20k_50k (watershed_code_50k);

CREATE INDEX ON whse_basemapping.fwa_waterbodies_20k_50k (waterbody_type_20k);
CREATE INDEX ON whse_basemapping.fwa_waterbodies_20k_50k (watershed_group_id_20k);
CREATE INDEX ON whse_basemapping.fwa_waterbodies_20k_50k (waterbody_poly_id_20k);
CREATE INDEX ON whse_basemapping.fwa_waterbodies_20k_50k (fwa_watershed_code_20k);
CREATE INDEX ON whse_basemapping.fwa_waterbodies_20k_50k (watershed_code_50k);

CREATE INDEX ON whse_basemapping.fwa_basins_poly USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_basins_poly USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_basins_poly USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_basins_poly USING BTREE (localcode_ltree);

-- Cluster the stream and watersheds data on disk on the watershed code GIST
-- index - this may slightly speed up upstream/downstream queries by making
-- nearby features also nearby on disk
-- https://postgis.net/docs/performance_tips.html
CLUSTER whse_basemapping.fwa_stream_networks_sp USING fwa_stream_networks_sp_wscode_ltree_gist_idx;
CLUSTER whse_basemapping.fwa_watersheds_poly USING fwa_watersheds_poly_wscode_ltree_gist_idx;
