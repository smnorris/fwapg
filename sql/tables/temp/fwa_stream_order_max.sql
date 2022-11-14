-- report on max order of given blue line key, useful for filtering when mapping at various scales

drop table if exists fwapg.fwa_stream_order_max ;

create table fwapg.fwa_stream_order_max
  (blue_line_key integer primary key,
    stream_order_max integer);

insert into fwapg.fwa_stream_order_max
(blue_line_key, stream_order_max)
select 
  blue_line_key,
  max(stream_order) as max_stream_order
from fwapg.fwa_stream_networks_sp
where wscode_ltree is not null
and watershed_key = blue_line_key
and edge_type != 6010
and wscode_ltree <@ '999'::ltree is false
group by blue_line_key;