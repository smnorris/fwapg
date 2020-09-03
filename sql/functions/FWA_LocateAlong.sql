-- Return a point on the stream network based on the location provided by input blue_line_key and downstream_route_measure

DROP FUNCTION postgisftw.FWA_LocateAlong;
CREATE OR REPLACE FUNCTION postgisftw.FWA_LocateAlong(blue_line_key integer, downstream_route_measure float)

RETURNS geometry


AS

$$

declare
   v_blkey    integer := blue_line_key;
   v_measure  float   := downstream_route_measure;
   v_geom     geometry;
begin

SELECT
  (ST_Dump(ST_LocateAlong(s.geom, v_measure))).geom as geom
FROM whse_basemapping.fwa_stream_networks_sp AS s
WHERE s.blue_line_key = v_blkey
AND s.downstream_route_measure <= v_measure
AND s.upstream_route_measure > v_measure
INTO v_geom;

RETURN v_geom;

end

$$
language 'plpgsql' immutable strict parallel safe;

COMMENT ON FUNCTION postgisftw.fwa_IndexPoint IS 'Return a point on the stream network based on the location provided by blue_line_key and downstream_route_measure'