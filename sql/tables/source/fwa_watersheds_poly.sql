# add the ltree types
ALTER TABLE whse_basemapping.fwa_watersheds_poly ADD COLUMN wscode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
ALTER TABLE whse_basemapping.fwa_watersheds_poly ADD COLUMN localcode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;

# index
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

-- clustering on disk by wscode may speed us/ds queries slightly
CLUSTER whse_basemapping.fwa_watersheds_poly USING fwa_watersheds_poly_wscode_ltree_gist_idx;