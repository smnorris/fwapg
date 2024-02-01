-- create_fwa_assessment_watershds_streams_lut.sql

-- Create a lookup for joining streams to assessment watersheds
-- This is not just for speed - it is necessary because the edges of assessment
-- watersheds can be coincident with stream lines - especially along double line rivers.
-- For an example, see Kootenay River just upstream of Castlegar

-- associate stream segments with assessment watersheds based on what watershed
-- contains the most length of each segment

DROP TABLE IF EXISTS fwapg.fwa_assessment_watersheds_streams_lut_:wsg;
CREATE table fwapg.fwa_assessment_watersheds_streams_lut_:wsg (
  watershed_feature_id integer PRIMARY KEY,
  assmnt_watershed_id integer,
  watershed_group_code text,
  watershed_group_id integer
);

INSERT INTO fwapg.fwa_assessment_watersheds_streams_lut_:wsg
WITH overlay AS
(SELECT DISTINCT ON (linear_feature_id)
 s.linear_feature_id,
 p.watershed_feature_id,
 s.watershed_group_code,
 s.watershed_group_id,
 CASE
   WHEN ST_Coveredby(s.geom, p.geom) THEN ST_Length(s.geom)
   ELSE ST_length(ST_Intersection(s.geom, p.geom))
 END AS length
FROM whse_basemapping.fwa_stream_networks_sp s
INNER JOIN whse_basemapping.fwa_assessment_watersheds_poly p
ON s.watershed_group_code = p.watershed_group_code
AND ST_Intersects(s.geom, p.geom)
WHERE s.edge_type != 6010
AND s.watershed_group_code = :'wsg'
-- try and remove coincident lines where possible
AND NOT ST_Touches(s.geom, p.geom)
ORDER BY linear_feature_id, length desc)

SELECT
  linear_feature_id,
  watershed_feature_id,
  watershed_group_code,
  watershed_group_id
FROM overlay;


-- Insert features that only touch
-- Where one stream matches more than one watershed, just arbitrarily return
-- the watershed with the lowest id
-- Note that we do not try and re-insert records that have already been
-- matched in the first step.
INSERT INTO fwapg.fwa_assessment_watersheds_streams_lut_:wsg
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
AND s.watershed_group_code = :'wsg'
ORDER BY linear_feature_id, watershed_feature_id
ON CONFLICT DO NOTHING;
