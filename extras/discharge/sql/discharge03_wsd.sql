-- Calculated area-weighted discharge and convert to m3/s for given watershed group, load to discharge03_wsd

BEGIN;

  SET max_parallel_workers_per_gather = 0;
  
  INSERT INTO fwapg.discharge03_wsd
  (
    watershed_feature_id,
    watershed_group_code,
    mad_mm,
    mad_m3s
  )

  -- get raw discharge values from discharge02_load (result of wsd overlay with raster)
  -- BUT - do not include watershed polygons for rivers of order >=8 - we
  -- do not generally care about the discharge of these large rivers and modelling their
  -- discharge can be very slow (so many records upstream)
  WITH order8rivs AS (
    SELECT DISTINCT ON (wscode_ltree)
      wscode_ltree,
      localcode_ltree,
      gnis_name,
      stream_order,
      watershed_group_code
    FROM whse_basemapping.fwa_stream_networks_sp
    WHERE stream_order >= 8
    AND localcode_ltree IS NOT NULL
    ORDER BY wscode_ltree, localcode_ltree desc
  ),

  src AS (
    SELECT
      w.watershed_feature_id,
      w.wscode_ltree,
      w.localcode_ltree,
      w.watershed_group_code,
      w.geom
    FROM whse_basemapping.fwa_watersheds_poly w
    LEFT OUTER JOIN order8rivs b
    ON w.wscode_ltree = b.wscode_ltree
    AND w.localcode_ltree < b.localcode_ltree
    WHERE w.watershed_group_code = :'wsg'
    AND b.wscode_ltree IS NULL
  ),

  -- calculate weighted average of discharge for all area upstream of given wsd polygon
  weighted_avg AS (
    SELECT
      a.watershed_feature_id,
      b.watershed_feature_id as id_up,
      b.discharge_mm,
      a.watershed_group_code,
      ua.upstream_area_ha * 10000 as upstream_area_m2,
      ST_Area(uw.geom) as area,
      ST_Area(uw.geom) / (upstream_area_ha * 10000) as pct,
      (ST_Area(uw.geom) / (upstream_area_ha * 10000)) * b.discharge_mm as weighted_discharge,
      a.geom
    FROM src a
    INNER JOIN whse_basemapping.fwa_watersheds_upstream_area ua
      ON a.watershed_feature_id = ua.watershed_feature_id
    INNER JOIN whse_basemapping.fwa_watersheds_poly uw
      ON FWA_Upstream(a.wscode_ltree, a.localcode_ltree, uw.wscode_ltree, uw.localcode_ltree)
    INNER JOIN fwapg.discharge02_load b
      ON uw.watershed_feature_id = b.watershed_feature_id
  )

  -- populate output with the area-weighted average mm discharge and also convert to m3s
  SELECT
    a.watershed_feature_id,
    a.watershed_group_code,
    round(sum(weighted_discharge)::numeric, 5) as mad_mm,
    round(((sum(weighted_discharge) * a.upstream_area_m2) / 31536000000.0)::numeric, 5) as mad_m3s  -- m3s = (mm * m2 upstream area) / (1000mm/m * 365d/y * 24h/d * 3600s/h)
  FROM weighted_avg a
  GROUP BY a.watershed_feature_id, a.watershed_group_code, a.upstream_area_m2;

COMMIT;