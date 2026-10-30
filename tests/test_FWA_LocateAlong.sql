-- https://github.com/smnorris/fwapg/issues/81
select st_astext(postgisftw.fwa_locatealong(356493192, 340.150635772625)) = 'POINT ZM (1595887.8029999994 515210.8049999997 442.00600000005215 340.150635772625)';

-- a measure at a junction is on the segment starting there (08KD006, Willow River above Hay Creek)
select (
  select st_equals(geom, (select st_startpoint(geom) from whse_basemapping.fwa_stream_networks_sp where linear_feature_id = 703862887))
  from fwa_locatealong(356360570, 14040.0058125527)
) as result;

-- a measure at a stream's head (the top segment's end) returns that point
select count(*) = 1 as result
from fwa_locatealong(356067104, 143.22395295247208);

-- a measure in the gap between two segments' recorded measures, and one past the
-- stream's head, return nothing
select count(*) = 0 as result
from fwa_locatealong(356360570, 14040.0053);

select count(*) = 0 as result
from fwa_locatealong(356067104, 144.2239529524721);
