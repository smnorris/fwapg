CREATE OR REPLACE FUNCTION FWA_hydroshed(id bigint)

RETURNS TABLE
    (
        geom geometry(Polygon, 3005)
    )

AS

$$

WITH RECURSIVE walkup (hybas_id, geom) AS
    (
        SELECT hybas_id, wsd.geom
        FROM hydrosheds.hybas_lev12_v1c wsd
        WHERE hybas_id = id

        UNION ALL

        SELECT b.hybas_id, b.geom
        FROM hydrosheds.hybas_lev12_v1c b,
        walkup w
        WHERE b.next_down = w.hybas_id
    )
SELECT
  ST_Union(w.geom, .5) as geom
FROM walkup w;

$$
language 'sql' immutable strict parallel safe;

COMMENT ON FUNCTION FWA_hydroshed IS 'Return geometry of aggregated watershed boundary for watershed upstream of provided hydroshed id';