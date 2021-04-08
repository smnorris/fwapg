-- Return aggregated boundary of all hydroshed polygons upstream of the provided location

CREATE OR REPLACE FUNCTION postgisftw.hydroshed(x float, y float, srid integer)

RETURNS geometry

AS

$$

WITH RECURSIVE walkup (hybas_id, geom) AS
        (
            SELECT hybas_id, wsd.geom
            FROM hydrosheds.hybas_lev12_v1c wsd
            INNER JOIN (SELECT ST_Transform(ST_SetSRID(ST_MakePoint(x, y), srid), 3005) as geom)  as pt
            ON ST_Intersects(wsd.geom, pt.geom)

            UNION ALL

            SELECT b.hybas_id, b.geom
            FROM hydrosheds.hybas_lev12_v1c b,
            walkup w
            WHERE b.next_down = w.hybas_id
        )
    SELECT
      ST_Union(w.geom) as geom
    FROM walkup w;

$$
language 'sql' immutable parallel safe;


COMMENT ON FUNCTION postgisftw.hydroshed IS 'Return aggregated boundary of all hydroshed polygons upstream of the provided location';