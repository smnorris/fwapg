-- Watersheds for larger basins in BC
-- Similar to https://catalogue.data.gov.bc.ca/dataset/bc-major-basins-river-forecast-centre
-- but - Based on FWA linework and includes additional smaller units.
-- Currently only used to speed generation of watershed polygons
-- todo: add more basins for greater utility
-- Fraser, Columbia, Peace, Liard, Nass, Skeena, Stikine,
-- plus any other grouping of >2-3 watershed groups that is a complete (within BC) watershed

-- To speed up basin creation we can use watershed groups as building blocks.
-- Note that watershed groups are arbitrary groupings (historically created as
-- work units), the features do not necessarily drain to a single point. This is obvious
-- on the coast, but is also possible for interior groups. Therefore, it makes
-- sense that there are no watershed codes provided in the watershed group table,
-- they are not particularly meaningful.


INSERT INTO whse_basemapping.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 1 as basin_id,
 'Thompson River' as basin_name,
'100.190442'::ltree as wscode_ltree,
'100.190442'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.190442'::ltree AND
 localcode_ltree <@ '100.190442'::ltree
GROUP BY basin_name, '100.190442'::ltree, '100.190442'::ltree;

INSERT INTO whse_basemapping.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 2 as basin_id,
 'Chilcotin River' as basin_name,
'100.342455'::ltree as wscode_ltree,
'100.342455'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.342455'::ltree AND
 localcode_ltree <@ '100.342455'::ltree
 GROUP BY basin_name, '100.342455'::ltree, '100.342455'::ltree;

INSERT INTO whse_basemapping.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 3 as basin_id,
 'Quesnel River' as basin_name,
'100.458399'::ltree as wscode_ltree,
'100.458399'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.458399'::ltree AND
 localcode_ltree <@ '100.458399'::ltree
 GROUP BY basin_name, '100.458399'::ltree, '100.458399'::ltree;

INSERT INTO whse_basemapping.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 4 as basin_id,
 'Blackwater River' as basin_name,
'100.500560'::ltree as wscode_ltree,
'100.500560'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.500560'::ltree AND
 localcode_ltree <@ '100.500560'::ltree
 GROUP BY basin_name, '100.500560'::ltree, '100.500560'::ltree;

INSERT INTO whse_basemapping.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 5 as basin_id,
 'Chilako River' as basin_name,
'100.567134'::ltree as wscode_ltree,
'100.567134'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.567134'::ltree AND
 localcode_ltree <@ '100.567134'::ltree
 GROUP BY basin_name, '100.567134'::ltree, '100.567134'::ltree;

INSERT INTO whse_basemapping.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 6 as basin_id,
 'Salmon River' as basin_name,
'100.591289'::ltree as wscode_ltree,
'100.591289'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.591289'::ltree AND
 localcode_ltree <@ '100.591289'::ltree
 GROUP BY basin_name, '100.591289'::ltree, '100.591289'::ltree;

INSERT INTO whse_basemapping.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 7 as basin_id,
 'McGregor River' as basin_name,
'100.639480'::ltree as wscode_ltree,
'100.639480'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.639480'::ltree AND
 localcode_ltree <@ '100.639480'::ltree
 GROUP BY basin_name, '100.639480'::ltree, '100.639480'::ltree;

INSERT INTO whse_basemapping.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 8 as basin_id,
 'Kootenay River' as basin_name,
'300.625474'::ltree as wscode_ltree,
'300.625474'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '300.625474' AND
 localcode_ltree <@ '300.625474'::ltree
GROUP BY basin_name, '300.625474'::ltree, '300.625474'::ltree;

INSERT INTO whse_basemapping.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 9 as basin_id,
 'Beatton River' as basin_name,
'200.948755.796981'::ltree as wscode_ltree,
'200.948755.796981'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM whse_basemapping.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '200.948755.796981' AND
 localcode_ltree <@ '200.948755.796981'::ltree
GROUP BY basin_name, '200.948755.796981'::ltree, '200.948755.796981'::ltree;

