CREATE OR REPLACE FUNCTION whse_basemapping.fwa_streamsasmvt(
            z integer, x integer, y integer)
RETURNS bytea
AS $$
DECLARE
    result bytea;
BEGIN
    WITH
    
    bounds AS (
      SELECT ST_TileEnvelope(z, x, y) AS geom
    ), 

    mvtgeom AS (
      SELECT
        blue_line_key,
        gnis_name,
        stream_order_max,
        ST_AsMVTGeom(ST_Transform(ST_Force2D(s.geom), 3857), bounds.geom)
      FROM whse_basemapping.fwa_stream_networks_sp s, bounds 
      WHERE ST_Intersects(s.geom, ST_Transform((select geom from bounds), 3005))
      AND s.edge_type != 6010 
      AND wscode_ltree is not null
      AND stream_order_max >= (-z + 13)
     )

    SELECT ST_AsMVT(mvtgeom, 'default')
    INTO result
    FROM mvtgeom;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

COMMENT ON FUNCTION whse_basemapping.fwa_streamsasmvt IS 'Zoom-level dependent FWA streams';