-- Return a point on the stream network based on the location provided by input blue_line_key and downstream_route_measure

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
SELECT distinct on (s.blue_line_key)
  (ST_Dump(ST_LocateAlong(s.geom, v_measure))).geom as geom
FROM whse_basemapping.fwa_stream_networks_sp AS s
WHERE s.blue_line_key = v_blkey
AND round(s.downstream_route_measure::numeric, 4) <= round(v_measure::numeric, 4)
AND round(s.upstream_route_measure::numeric, 4) > round(v_measure::numeric, 4)
order by s.blue_line_key, s.downstream_route_measure desc;
END

$$
LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION postgisftw.FWA_LocateAlong IS 'Return a point on the stream network based on the location provided by blue_line_key and downstream_route_measure'