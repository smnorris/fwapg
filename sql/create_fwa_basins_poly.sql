-- Watersheds for larger basins in BC
-- Similar to https://catalogue.data.gov.bc.ca/dataset/bc-major-basins-river-forecast-centre
-- but - Based on FWA linework and includes additional smaller units.
-- Currently only used to speed generation of watershed polygons
-- todo: add more basins for greater utility
-- Fraser, Columbia, Peace, Liard, Fraser, Nass, Skeena, Stikine,
-- plus any other grouping of >2-3 watershed groups that is a complete (within BC) watershed

DROP TABLE IF EXISTS whse_basemapping.fwa_basins_poly;

CREATE TABLE whse_basemapping.fwa_basins_poly
(watershed_cache_id serial primary key,
 name text,
 wscode_ltree ltree,
 localcode_ltree ltree,
 geom Geometry);

INSERT INTO whse_basemapping.fwa_basins_poly
(name, wscode_ltree, localcode_ltree, geom)
SELECT
 'Thompson River' as name,
'100.190442'::ltree as wscode_ltree,
'100.190442'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.190442'::ltree AND
 localcode_ltree <@ '100.190442'::ltree
GROUP BY name, '100.190442'::ltree, '100.190442'::ltree;

INSERT INTO whse_basemapping.fwa_basins_poly
(name, wscode_ltree, localcode_ltree, geom)
SELECT
 'Chilcotin River' as name,
'100.342455'::ltree as wscode_ltree,
'100.342455'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.342455'::ltree AND
 localcode_ltree <@ '100.342455'::ltree
 GROUP BY name, '100.342455'::ltree, '100.342455'::ltree;
INSERT INTO whse_basemapping.fwa_basins_poly
(name, wscode_ltree, localcode_ltree, geom)
SELECT
 'Quesnel River' as name,
'100.458399'::ltree as wscode_ltree,
'100.458399'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.458399'::ltree AND
 localcode_ltree <@ '100.458399'::ltree
 GROUP BY name, '100.458399'::ltree, '100.458399'::ltree;

INSERT INTO whse_basemapping.fwa_basins_poly
(name, wscode_ltree, localcode_ltree, geom)
SELECT
 'Blackwater River' as name,
'100.500560'::ltree as wscode_ltree,
'100.500560'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.500560'::ltree AND
 localcode_ltree <@ '100.500560'::ltree
 GROUP BY name, '100.500560'::ltree, '100.500560'::ltree;

INSERT INTO whse_basemapping.fwa_basins_poly
(name, wscode_ltree, localcode_ltree, geom)
SELECT
 'Chilako River' as name,
'100.567134'::ltree as wscode_ltree,
'100.567134'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.567134'::ltree AND
 localcode_ltree <@ '100.567134'::ltree
 GROUP BY name, '100.567134'::ltree, '100.567134'::ltree;

INSERT INTO whse_basemapping.fwa_basins_poly
(name, wscode_ltree, localcode_ltree, geom)
SELECT
 'Salmon River' as name,
'100.591289'::ltree as wscode_ltree,
'100.591289'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.591289'::ltree AND
 localcode_ltree <@ '100.591289'::ltree
 GROUP BY name, '100.591289'::ltree, '100.591289'::ltree;

INSERT INTO whse_basemapping.fwa_basins_poly
(name, wscode_ltree, localcode_ltree, geom)
SELECT
 'McGregor River' as name,
'100.639480'::ltree as wscode_ltree,
'100.639480'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.639480'::ltree AND
 localcode_ltree <@ '100.639480'::ltree
 GROUP BY name, '100.639480'::ltree, '100.639480'::ltree;



INSERT INTO whse_basemapping.fwa_basins_poly
(name, wscode_ltree, localcode_ltree, geom)
SELECT
 'Kootenay River' as name,
'300.625474'::ltree as wscode_ltree,
'300.625474'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '300.625474' AND
 localcode_ltree <@ '300.625474'::ltree
GROUP BY name, '300.625474'::ltree, '300.625474'::ltree;

-- we want to be able to quickly relate these back to watershed groups
ALTER TABLE whse_basemapping.fwa_watershed_groups_poly ADD COLUMN IF NOT EXISTS basin_id integer;

UPDATE whse_basemapping.fwa_watershed_groups_poly
SET watershed_cache_id = 1
WHERE wscode_ltree <@ '100.190442'::ltree AND
localcode_ltree <@ '100.190442'::ltree;

UPDATE whse_basemapping.fwa_watershed_groups_poly
SET watershed_cache_id = 2
WHERE wscode_ltree <@ '100.458399'::ltree AND
localcode_ltree <@ '100.458399'::ltree;

UPDATE whse_basemapping.fwa_watershed_groups_poly
SET watershed_cache_id = 3
WHERE wscode_ltree <@ '100.500560'::ltree AND
localcode_ltree <@ '100.500560'::ltree;

UPDATE whse_basemapping.fwa_watershed_groups_poly
SET watershed_cache_id = 4
WHERE wscode_ltree <@ '100.567134'::ltree AND
localcode_ltree <@ '100.567134'::ltree;

UPDATE whse_basemapping.fwa_watershed_groups_poly
SET watershed_cache_id = 5
WHERE wscode_ltree <@ '100.591289'::ltree AND
localcode_ltree <@ '100.591289'::ltree;

UPDATE whse_basemapping.fwa_watershed_groups_poly
SET watershed_cache_id = 6
WHERE wscode_ltree <@ '100.639480'::ltree AND
localcode_ltree <@ '100.639480'::ltree;

UPDATE whse_basemapping.fwa_watershed_groups_poly
SET watershed_cache_id = 7
WHERE wscode_ltree <@ '100.342455'::ltree AND
localcode_ltree <@ '100.342455'::ltree;

UPDATE whse_basemapping.fwa_watershed_groups_poly
SET watershed_cache_id = 8
WHERE wscode_ltree <@ '300.625474'::ltree AND
localcode_ltree <@ '300.625474'::ltree;

CREATE INDEX ON whse_basemapping.fwa_basins_poly USING GIST (geom);