-- Join discharge per wsd to streams via streams-wsd lookup to create
-- per-linear_feature_id discharge table

INSERT INTO whse_basemapping.fwa_stream_networks_discharge
(linear_feature_id, watershed_group_code, mad_mm, mad_m3s)
SELECT
  s.linear_feature_id,
  s.watershed_group_code,
  mad.mad_mm,
  mad.mad_m3s
FROM whse_basemapping.fwa_stream_networks_sp s
INNER JOIN whse_basemapping.fwa_streams_watersheds_lut l
ON s.linear_feature_id = l.linear_feature_id
INNER JOIN fwapg.discharge03_wsd mad
ON l.watershed_feature_id = mad.watershed_feature_id
WHERE s.watershed_group_code = :'wsg'
ON CONFLICT DO NOTHING;