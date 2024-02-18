-- The source FWA database holds waterbodies in four different tables.
-- We could combine them on demand, but for faster queries a single
-- waterbody table is useful - simpler code when relating to all
-- waterbodies and the table also holds the  wscodes / blue_line key
-- / downstream_route_measure at the outlet of the wb for
-- easier queries of 'how much lake is upstream of this point?'

-- LAKES

INSERT INTO whse_basemapping.fwa_waterbodies
(
  waterbody_key,
  waterbody_type,
  blue_line_key,
  downstream_route_measure,
  wscode_ltree,
  localcode_ltree
)

SELECT DISTINCT ON (waterbody_key)
  s.waterbody_key,
  wb.waterbody_type,
  s.blue_line_key,
  s.downstream_route_measure,
  s.wscode_ltree,
  s.localcode_ltree
FROM whse_basemapping.fwa_stream_networks_sp s
INNER JOIN whse_basemapping.fwa_lakes_poly wb
ON s.waterbody_key = wb.waterbody_key
WHERE s.wscode_ltree <@ '999.999999'::ltree is false
AND s.localcode_ltree IS NOT NULL
AND s.waterbody_key IS NOT NULL
ORDER BY s.waterbody_key, s.wscode_ltree, s.localcode_ltree, s.downstream_route_measure;


-- RIVERS

INSERT INTO whse_basemapping.fwa_waterbodies
(
  waterbody_key,
  waterbody_type,
  blue_line_key,
  downstream_route_measure,
  wscode_ltree,
  localcode_ltree
)

SELECT DISTINCT ON (waterbody_key)
  s.waterbody_key,
  wb.waterbody_type,
  s.blue_line_key,
  s.downstream_route_measure,
  s.wscode_ltree,
  s.localcode_ltree
FROM whse_basemapping.fwa_stream_networks_sp s
INNER JOIN whse_basemapping.fwa_rivers_poly wb
ON s.waterbody_key = wb.waterbody_key
WHERE s.wscode_ltree <@ '999.999999'::ltree is false
AND s.localcode_ltree IS NOT NULL
AND s.waterbody_key IS NOT NULL
ORDER BY s.waterbody_key, s.wscode_ltree, s.localcode_ltree, s.downstream_route_measure;


-- WETLANDS

INSERT INTO whse_basemapping.fwa_waterbodies
(
  waterbody_key,
  waterbody_type,
  blue_line_key,
  downstream_route_measure,
  wscode_ltree,
  localcode_ltree
)

SELECT DISTINCT ON (waterbody_key)
  s.waterbody_key,
  wb.waterbody_type,
  s.blue_line_key,
  s.downstream_route_measure,
  s.wscode_ltree,
  s.localcode_ltree
FROM whse_basemapping.fwa_stream_networks_sp s
INNER JOIN whse_basemapping.fwa_wetlands_poly wb
ON s.waterbody_key = wb.waterbody_key
WHERE s.wscode_ltree <@ '999.999999'::ltree is false
AND s.localcode_ltree IS NOT NULL
AND s.waterbody_key IS NOT NULL
ORDER BY s.waterbody_key, s.wscode_ltree, s.localcode_ltree, s.downstream_route_measure;


-- MANMADE WATERBODIES

INSERT INTO whse_basemapping.fwa_waterbodies
(
  waterbody_key,
  waterbody_type,
  blue_line_key,
  downstream_route_measure,
  wscode_ltree,
  localcode_ltree
)

SELECT DISTINCT ON (waterbody_key)
  s.waterbody_key,
  wb.waterbody_type,
  s.blue_line_key,
  s.downstream_route_measure,
  s.wscode_ltree,
  s.localcode_ltree
FROM whse_basemapping.fwa_stream_networks_sp s
INNER JOIN whse_basemapping.fwa_manmade_waterbodies_poly wb
ON s.waterbody_key = wb.waterbody_key
WHERE s.wscode_ltree <@ '999.999999'::ltree is false
AND s.localcode_ltree IS NOT NULL
AND s.waterbody_key IS NOT NULL
ORDER BY s.waterbody_key, s.wscode_ltree, s.localcode_ltree, s.downstream_route_measure;


-- GLACIERS
-- *these do not have a wb key so they do not get inserted*

INSERT INTO whse_basemapping.fwa_waterbodies
(
  waterbody_key,
  waterbody_type,
  blue_line_key,
  downstream_route_measure,
  wscode_ltree,
  localcode_ltree
)

SELECT DISTINCT ON (waterbody_key)
  s.waterbody_key,
  wb.waterbody_type,
  s.blue_line_key,
  s.downstream_route_measure,
  s.wscode_ltree,
  s.localcode_ltree
FROM whse_basemapping.fwa_stream_networks_sp s
INNER JOIN whse_basemapping.fwa_glaciers_poly wb
ON s.waterbody_key = wb.waterbody_key
WHERE s.wscode_ltree <@ '999.999999'::ltree is false
AND s.localcode_ltree IS NOT NULL
AND s.waterbody_key IS NOT NULL
ORDER BY s.waterbody_key, s.wscode_ltree, s.localcode_ltree, s.downstream_route_measure;
