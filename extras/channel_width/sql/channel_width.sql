WITH cwmeas AS
(
  SELECT DISTINCT
    s.linear_feature_id,
    c.channel_width_measured AS cw
  FROM whse_basemapping.fwa_stream_networks_sp s
  LEFT OUTER JOIN bcfishpass.channel_width_measured c
    ON s.wscode_ltree = c.wscode_ltree
    AND s.localcode_ltree = c.localcode_ltree
  LEFT OUTER JOIN whse_basemapping.fwa_waterbodies wb
    ON s.waterbody_key = wb.waterbody_key
  WHERE s.watershed_group_code = :'wsg'
),

cwmap AS 
(
  SELECT
  a.linear_feature_id,
  ROUND(avg(a.channel_width_mapped)::numeric, 2) as cw
FROM bcfishpass.channel_width_mapped a
WHERE a.watershed_group_code = :'wsg'
GROUP BY a.linear_feature_id
),

cwmodel AS
(
  SELECT DISTINCT
    s.linear_feature_id,
    c.channel_width_modelled AS cw
  FROM whse_basemapping.fwa_stream_networks_sp s
  LEFT OUTER JOIN bcfishpass.channel_width_modelled c
    ON s.wscode_ltree = c.wscode_ltree
    AND s.localcode_ltree = c.localcode_ltree
    AND s.watershed_group_code = c.watershed_group_code
  LEFT OUTER JOIN whse_basemapping.fwa_waterbodies wb
    ON s.waterbody_key = wb.waterbody_key
    WHERE s.stream_order > 1 AND
    s.watershed_group_code = :'wsg'
)

INSERT INTO bcfishpass.channel_width 
(linear_feature_id, channel_width_source, channel_width)

SELECT
  s.linear_feature_id,
  case when cwmeas.cw is not null then 'FIELD_MEASURMENT'
       when cwmap.cw is not null then 'FWA_RIVERS_POLY'
       when cwmodel.cw is not null then 'MODELLED'
  end as channel_width_source,
  COALESCE(cwmeas.cw, cwmap.cw, cwmodel.cw)
FROM whse_basemapping.fwa_stream_networks_sp s 
LEFT OUTER JOIN cwmeas ON s.linear_feature_id = cwmeas.linear_feature_id
LEFT OUTER JOIN cwmap ON s.linear_feature_id = cwmap.linear_feature_id
LEFT OUTER JOIN cwmodel ON s.linear_feature_id = cwmodel.linear_feature_id
WHERE s.watershed_group_code = :'wsg'