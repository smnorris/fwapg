-- Aggregate and slice watershed polygons on and adjacent to double line
-- rivers/canals, return portion of the watersheds upstream of provided point
-- (in form of blue_line_key, downstream_route_measure)

-- To do the slicing, xtract the watersheds on the waterbody and on the banks
-- of the waterbody adjacent to the point.
-- Then cut these polys with a blade spanning between the input point and
-- the closest points on the opposite edges of the bank/adjacent watershed poly

CREATE OR REPLACE FUNCTION FWA_SliceWatershedAtPoint(blkey integer, meas float)

RETURNS TABLE(wsds integer[], geom geometry)  AS $$

-- Generate a point from the privided blue line key and measure
WITH ref_point AS
(SELECT
  s.linear_feature_id,
  s.blue_line_key,
  s.downstream_route_measure,
  s.wscode_ltree,
  s.localcode_ltree,
  s.waterbody_key,
  ST_LineInterpolatePoint(
    (ST_Dump(s.geom)).geom,
    ROUND(CAST((meas - s.downstream_route_measure) / s.length_metre AS NUMERIC), 5)
        ) as geom
FROM whse_basemapping.fwa_stream_networks_sp s
WHERE s.blue_line_key = blkey
AND s.downstream_route_measure <= meas
ORDER BY s.downstream_route_measure desc
LIMIT 1),


-- Find watershed polys that compose the waterbody on which the point lies.
-- This is not a simple case of extracting watersheds with the equivalent
-- waterbody key, waterbodies may terminate near a site, we may have to
-- include several watershed polygons.
-- Therefore, here we will first select watersheds with a matching wb key
-- (within 100m) and then in the next WITH CTE, widen the selection to
-- any watersheds with that touch the waterbody in which the point lies.
wsds_river_prelim AS
(SELECT
  wsd.watershed_feature_id,
  wsd.waterbody_key,
  wsd.geom
 FROM whse_basemapping.fwa_watersheds_poly wsd
 INNER JOIN ref_point pt
  ON (wsd.waterbody_key = pt.waterbody_key
     AND ST_DWithin(wsd.geom, pt.geom, 100))
),

-- Add intersecting waterbodies if present, combining with results from above
wsds_river AS
(SELECT DISTINCT watershed_feature_id, waterbody_key, geom
FROM (
(SELECT wsd.watershed_feature_id, wsd.waterbody_key, wsd.geom
FROM whse_basemapping.fwa_watersheds_poly wsd
INNER JOIN wsds_river_prelim p ON ST_Intersects(wsd.geom, p.geom)
WHERE wsd.watershed_feature_id != p.watershed_feature_id
AND wsd.waterbody_key != 0
UNION ALL
SELECT * FROM wsds_river_prelim)
) as foo
) ,


-- Find the watershed polygons that are on the banks of wsds_river, returns all
-- watersheds that share an edge with the river (or lake) polys
wsds_adjacent AS
(SELECT
    r.watershed_feature_id as riv_id,
  wsd.watershed_feature_id,
  wsd.geom,
  ST_Distance(s.geom, wsd.geom) as dist_to_site
FROM whse_basemapping.fwa_watersheds_poly wsd
INNER JOIN wsds_river r
ON (r.geom && wsd.geom AND ST_Relate(r.geom, wsd.geom, '****1****'))
INNER JOIN ref_point s ON ST_DWithin(s.geom, r.geom, 5)
LEFT OUTER JOIN whse_basemapping.fwa_lakes_poly lk
ON wsd.waterbody_key = lk.waterbody_key
LEFT OUTER JOIN whse_basemapping.fwa_rivers_poly riv
ON wsd.waterbody_key = riv.waterbody_key
LEFT OUTER JOIN whse_basemapping.fwa_manmade_waterbodies_poly mm
ON wsd.waterbody_key = mm.waterbody_key
WHERE lk.waterbody_key IS NULL AND riv.waterbody_key IS NULL AND mm.waterbody_key IS NULL
AND r.watershed_feature_id != wsd.watershed_feature_id
AND wsd.watershed_feature_id NOT IN (SELECT watershed_feature_id FROM wsds_river)),

