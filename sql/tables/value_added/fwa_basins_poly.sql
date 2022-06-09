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

-- add columns
ALTER TABLE fwapg.fwa_watershed_groups_poly
  ADD COLUMN IF NOT EXISTS fwa_watershed_code character varying(143);
ALTER TABLE fwapg.fwa_watershed_groups_poly
  ADD COLUMN IF NOT EXISTS local_watershed_code character varying(143);

-- find the minimum watershed codes per group
-- based on assessment watersheds
UPDATE fwapg.fwa_watershed_groups_poly a
SET
  fwa_watershed_code = b.fwa_watershed_code,
  local_watershed_code = b.local_watershed_code
FROM
(
    SELECT DISTINCT ON (watershed_group_id)
      watershed_group_id,
      fwa_watershed_code,
      local_watershed_code
    FROM fwapg.fwa_assessment_watersheds_poly
    ORDER BY
      watershed_group_id,
      fwa_watershed_code,
      local_watershed_code asc
) b
WHERE a.watershed_group_id = b.watershed_group_id;

-- add the ltree watershed code columns for fast searches
ALTER TABLE fwapg.fwa_watershed_groups_poly
  ADD COLUMN IF NOT EXISTS wscode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
ALTER TABLE fwapg.fwa_watershed_groups_poly
  ADD COLUMN IF NOT EXISTS localcode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;


-- now create the basins table from above
DROP TABLE IF EXISTS fwapg.fwa_basins_poly;

CREATE TABLE fwapg.fwa_basins_poly
(basin_id integer primary key,
 basin_name text,
 wscode_ltree ltree,
 localcode_ltree ltree,
 geom Geometry(Polygon, 3005));

INSERT INTO fwapg.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 1 as basin_id,
 'Thompson River' as basin_name,
'100.190442'::ltree as wscode_ltree,
'100.190442'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM fwapg.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.190442'::ltree AND
 localcode_ltree <@ '100.190442'::ltree
GROUP BY basin_name, '100.190442'::ltree, '100.190442'::ltree;

INSERT INTO fwapg.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 2 as basin_id,
 'Chilcotin River' as basin_name,
'100.342455'::ltree as wscode_ltree,
'100.342455'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM fwapg.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.342455'::ltree AND
 localcode_ltree <@ '100.342455'::ltree
 GROUP BY basin_name, '100.342455'::ltree, '100.342455'::ltree;

INSERT INTO fwapg.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 3 as basin_id,
 'Quesnel River' as basin_name,
'100.458399'::ltree as wscode_ltree,
'100.458399'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM fwapg.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.458399'::ltree AND
 localcode_ltree <@ '100.458399'::ltree
 GROUP BY basin_name, '100.458399'::ltree, '100.458399'::ltree;

INSERT INTO fwapg.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 4 as basin_id,
 'Blackwater River' as basin_name,
'100.500560'::ltree as wscode_ltree,
'100.500560'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM fwapg.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.500560'::ltree AND
 localcode_ltree <@ '100.500560'::ltree
 GROUP BY basin_name, '100.500560'::ltree, '100.500560'::ltree;

INSERT INTO fwapg.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 5 as basin_id,
 'Chilako River' as basin_name,
'100.567134'::ltree as wscode_ltree,
'100.567134'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM fwapg.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.567134'::ltree AND
 localcode_ltree <@ '100.567134'::ltree
 GROUP BY basin_name, '100.567134'::ltree, '100.567134'::ltree;

INSERT INTO fwapg.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 6 as basin_id,
 'Salmon River' as basin_name,
'100.591289'::ltree as wscode_ltree,
'100.591289'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM fwapg.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.591289'::ltree AND
 localcode_ltree <@ '100.591289'::ltree
 GROUP BY basin_name, '100.591289'::ltree, '100.591289'::ltree;

INSERT INTO fwapg.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 7 as basin_id,
 'McGregor River' as basin_name,
'100.639480'::ltree as wscode_ltree,
'100.639480'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM fwapg.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '100.639480'::ltree AND
 localcode_ltree <@ '100.639480'::ltree
 GROUP BY basin_name, '100.639480'::ltree, '100.639480'::ltree;

INSERT INTO fwapg.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 8 as basin_id,
 'Kootenay River' as basin_name,
'300.625474'::ltree as wscode_ltree,
'300.625474'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM fwapg.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '300.625474' AND
 localcode_ltree <@ '300.625474'::ltree
