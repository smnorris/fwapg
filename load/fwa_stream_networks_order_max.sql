-- report on max order of given blue line key, useful for filtering when mapping at various scales
BEGIN;

  TRUNCATE whse_basemapping.fwa_stream_networks_order_max;

  insert into whse_basemapping.fwa_stream_networks_order_max
  (blue_line_key, stream_order_max)
  select
    blue_line_key,
    max(stream_order) as max_stream_order
  from whse_basemapping.fwa_stream_networks_sp
  where fwa_watershed_code is not null
  and watershed_key = blue_line_key
  and edge_type != 6010
  and fwa_watershed_code not like '999%'
  group by blue_line_key;

COMMIT;