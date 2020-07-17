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

-- Cluster the stream and watersheds data on disk on the watershed code GIST
-- index - this may slightly speed up upstream/downstream queries by making
-- nearby features also nearby on disk
-- https://postgis.net/docs/performance_tips.html
CLUSTER whse_basemapping.fwa_stream_networks_sp USING fwa_stream_networks_sp_wscode_ltree_gist_idx;