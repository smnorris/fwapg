-- load all the stream data, populating ltree codes etc
CREATE TABLE whse_basemapping.fwa_stream_networks_sp (
    linear_feature_id bigint PRIMARY KEY,
  watershed_group_id integer NOT NULL,
  edge_type integer NOT NULL,
  blue_line_key integer NOT NULL,
  watershed_key integer NOT NULL,
  fwa_watershed_code character varying(143) NOT NULL,
  local_watershed_code character varying(143),
  watershed_group_code character varying(4) NOT NULL,
  downstream_route_measure double precision NOT NULL,
  length_metre double precision NOT NULL,
  feature_source character varying(15),
  gnis_id integer,
  gnis_name character varying(80),
  left_right_tributary character varying(7),
  stream_order integer,
  stream_magnitude integer,
  waterbody_key integer,
  blue_line_key_50k integer,
  watershed_code_50k character varying(45),
  watershed_key_50k integer,
  watershed_group_code_50k character varying(4),
  gradient double precision GENERATED ALWAYS AS (round((((ST_Z (ST_PointN (geom, - 1)) - ST_Z
    (ST_PointN (geom, 1))) / ST_Length (geom))::numeric), 4)) STORED,
  feature_code character varying(10),
  wscode_ltree ltree GENERATED ALWAYS AS (REPLACE(REPLACE(fwa_watershed_code,
    '-000000', ''), '-', '.')::ltree) STORED,
  localcode_ltree ltree GENERATED ALWAYS AS
    (REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.')::ltree) STORED,
  upstream_route_measure double precision GENERATED ALWAYS AS (downstream_route_measure +
    ST_Length (geom)) STORED,
  upstream_area_ha double precision,
  geom geometry(LineStringZM, 3005)
);

INSERT INTO whse_basemapping.fwa_stream_networks_sp (linear_feature_id, watershed_group_id,
  edge_type, blue_line_key, watershed_key, fwa_watershed_code, local_watershed_code,
  watershed_group_code, downstream_route_measure, length_metre, feature_source, gnis_id, gnis_name,
  left_right_tributary, stream_order, stream_magnitude, waterbody_key, blue_line_key_50k,
  watershed_code_50k, watershed_key_50k, watershed_group_code_50k, feature_code, geom)
SELECT
  linear_feature_id,
  watershed_group_id,
  edge_type,
  blue_line_key,
  watershed_key,
  fwa_watershed_code,
  local_watershed_code,
  watershed_group_code,
  downstream_route_measure,
  length_metre,
  feature_source,
  gnis_id,
  gnis_name,
  left_right_tributary,
  stream_order,
  stream_magnitude,
  waterbody_key,
  blue_line_key_50k,
  watershed_code_50k,
  watershed_key_50k,
  watershed_group_code_50k,
  feature_code,
  ST_AddMeasure (geom, downstream_route_measure, downstream_route_measure + ST_Length (geom)) AS geom
FROM
  whse_basemapping.fwa_stream_networks_sp_load;

-- create the necessary indices
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp (edge_type);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp (blue_line_key);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp (blue_line_key, downstream_route_measure);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp (watershed_key);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp (waterbody_key);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp (gnis_name);
CREATE INDEX fwa_stream_networks_sp_wscode_ltree_gist_idx ON whse_basemapping.fwa_stream_networks_sp USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp USING BTREE (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_stream_networks_sp USING GIST (geom);

-- clustering on disk by wscode may speed us/ds queries slightly
CLUSTER whse_basemapping.fwa_stream_networks_sp USING fwa_stream_networks_sp_wscode_ltree_gist_idx