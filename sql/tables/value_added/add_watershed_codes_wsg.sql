-- Watershed groups are arbitrary groupings (historically created as work units),
-- the watersheds do not necessarily drain to a single point. This is obvious
-- on the coast, but is also possible for interior groups. Therefore, it makes
-- sense that there are no watershed codes provided in the watershed group table,
-- they are not particularly meaningful.
-- However, watershed groups are a very convenient pre-existing unit that we
-- can use as pre-aggregated units for speeding up ad-hoc watershed queries.
-- We can update the existing watershed group table with the minimum codes found
-- in the group, taking the minimum from assessment watersheds within the group.

-- add the columns
ALTER TABLE whse_basemapping.fwa_watershed_groups_poly
  ADD COLUMN IF NOT EXISTS fwa_watershed_code character varying(143);
ALTER TABLE whse_basemapping.fwa_watershed_groups_poly
  ADD COLUMN IF NOT EXISTS local_watershed_code character varying(143);

-- add the minimum watershed codes per group
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

-- add the ltree watershed code columns for fast searches
ALTER TABLE whse_basemapping.fwa_watershed_groups_poly
  ADD COLUMN IF NOT EXISTS wscode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;
ALTER TABLE whse_basemapping.fwa_watershed_groups_poly
  ADD COLUMN IF NOT EXISTS localcode_ltree ltree
  GENERATED ALWAYS AS (REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.')::ltree) STORED;