-- very basic fwa_neareststream tests, all should return result=t

-- simple closest stream
SELECT gnis_name = 'Bowker Creek' as result
FROM postgisftw.FWA_NearestStream(1199447.0, 383113.0, 3005);

-- outside BC
SELECT bc_ind = 'f' as result
FROM postgisftw.FWA_NearestStream(1263072, 447879, 3005);

-- return up to 10 streams within 1km - 4 results in this case
SELECT COUNT(*) = 4 as result
FROM postgisftw.FWA_NearestStream(1184984, 421568, 3005, 1000, 10);

-- try something really close
SELECT distance_to_stream < 1 as result
FROM postgisftw.FWA_NearestStream(1179988, 407541, 3005);

-- try a UTMZ10 point
SELECT gnis_name = 'Shawnigan Creek' as result
FROM postgisftw.FWA_NearestStream(458696, 5389371, 26910);
