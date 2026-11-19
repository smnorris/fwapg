-- very basic FWA_IndexPoint tests, all should return result=t

-- simple closest stream
SELECT gnis_name = 'Bowker Creek' as result
FROM postgisftw.FWA_IndexPoint(1199447.0, 383113.0, 3005);

-- geometry form of function
SELECT gnis_name = 'Bowker Creek' as result
FROM FWA_IndexPoint(ST_SetSRID(ST_MakePoint(1199447.0, 383113.0), 3005));

-- outside BC
SELECT bc_ind = 'f' as result
FROM postgisftw.FWA_IndexPoint(1263072, 447879, 3005);

-- return up to 10 streams within 1km - 4 results in this case
SELECT COUNT(*) = 4 as result
FROM postgisftw.FWA_IndexPoint(1184984, 421568, 3005, 1000, 10);

-- try something really close
SELECT distance_to_stream < 1 as result
FROM postgisftw.FWA_IndexPoint(1179988, 407541, 3005);

-- try a UTMZ10 point
SELECT gnis_name = 'Shawnigan Creek' as result
FROM postgisftw.FWA_IndexPoint(458696, 5389371, 26910);

-- Teanook Lake is disconnected, ensure it is returned
SELECT blue_line_key = 354094227 as result
FROM postgisftw.FWA_IndexPoint(1184392,389012, 3005, 300, 3)
limit 1;

-- a point whose nearest point on two segments of one stream is the vertex they
-- share: take the segment starting at the vertex (here the segment above a tributary)
SELECT (
  SELECT linear_feature_id
  FROM postgisftw.FWA_IndexPoint(-126.697631836, 55.4265403748, 4326, 5000, 5)
  WHERE blue_line_key = 360886970
) = 5086970 as result;

SELECT (
  SELECT linear_feature_id
  FROM postgisftw.FWA_IndexPoint(-122.373062134, 54.0455589294, 4326, 5000, 5)
  WHERE blue_line_key = 356360570
) = 703862887 as result;

-- the measure returned at a vertex is one FWA_LocateAlong can find
SELECT count(*) = 1 as result
FROM FWA_LocateAlong(356360570, (
  SELECT downstream_route_measure
  FROM postgisftw.FWA_IndexPoint(-122.373062134, 54.0455589294, 4326, 5000, 5)
  WHERE blue_line_key = 356360570
));
