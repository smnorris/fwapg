-- cut first segment on sooke river
select length_metre = 100 as result
from FWA_DownstreamTrace(354153927, 100);

-- count features downstream of old wolf lake
select count(*) = 33 as result
from FWA_DownstreamTrace(354148481, 4864, 2);

-- within tolerance to upstream_route_measure of first included line (do not split)
select count(*) = 7 as result
from FWA_DownstreamTrace(354153927, 5175, 1);

-- within tolerance to start point, check output measure (nothing cut)
select round(upstream_route_measure::numeric, 2) = 5175.50 as result
from FWA_DownstreamTrace(354153927, 5175, 1)
limit 1;

-- within tolerance to end point
select count(*) = 8 as result
from FWA_DownstreamTrace(354153927, 5175.7, 1);

-- beyond end of stream
select count(*) = 0 as result
from FWA_DownstreamTrace(354113580, 622);

-- is stream getting cut correctly? (new length = difference in measures)
select round(st_length(geom)::numeric, 4) = round((upstream_route_measure - downstream_route_measure)::numeric, 4) as result
from FWA_DownstreamTrace(354153927, 100);
