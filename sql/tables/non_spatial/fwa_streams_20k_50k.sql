insert into whse_basemapping.fwa_streams_20k_50k (
  stream_20k_50k_id,
  watershed_group_id_20k,
  linear_feature_id_20k,
  blue_line_key_20k,
  watershed_key_20k,
  fwa_watershed_code_20k,
  watershed_group_code_20k,
  blue_line_key_50k,
  watershed_key_50k,
  watershed_code_50k,
  watershed_group_code_50k,
  match_type
)
select
  stream_20k_50k_id,
  watershed_group_id_20k,
  linear_feature_id_20k,
  blue_line_key_20k,
  watershed_key_20k,
  fwa_watershed_code_20k,
  watershed_group_code_20k,
  blue_line_key_50k,
  watershed_key_50k,
  watershed_code_50k,
  watershed_group_code_50k,
  match_type
from fwapg.fwa_streams_20k_50k;