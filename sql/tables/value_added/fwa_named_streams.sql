-- create a table of named streams (for labelling purposes)
-- filter out lakes by joining to lakes/manmade wb tables
-- (edge type doesn't work because we want to retain rivers, wetlands)
DROP TABLE IF EXISTS whse_basemapping.fwa_named_streams;

CREATE TABLE whse_basemapping.fwa_named_streams
(named_streams_id SERIAL PRIMARY KEY,
 gnis_name TEXT,
 blue_line_key BIGINT,
 stream_order INTEGER,
 watershed_group_code TEXT,
 geom GEOMETRY(MULTILINESTRING, 3005));

INSERT INTO whse_basemapping.fwa_named_streams
  (gnis_name, blue_line_key, stream_order, watershed_group_code, geom)
SELECT
  str.gnis_name,
  str.blue_line_key,
  max(str.stream_order),
  str.watershed_group_code,
  ST_Multi(ST_Force2D(ST_Simplify(ST_Union(str.geom), 25))) AS geom
  FROM whse_basemapping.fwa_stream_networks_sp str
  LEFT OUTER JOIN whse_basemapping.fwa_lakes_poly lk
  ON str.waterbody_key = lk.waterbody_key
  LEFT OUTER JOIN whse_basemapping.fwa_manmade_waterbodies_poly mmwb
  ON str.waterbody_key = mmwb.waterbody_key
  WHERE gnis_name IS NOT NULL
  AND lk.waterbody_key IS NULL
  AND mmwb.waterbody_key IS NULL
  GROUP BY str.gnis_name, str.blue_line_key, str.watershed_group_code;

CREATE INDEX
ON whse_basemapping.fwa_named_streams
USING gist (geom);


COMMENT ON TABLE whse_basemapping.fwa_named_streams IS 'Named streams of BC, aggregated per watershed group and simplified using a 25m tolerance (primarily for mapping use)';
COMMENT ON COLUMN whse_basemapping.fwa_named_streams.named_streams_id IS 'Named stream unique identifier';
COMMENT ON COLUMN whse_basemapping.fwa_named_streams.gnis_name IS 'The BCGNIS (BC Geographical Names Information System) name associated with the stream';
COMMENT ON COLUMN whse_basemapping.fwa_named_streams.blue_line_key IS 'The blue line key of the named stream, see FWA documentation for blue_line_key description';
COMMENT ON COLUMN whse_basemapping.fwa_named_streams.stream_order IS 'The maximum stream order associated with the stream name';
COMMENT ON COLUMN whse_basemapping.fwa_named_streams.watershed_group_code IS 'The watershed group code associated with the named stream';
COMMENT ON COLUMN whse_basemapping.fwa_named_streams.geom IS 'The geometry of the named stream, an aggregation of the source features and simpified by 25m';
