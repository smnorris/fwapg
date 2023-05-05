-- clip geom of provided table by specified watershed group, also overlaying with assesment watersheds

drop function whse_basemapping.FWA_ClipByWatershed;

CREATE OR REPLACE FUNCTION whse_basemapping.FWA_ClipByWatershed(
  _tbl regclass, 
  _id text, 
  _wsg text, 
  OUT id text, 
  OUT assessment_watershed_id integer,
  OUT watershed_group_id integer, 
  OUT watershed_group_code character varying (4),
  OUT geom geometry
)
RETURNS SETOF record
LANGUAGE plpgsql AS

$func$

BEGIN
  RETURN QUERY
  EXECUTE format('
  SELECT 
   a.%I::text as id,
   w.watershed_feature_id as assessment_watershed_id,
   w.watershed_group_id,
   w.watershed_group_code,
   CASE
     WHEN ST_Coveredby(a.geom, w.geom) THEN a.geom
     ELSE ST_Intersection(a.geom, w.geom)
   END AS geom
  FROM %I a
  INNER JOIN whse_basemapping.fwa_assessment_watersheds_poly w
  ON ST_Intersects(a.geom, w.geom)
  WHERE w.watershed_group_code = $1;', _id, _tbl)
  USING _wsg;
END

$func$;