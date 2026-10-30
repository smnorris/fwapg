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

-- the returned point keeps the stream's z and m, in BC Albers (ST_Zmflag 3 = ZM).
-- New cases wrap the call in a scalar subquery, so a call returning no row
-- prints a blank result rather than nothing.
SELECT (
  SELECT ST_Zmflag(geom) = 3 AND ST_SRID(geom) = 3005 AND ST_M(geom) = downstream_route_measure
  FROM postgisftw.FWA_IndexPoint(1199447.0, 383113.0, 3005)
) as result;

-- the point is the closest point on the matched segment, and the measure lies on that segment
SELECT (
  SELECT ST_Distance(i.geom, ST_ClosestPoint(s.geom, ST_SetSRID(ST_MakePoint(1199447.0, 383113.0), 3005))) < 1e-6
    AND i.downstream_route_measure BETWEEN s.downstream_route_measure AND s.upstream_route_measure
    AND abs(ST_Distance(i.geom, ST_SetSRID(ST_MakePoint(1199447.0, 383113.0), 3005)) - i.distance_to_stream) < 5e-4
  FROM postgisftw.FWA_IndexPoint(1199447.0, 383113.0, 3005) i
  JOIN whse_basemapping.fwa_stream_networks_sp s ON s.linear_feature_id = i.linear_feature_id
) as result;

-- the measure is the stream geometry's m, which here is 2 mm from
-- downstream_route_measure + fraction * length_metre
SELECT (
  SELECT abs(i.downstream_route_measure
    - ST_InterpolatePoint(s.geom, ST_SetSRID(ST_MakePoint(804254.4, 1591269.4), 3005))) < 1e-9
  FROM postgisftw.FWA_IndexPoint(804254.4, 1591269.4, 3005) i
  JOIN whse_basemapping.fwa_stream_networks_sp s ON s.linear_feature_id = i.linear_feature_id
) as result;

-- the point FWA_LocateAlong returns for the measure is the point returned, at the
-- 08KD006 vertex and at a stream's head (measure = its top segment's end)
SELECT (
  SELECT ST_Distance(i.geom, l.geom) < 1e-6
  FROM postgisftw.FWA_IndexPoint(-122.373062134, 54.0455589294, 4326, 5000, 5) i,
  FWA_LocateAlong(i.blue_line_key, i.downstream_route_measure) l
  WHERE i.blue_line_key = 356360570
) as result;

SELECT (
  SELECT ST_Distance(i.geom, l.geom) < 1e-6
  FROM postgisftw.FWA_IndexPoint(1298386.2, 743436.2, 3005) i,
  FWA_LocateAlong(i.blue_line_key, i.downstream_route_measure) l
  WHERE i.blue_line_key = 356067104
) as result;

-- include_disconnected => false: Teanook Lake (a 999 stream) is excluded and the
-- next streams are still returned
SELECT count(*) = 2 AND count(*) FILTER (WHERE blue_line_key = 354094227) = 0 as result
FROM postgisftw.FWA_IndexPoint(1184392, 389012, 3005, 300, 3, false, true);

-- include_null_localcodes => false applies before the nearest segment of each
-- stream is chosen: this stream's nearest segment has no local code, and the
-- stream is returned on its nearest segment that has one
SELECT (
  SELECT localcode_ltree IS NULL
  FROM postgisftw.FWA_IndexPoint(1092971.0, 1530851.3, 3005, 5000, 5)
  WHERE blue_line_key = 359010948
)
AND (
  SELECT linear_feature_id
  FROM postgisftw.FWA_IndexPoint(1092971.0, 1530851.3, 3005, 5000, 5, true, false)
  WHERE blue_line_key = 359010948
) = 44074564 as result;

