CREATE TABLE whse_basemapping.fwa_approx_borders AS
SELECT
  'USA_49' as border,
    ST_Transform(
      ST_MakeLine(
        ST_SetSRID(ST_MakePoint(x, y), 4326)
      ),
    3005)
   AS geom
FROM (SELECT
        generate_series(-123.3, -114.06, .01) AS x,
        49.0005 AS y) AS segments

UNION ALL

SELECT
  'YTNWT_60' as border,
    ST_Transform(
      ST_MakeLine(
        ST_SetSRID(ST_MakePoint(x, y), 4326)
      ),
    3005)
   AS geom
FROM (SELECT
        generate_series(-139.05, -120.00, .01) AS x,
        59.9995 AS y) AS segments

UNION ALL

SELECT
  'AB_120' as border,
    ST_Transform(
      ST_MakeLine(
        ST_SetSRID(ST_MakePoint(x, y), 4326)
      ),
    3005)
   AS geom
FROM (SELECT
        -120.0005 AS x,
        generate_series(60, 53.79914, -.01) AS y) AS segments;