-- create temp table and inserting is faster than running an UPDATE
DROP TABLE IF EXISTS whse_basemapping.streams_temp;

-- start with stream network table so we don't have to recreate constraints/indexes
CREATE TABLE whse_basemapping.streams_temp (LIKE whse_basemapping.fwa_stream_networks_sp);

-- include m in geom
ALTER TABLE whse_basemapping.streams_temp ALTER COLUMN geom SET DATA TYPE geometry(MultiLineStringZM, 3005);

-- insert the data, adding m values
INSERT INTO whse_basemapping.streams_temp
SELECT
 linear_feature_id        ,
 watershed_group_id       ,
 edge_type                ,
 blue_line_key            ,
 watershed_key            ,
 fwa_watershed_code       ,
 local_watershed_code     ,
 watershed_group_code     ,
 downstream_route_measure ,
 length_metre             ,
 feature_source           ,
 gnis_id                  ,
 gnis_name                ,
 left_right_tributary     ,
 stream_order             ,
 stream_magnitude         ,
 waterbody_key            ,
 blue_line_key_50k        ,
 watershed_code_50k       ,
 watershed_key_50k        ,
 watershed_group_code_50k ,
 gradient                 ,
 feature_code             ,
 wscode_ltree             ,
 localcode_ltree          ,
 upstream_route_measure   ,
 ST_AddMeasure(geom, downstream_route_measure, upstream_route_measure) as geom
FROM whse_basemapping.fwa_stream_networks_sp;

DROP TABLE whse_basemapping.fwa_stream_networks_sp;
ALTER TABLE whse_basemapping.streams_temp RENAME TO fwa_stream_networks_sp;
ALTER TABLE whse_basemapping.fwa_stream_networks_sp ADD PRIMARY KEY (linear_feature_id);