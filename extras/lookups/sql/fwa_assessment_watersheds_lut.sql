DROP TABLE IF EXISTS fwapg.fwa_assessment_watersheds_lut_:wsg;

CREATE table fwapg.fwa_assessment_watersheds_lut_:wsg (
  watershed_feature_id integer PRIMARY KEY,
  assmnt_watershed_id integer,
  watershed_group_code text,
  watershed_group_id integer
);

INSERT INTO fwapg.fwa_assessment_watersheds_lut_:wsg
(watershed_feature_id, assmnt_watershed_id, watershed_group_code, watershed_group_id)
with overlay as (
  SELECT
    a.watershed_feature_id,
    b.watershed_feature_id as assmnt_watershed_id,
    a.watershed_group_code,
    a.watershed_group_id,
    CASE
     WHEN ST_Coveredby(a.geom, b.geom) THEN ST_Area(a.geom)
     ELSE ST_area(ST_Intersection(a.geom, b.geom))
   END AS area
  FROM whse_basemapping.fwa_watersheds_poly a
  INNER JOIN whse_basemapping.fwa_assessment_watersheds_poly b
  ON a.watershed_group_code = b.watershed_group_code
  AND st_intersects(a.geom, b.geom)
  WHERE a.watershed_group_code = :'wsg'
)

select distinct on (watershed_feature_id)
  watershed_feature_id,
  assmnt_watershed_id,
  watershed_group_code,
  watershed_group_id
from overlay
order by watershed_feature_id, area desc
