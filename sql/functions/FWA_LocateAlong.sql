-- Return a point on the stream network based on the location provided by input blue_line_key and downstream_route_measure

DROP FUNCTION postgisftw.FWA_LocateAlong;
CREATE OR REPLACE FUNCTION postgisftw.FWA_LocateAlong(blue_line_key integer, downstream_route_measure float)

RETURNS TABLE (
    geom                     geometry(Point, 3005)
)

AS

$$

DECLARE
   v_blkey    integer := blue_line_key;
   v_measure  float   := downstream_route_measure;
   v_geom     geometry;

BEGIN

RETURN QUERY
SELECT
  (ST_Dump(ST_LocateAlong(s.geom, v_measure))).geom as geom
FROM whse_basemapping.fwa_stream_networks_sp AS s
WHERE s.blue_line_key = v_blkey
AND s.downstream_route_measure <= v_measure
AND s.upstream_route_measure > v_measure;

END

$$
LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION postgisftw.fwa_IndexPoint IS 'Return a point on the stream network based on the location provided by blue_line_key and downstream_route_measure'