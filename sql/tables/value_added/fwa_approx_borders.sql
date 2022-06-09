-- fwa_approx_borders.sql

-- For watersheds queries, we want to know if a given location is
-- on a stream that is about to leave BC. Find these streams by intersecting
-- with these lines along the border.
-- Borders should match the FWA boundaries (using the surveyed BC boundary
-- does not work for this application because it does not follow the
-- lat 49/6 lon 120 that the FWA generally follows)

-- NOTES
-- - this does not include Alaska
-- - does not attempt to define continental divide
-- - it could be valuable to manually QA results of intersection of these
--   lines and streams and generate a lookup of all BC streams that exit the
--   province rather than approximating in this way. We could also presumably
--   query to find streams that end where measure != 0
DROP TABLE IF EXISTS fwapg.fwa_approx_borders;

CREATE TABLE fwapg.fwa_approx_borders
(approx_border_id SERIAL PRIMARY KEY,
border text,
geom geometry(LINESTRING, 3005));

INSERT INTO fwapg.fwa_approx_borders
(border, geom)
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
        49.00025 AS y) AS segments

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

COMMENT ON TABLE fwapg.fwa_approx_borders IS 'Lines of latitude / longitude for 49N, 60N, -120W. These are used by fwapg for finding cross-border streams';
COMMENT ON COLUMN fwapg.fwa_approx_borders.approx_border_id IS 'Unique identifer';
COMMENT ON COLUMN fwapg.fwa_approx_borders.border IS 'A code identifying the border (USA49, YTNWT_60, AB_120)';
COMMENT ON COLUMN fwapg.fwa_approx_borders.geom IS 'Geometry of the border line';