-- the defaults keep the unfiltered result (and it is not empty)
SELECT EXISTS (
  SELECT 1 FROM FWA_IndexPoint(ST_SetSRID(ST_MakePoint(1092971.0, 1530851.3), 3005), 5000, 5)
) AND NOT EXISTS (
  (SELECT linear_feature_id, downstream_route_measure, ST_AsBinary(geom)
   FROM FWA_IndexPoint(ST_SetSRID(ST_MakePoint(1092971.0, 1530851.3), 3005), 5000, 5)
   EXCEPT
   SELECT linear_feature_id, downstream_route_measure, ST_AsBinary(geom)
   FROM FWA_IndexPoint(ST_SetSRID(ST_MakePoint(1092971.0, 1530851.3), 3005), 5000, 5, true, true))
  UNION ALL
  (SELECT linear_feature_id, downstream_route_measure, ST_AsBinary(geom)
   FROM FWA_IndexPoint(ST_SetSRID(ST_MakePoint(1092971.0, 1530851.3), 3005), 5000, 5, true, true)
   EXCEPT
   SELECT linear_feature_id, downstream_route_measure, ST_AsBinary(geom)
   FROM FWA_IndexPoint(ST_SetSRID(ST_MakePoint(1092971.0, 1530851.3), 3005), 5000, 5))
) as result;

-- one-argument and named-argument calls
SELECT (
  SELECT gnis_name = 'Bowker Creek'
  FROM FWA_IndexPoint(ST_SetSRID(ST_MakePoint(1199447.0, 383113.0), 3005))
) as result;

SELECT count(*) = 2 as result
FROM FWA_IndexPoint(ST_SetSRID(ST_MakePoint(1184392, 389012), 3005), 300, 3, include_disconnected => false);

-- a MultiPoint input (bcdata loads points as multi) gives the same measure and
-- point as its Point. Select the measure and geom: the function is inlined, and
-- an output column the query does not read is never computed.
SELECT (
  SELECT m.downstream_route_measure = p.downstream_route_measure
    AND ST_Equals(m.geom, p.geom) AND m.linear_feature_id = p.linear_feature_id
  FROM FWA_IndexPoint(ST_Multi(ST_SetSRID(ST_MakePoint(1199447.0, 383113.0), 3005))) m,
  FWA_IndexPoint(ST_SetSRID(ST_MakePoint(1199447.0, 383113.0), 3005)) p
) as result;

-- a point on the boundary between two watershed groups (a BULK vertex) returns
-- one row per stream, rather than failing on the group lookup
SELECT (
  SELECT count(*) = 1 AND bool_and(bc_ind)
  FROM FWA_IndexPoint(ST_SetSRID(ST_MakePoint(991961.3809999991, 1065362.4670000002), 3005))
) as result;

-- the measure FWA_IndexPoint returns at a stream's head (20 m past the head of
-- blue line 356014037; here equal to the top segment's upstream_route_measure)
-- is accepted by the functions that take a measure
SELECT (
  SELECT count(*) = 1
  FROM FWA_IndexPoint(ST_SetSRID(ST_MakePoint(1002014.9, 1018388.1), 3005)) i,
  FWA_WatershedStream(i.blue_line_key, i.downstream_route_measure) w
) as result;

SELECT (
  SELECT count(*) > 0
  FROM FWA_IndexPoint(ST_SetSRID(ST_MakePoint(1002014.9, 1018388.1), 3005)) i,
  FWA_WatershedHex(i.blue_line_key, i.downstream_route_measure) w
) as result;

SELECT (
  SELECT count(*) = 1
  FROM FWA_IndexPoint(ST_SetSRID(ST_MakePoint(1002014.9, 1018388.1), 3005)) i,
  FWA_LocateAlong(i.blue_line_key, i.downstream_route_measure) l
) as result;

-- at a stream's head the measure (the geometry's last m) can exceed
-- downstream_route_measure + length_metre; FWA_SliceWatershedAtPoint, which
-- FWA_WatershedAtMeasure calls on rivers, takes it rather than failing
SELECT (
  SELECT count(*) >= 0
  FROM FWA_SliceWatershedAtPoint(360228283, 1255.8763650310827)
) as result;
