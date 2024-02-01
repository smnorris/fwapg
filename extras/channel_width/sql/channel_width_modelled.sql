-- Model channel width - based on upstream area and precip


DROP TABLE IF EXISTS bcfishpass.channel_width_modelled;

CREATE TABLE bcfishpass.channel_width_modelled
(
  channel_width_id serial primary key,
  wscode_ltree ltree,
  localcode_ltree ltree,
  watershed_group_code text,
  channel_width_modelled double precision,
  UNIQUE (wscode_ltree, localcode_ltree, watershed_group_code)
);


WITH streams AS
(
SELECT
-- a given watershed code combination can have more than one magnitude (side channels)
-- and more than one upstream area (several watershed polys can have with the same codes)
-- So, to get distinct codes, simply take the maximum upstream_area, this won't make much/any
-- difference in the output
  s.wscode_ltree,
  s.localcode_ltree,
  s.watershed_group_code,
  max(COALESCE(ua.upstream_area_ha, 0)) + 1 as upstream_area_ha
FROM whse_basemapping.fwa_stream_networks_sp s
LEFT OUTER JOIN whse_basemapping.fwa_waterbodies wb
ON s.waterbody_key = wb.waterbody_key
LEFT OUTER JOIN whse_basemapping.fwa_streams_watersheds_lut l
ON s.linear_feature_id = l.linear_feature_id
INNER JOIN whse_basemapping.fwa_watersheds_upstream_area ua
ON l.watershed_feature_id = ua.watershed_feature_id
-- we only want widths of streams/rivers
-- WHERE (wb.waterbody_type = 'R' OR (wb.waterbody_type IS NULL AND s.edge_type IN (1000,1100,2000,2300)))
WHERE s.localcode_ltree IS NOT NULL
GROUP BY s.wscode_ltree, s.localcode_ltree, s.watershed_group_code

)

INSERT INTO bcfishpass.channel_width_modelled
(
  wscode_ltree,
  localcode_ltree,
  watershed_group_code,
  channel_width_modelled
)

SELECT
  s.wscode_ltree,
  s.localcode_ltree,
  s.watershed_group_code,
  -- formula for predicting channel width is from Thorley and Irvine 2021
  --round(
  --    (EXP(-2.2383120 + 0.3121556 * ln(s.upstream_area_ha / 100) + 0.6546995 * ln(p.map_upstream / 10))
  --  )::numeric, 2
  --)
  -- updated formula, Thorley and Irvine 2021b
  round(
    exp(0.3071300 + 0.4577882 *
        (ln(s.upstream_area_ha) + ln(coalesce(p.map_upstream, 0) + 1) - ln(100) - ln(1000))
      )::numeric, 2) as channel_width_modelled
FROM streams s
INNER JOIN bcfishpass.mean_annual_precip p
ON s.wscode_ltree = p.wscode_ltree
AND s.localcode_ltree = p.localcode_ltree
WHERE s.upstream_area_ha IS NOT NULL;


CREATE INDEX ON bcfishpass.channel_width_modelled USING GIST (wscode_ltree);
CREATE INDEX ON bcfishpass.channel_width_modelled USING BTREE (wscode_ltree);
CREATE INDEX ON bcfishpass.channel_width_modelled USING GIST (localcode_ltree);
CREATE INDEX ON bcfishpass.channel_width_modelled USING BTREE (localcode_ltree);
