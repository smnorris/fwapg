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
