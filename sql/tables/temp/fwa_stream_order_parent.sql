-- create lookup linking streams to their parent order
-- (generally used for finding small channels that drain into major rivers)

-- load primary channels
insert into fwapg.fwa_stream_order_parent
    (blue_line_key, stream_order_parent)
  select distinct on (a.blue_line_key)
    a.blue_line_key,
    b.stream_order as stream_order_parent
  from fwapg.fwa_stream_networks_sp a
  left outer join fwapg.fwa_stream_networks_sp b
  on a.wscode_ltree = b.localcode_ltree
  where
    a.watershed_group_code = :'wsg'
    and a.blue_line_key = a.watershed_key
    and b.blue_line_key = b.watershed_key
    and a.wscode_ltree <@ '999' is false
    and a.edge_type != 6010
    and a.localcode_ltree is not null
    and a.blue_line_key != b.blue_line_key
  order by a.blue_line_key, b.stream_order desc
  on conflict do nothing;

-- load side channels
-- (use the order of non-side channel stream with equivalent watershed codes
-- as the side channel)
-- NOTE - this will not populate parent order for side channels that do not
-- have local codes
insert into fwapg.fwa_stream_order_parent (
  blue_line_key,
  stream_order_parent
)
select distinct on (a.blue_line_key)
  a.blue_line_key,
  b.stream_order as stream_order_parent
from fwapg.fwa_stream_networks_sp a
left outer join fwapg.fwa_stream_networks_sp b
on (a.wscode_ltree = b.wscode_ltree and
    a.localcode_ltree = b.localcode_ltree)
where
  a.watershed_group_code = :'wsg'
  and a.blue_line_key != a.watershed_key
  and b.blue_line_key = b.watershed_key
  and a.wscode_ltree <@ '999' is false
  and a.edge_type != 6010
  and a.localcode_ltree is not null
  and a.blue_line_key != b.blue_line_key
order by a.blue_line_key, b.stream_order desc
on conflict do nothing;