insert into whse_basemapping.fwa_watershed_groups_poly (
  watershed_group_id,
  watershed_group_code,
  watershed_group_name,
  area_ha,
  feature_code,
  geom
)
select
  watershed_group_id::integer as watershed_group_id,
  watershed_group_code,
  watershed_group_name,
  area_ha::double precision as area_ha,
  feature_code,
  geom
from fwapg.fwa_watershed_groups_poly;

-- load watershed codes (used for deriving basins table)
UPDATE whse_basemapping.fwa_watershed_groups_poly a
SET
  fwa_watershed_code = b.fwa_watershed_code,
  local_watershed_code = b.local_watershed_code
FROM
(
    SELECT DISTINCT ON (watershed_group_id)
      watershed_group_id,
      fwa_watershed_code,
      local_watershed_code
    FROM whse_basemapping.fwa_assessment_watersheds_poly
    ORDER BY
      watershed_group_id,
      fwa_watershed_code,
      local_watershed_code asc
) b
WHERE a.watershed_group_id = b.watershed_group_id;


-- load basin ids

-- thompson
UPDATE whse_basemapping.fwa_watershed_groups_poly
SET basin_id = 1
WHERE wscode_ltree <@ '100.190442'::ltree AND
localcode_ltree <@ '100.190442'::ltree;

-- chilcotin
UPDATE whse_basemapping.fwa_watershed_groups_poly
SET basin_id = 2
WHERE wscode_ltree <@ '100.342455'::ltree AND
localcode_ltree <@ '100.342455'::ltree;

-- quesnel
UPDATE whse_basemapping.fwa_watershed_groups_poly
SET basin_id = 3
WHERE wscode_ltree <@ '100.458399'::ltree AND
localcode_ltree <@ '100.458399'::ltree;

-- blackwater
UPDATE whse_basemapping.fwa_watershed_groups_poly
SET basin_id = 4
WHERE wscode_ltree <@ '100.500560'::ltree AND
localcode_ltree <@ '100.500560'::ltree;

--chilako
UPDATE whse_basemapping.fwa_watershed_groups_poly
SET basin_id = 5
WHERE wscode_ltree <@ '100.567134'::ltree AND
localcode_ltree <@ '100.567134'::ltree;

-- salmon
UPDATE whse_basemapping.fwa_watershed_groups_poly
SET basin_id = 6
WHERE wscode_ltree <@ '100.591289'::ltree AND
localcode_ltree <@ '100.591289'::ltree;

-- mcgregor
UPDATE whse_basemapping.fwa_watershed_groups_poly
SET basin_id = 7
WHERE wscode_ltree <@ '100.639480'::ltree AND
localcode_ltree <@ '100.639480'::ltree;

-- kootenay
UPDATE whse_basemapping.fwa_watershed_groups_poly
SET basin_id = 8
WHERE wscode_ltree <@ '300.625474'::ltree AND
localcode_ltree <@ '300.625474'::ltree;

-- beatton
UPDATE whse_basemapping.fwa_watershed_groups_poly
SET basin_id = 9
WHERE wscode_ltree <@ '200.948755.796981'::ltree AND
localcode_ltree <@ '200.948755.796981'::ltree;
