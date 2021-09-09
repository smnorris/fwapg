# add the ltree types
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