-- create_fwa_assessment_watershds_streams_lut.sql

-- Create a lookup for joining streams to assessment watersheds
-- This is necessary because the edges of assessment watersheds can be
-- coincident with stream lines - especially along double line rivers.
-- For an example, see Kootenay River just upstream of Castlegar

DROP TABLE IF EXISTS whse_basemapping.fwa_assessment_watersheds_streams_lut;
CREATE TABLE whse_basemapping.fwa_assessment_watersheds_streams_lut
(linear_feature_id bigint primary key,
watershed_feature_id integer,
watershed_group_code text,
watershed_group_id integer);

-- Step 1, insert the simple cases
INSERT INTO whse_basemapping.fwa_assessment_watersheds_streams_lut
SELECT
 s.linear_feature_id,
 p.watershed_feature_id,
 s.watershed_group_code,
 s.watershed_group_id
FROM whse_basemapping.fwa_stream_networks_sp s
INNER JOIN whse_basemapping.fwa_assessment_watersheds_poly p
ON s.watershed_group_code = p.watershed_group_code
AND ST_Intersects(s.geom, p.geom)
AND NOT ST_Touches(s.geom, p.geom)
WHERE s.edge_type != 6010;

-- Step 2, insert features that only touch
-- Where one stream matches more than one watershed, just arbitrarily return
-- the watershed with the lowest id
-- Note that we do not try and re-insert records that have already been
-- matched in the first step.
-- For example, see linear_feature_id=2005121
-- This segment is assigned to the lower watershed in step 1, but because
-- it also touches the upper watershed it needs to be ignored in step 2
INSERT INTO whse_basemapping.fwa_assessment_watersheds_streams_lut
SELECT DISTINCT ON (linear_feature_id)
 s.linear_feature_id,
 p.watershed_feature_id,
 s.watershed_group_code,
 s.watershed_group_id
FROM whse_basemapping.fwa_stream_networks_sp s
INNER JOIN whse_basemapping.fwa_assessment_watersheds_poly p
ON s.watershed_group_code = p.watershed_group_code
AND ST_Intersects(s.geom, p.geom)
AND ST_Touches(s.geom, p.geom)
WHERE s.edge_type != 6010
ORDER BY linear_feature_id, watershed_feature_id
ON CONFLICT DO NOTHING;

CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_streams_lut (watershed_feature_id);




/*
This is a count check, evaluating if above is a valid way to build lookup -
The relationship is indeed 1:1 for records where NOT ST_Touches:

select count(*) from
(SELECT DISTINCT ON (linear_feature_id)
 s.linear_feature_id,
 p.watershed_feature_id
FROM whse_basemapping.fwa_stream_networks_sp s
INNER JOIN whse_basemapping.fwa_assessment_watersheds_poly p
ON s.watershed_group_code = p.watershed_group_code
AND s.wscode_ltree @> p.wscode_ltree
AND ST_Intersects(s.geom, p.geom)
AND NOT ST_Touches(s.geom, p.geom)
WHERE s.edge_type != 6010
ORDER BY linear_feature_id, watershed_feature_id) as f;

 count
--------
 964113
(1 row)

select count(*) from
(SELECT
 s.linear_feature_id,
 p.watershed_feature_id
FROM whse_basemapping.fwa_stream_networks_sp s
INNER JOIN whse_basemapping.fwa_assessment_watersheds_poly p
ON s.watershed_group_code = p.watershed_group_code
AND s.wscode_ltree @> p.wscode_ltree
AND ST_Intersects(s.geom, p.geom)
AND NOT ST_Touches(s.geom, p.geom)
WHERE s.edge_type != 6010) as f;

 count
--------
 964113
(1 row)

*/