-- From wsds_adjacent, find just the nearest wsd poly to the point (on each
-- bank) - there should always be just two results
wsds_adjacent_nearest AS
(SELECT DISTINCT ON (riv_id) riv_id, watershed_feature_id, dist_to_site, geom
FROM wsds_adjacent
ORDER BY riv_id, dist_to_site),

-- Extract the (valid) exterior ring from wsds_adjacent_nearest and retain
-- only the portion that doesn't intersect with the river polys -
-- the outside edges
edges AS (
  SELECT
  w_adj.watershed_feature_id,
  ST_Difference(
    ST_ExteriorRing(
      ST_MakeValid(
        (ST_Dump(w_adj.geom)).geom
      )
    ),
    w_riv.geom
  ) as geom
  FROM wsds_adjacent_nearest w_adj,
(SELECT ST_Union(geom) as geom FROM wsds_river) as w_riv),

-- build all possible blades because the shortest may not work
-- the shortest edge may cross the waterbody before getting to the site,
-- resulting in an invalid blade
all_ends AS (
  SELECT
    row_number() over() AS id,
    e.watershed_feature_id,
    (ST_DumpPoints(e.geom)).geom as geom_end,
    stn.blue_line_key,
    stn.geom as geom_stn
  FROM edges e, ref_point stn
),

-- build all possible blades to see which ones don't cross the river
all_blade_edges AS (
  SELECT
    e.id,
    e.blue_line_key,
    ST_Makeline(geom_end, geom_stn) as geom
  FROM all_ends e),

-- buffer the stream for use below, the buffer ensures that intersections occur,
-- otherwise precision errors may occur when intersecting the point with the line end
stream_buff AS (
SELECT ST_Union(ST_Buffer(ST_LineMerge(s.geom), .01)) as geom
FROM whse_basemapping.fwa_stream_networks_sp s
INNER JOIN ref_point p ON s.blue_line_key = p.blue_line_key
),

-- find the shortest of the blades that do not cross the river
shortest_valid_edges AS (
SELECT DISTINCT ON (id)
    e.id,
    ST_Length(e.geom) AS length,
    e.geom
  FROM all_blade_edges e
  INNER JOIN stream_buff s ON ST_Intersects(e.geom, s.geom)
  AND ST_GeometryType(ST_Intersection(e.geom, s.geom)) = 'ST_LineString'
  ORDER BY id, length
),

-- Now we can construct a valid blade.
-- One of the lines has to be flipped for the line to build properly
blade AS
(SELECT
  1 as id,
  ST_LineMerge(ST_Collect(geom)) as geom
FROM (
  SELECT
    id,
    ST_Reverse(geom) as geom
  FROM shortest_valid_edges
  WHERE id = 1
  UNION ALL
  SELECT id, geom
  FROM shortest_valid_edges
  WHERE id = 2) as flipped
),

-- Aggregate the watersheds extracted above (river and nearest adjacent) into
-- a single poly for cutting. Insert other nearby waterbodies in case we are
-- missing part of the river when sharp angles get involved
to_split AS
(
SELECT array_agg(watershed_feature_id) as wsds, (ST_Dump(ST_Union(geom))).geom AS geom
FROM
  (SELECT watershed_feature_id, geom FROM wsds_adjacent_nearest
   UNION ALL
   SELECT watershed_feature_id, geom FROM wsds_river
   UNION ALL
   SELECT wsd.watershed_feature_id, wsd.geom FROM whse_basemapping.fwa_watersheds_poly wsd
   INNER JOIN ref_point pt
   ON ST_DWithin(wsd.geom, pt.geom, 100)
   WHERE wsd.waterbody_key != 0) AS bar
)

-- Cut the aggregated watershed poly
SELECT
  wsds,
  ST_Multi(cut.geom) AS geom
FROM
  (SELECT
    wsds,
    (ST_Dump(ST_Split(ST_Snap(w.geom, b.geom, .001), b.geom))).geom
   FROM to_split w, blade b
   ) AS cut
INNER JOIN
(SELECT
   str.geom
 FROM whse_basemapping.fwa_stream_networks_sp str
 INNER JOIN ref_point p
 ON str.blue_line_key = p.blue_line_key
 AND str.downstream_route_measure > p.downstream_route_measure
 ORDER BY str. downstream_route_measure asc
 LIMIT 1
) stream
ON st_intersects(cut.geom, stream.geom);



$$
language 'sql' immutable strict parallel safe;
