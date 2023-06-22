-- 1505 features in sooke drainage with non-null local codes
select count(*) = 1505 as result
from FWA_UpstreamTrace(354153927, 100);

-- within tolerance to start point
select count(*) = 1505 as result
from FWA_UpstreamTrace(354153927, 1, 2);

-- within tolerance to end point
select count(*) = 1504 as result
from FWA_UpstreamTrace(354153927, 694);

-- end of the line
select count(*) = 1 as result
from FWA_UpstreamTrace(354113580, 100);

-- beyond end of stream
select count(*) = 0 as result
from FWA_UpstreamTrace(354113580, 622);

-- is stream getting cut correctly? (new length = difference in measures)
select round(st_length(geom)::numeric, 4) = round((upstream_route_measure - downstream_route_measure)::numeric, 4) as result
from FWA_UpstreamTrace(354153927, 100)
where linear_feature_id = 710513719;