GROUP BY basin_name, '300.625474'::ltree, '300.625474'::ltree;

INSERT INTO fwapg.fwa_basins_poly
(basin_id, basin_name, wscode_ltree, localcode_ltree, geom)
SELECT
 9 as basin_id,
 'Beatton River' as basin_name,
'200.948755.796981'::ltree as wscode_ltree,
'200.948755.796981'::ltree as localcode_ltree,
 ST_Union(geom) as geom
FROM fwapg.fwa_watershed_groups_poly
WHERE
 wscode_ltree <@ '200.948755.796981' AND
 localcode_ltree <@ '200.948755.796981'::ltree
GROUP BY basin_name, '200.948755.796981'::ltree, '200.948755.796981'::ltree;



-- To be able to quickly relate basins to watershed groups, add
-- basin id as fk in watershed groups

ALTER TABLE fwapg.fwa_watershed_groups_poly ADD COLUMN IF NOT EXISTS basin_id integer;

-- thompson
UPDATE fwapg.fwa_watershed_groups_poly
SET basin_id = 1
WHERE wscode_ltree <@ '100.190442'::ltree AND
localcode_ltree <@ '100.190442'::ltree;

-- chilcotin
UPDATE fwapg.fwa_watershed_groups_poly
SET basin_id = 2
WHERE wscode_ltree <@ '100.342455'::ltree AND
localcode_ltree <@ '100.342455'::ltree;

-- quesnel
UPDATE fwapg.fwa_watershed_groups_poly
SET basin_id = 3
WHERE wscode_ltree <@ '100.458399'::ltree AND
localcode_ltree <@ '100.458399'::ltree;

-- blackwater
UPDATE fwapg.fwa_watershed_groups_poly
SET basin_id = 4
WHERE wscode_ltree <@ '100.500560'::ltree AND
localcode_ltree <@ '100.500560'::ltree;

--chilako
UPDATE fwapg.fwa_watershed_groups_poly
SET basin_id = 5
WHERE wscode_ltree <@ '100.567134'::ltree AND
localcode_ltree <@ '100.567134'::ltree;

-- salmon
UPDATE fwapg.fwa_watershed_groups_poly
SET basin_id = 6
WHERE wscode_ltree <@ '100.591289'::ltree AND
localcode_ltree <@ '100.591289'::ltree;

-- mcgregor
UPDATE fwapg.fwa_watershed_groups_poly
SET basin_id = 7
WHERE wscode_ltree <@ '100.639480'::ltree AND
localcode_ltree <@ '100.639480'::ltree;

-- kootenay
UPDATE fwapg.fwa_watershed_groups_poly
SET basin_id = 8
WHERE wscode_ltree <@ '300.625474'::ltree AND
localcode_ltree <@ '300.625474'::ltree;

-- beatton
UPDATE fwapg.fwa_watershed_groups_poly
SET basin_id = 9
WHERE wscode_ltree <@ '200.948755.796981'::ltree AND
localcode_ltree <@ '200.948755.796981'::ltree;


CREATE INDEX ON fwapg.fwa_basins_poly USING GIST (geom);
CREATE INDEX ON fwapg.fwa_basins_poly USING GIST (wscode_ltree);
CREATE INDEX ON fwapg.fwa_basins_poly USING BTREE (wscode_ltree);
CREATE INDEX ON fwapg.fwa_basins_poly USING GIST (localcode_ltree);
CREATE INDEX ON fwapg.fwa_basins_poly USING BTREE (localcode_ltree);

COMMENT ON TABLE fwapg.fwa_basins_poly IS 'Large BC waterhseds consisting of at least 2-3 watershed groups, used by fwapg for watershed pre-aggregation';
COMMENT ON COLUMN fwapg.fwa_basins_poly.basin_id IS 'Basin unique identifier';
COMMENT ON COLUMN fwapg.fwa_basins_poly.basin_name IS 'Basin name, eg Thompson River';
COMMENT ON COLUMN fwapg.fwa_basins_poly.wscode_ltree IS 'The watershed code associated with the stream at the outlet of the basin';
COMMENT ON COLUMN fwapg.fwa_basins_poly.localcode_ltree IS 'The local watershed code associated with the stream at the outlet of the basin';
COMMENT ON COLUMN fwapg.fwa_basins_poly.geom IS 'Geometry of the basin';