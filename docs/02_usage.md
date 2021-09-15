# Usage

This document presumes a working familiarity with FWA data and PostgreSQL/PostGIS.


## Upstream / Downstream

The most typical use of `fwapg` is to answer the question - "what is upstream or downstream of these points of interest"?

### Reference a single point to stream network

If you simply have a single point location as `X,Y` (plus coordinate system identifier), use the function `FWA_IndexPoint`.


For example, to find the nearest point on the FWA stream network to location `-123.7028, 48.3858`:

    SELECT *
    FROM FWA_IndexPoint(-123.7028, 48.3858, 4326);

This snaps the input point to the closest stream - it returns information about the closest stream, minimum distance from input point to the stream, and the geometry of the closest point on the stream to the point:

    linear_feature_id |  gnis_name  | wscode_ltree | localcode_ltree | blue_line_key | downstream_route_measure | distance_to_stream | bc_ind | geom
    -------------------+-------------+--------------+-----------------+---------------+--------------------------+--------------------+--------+
             710513719 | Sooke River | 930.023810   | 930.023810      |     354153927 |        350.2530543284006 | 24.228412194958068 | t      |

This function is available via the `fwapg` [feature service](https://www.hillcrestgeo.ca/fwapg/functions/fwa_indexpoint.html) - you can experiment with it [directly](https://www.hillcrestgeo.ca/fwapg/functions/fwa_indexpoint/items.html?x=-123.7028&y=48.3858&srid=4326) without having to install fwapg (zoom out to see the context in the default web map).


### Reference many points to stream network

Referencing a single point is handy but generally it is necessary to join/snap an entire table of point geometries to FWA streams.

```
-- extract subset for testing
WITH src_pts AS
(
  SELECT *
  FROM whse_fish.pscis_assessment_svw
  LIMIT 10
),

-- find nearest neighbouring streams within given distance of input features
candidates AS
(
  SELECT
    pt.stream_crossing_id,
    nn.linear_feature_id,
    nn.distance_to_stream,
    nn.blue_line_key,
  CEIL(
    GREATEST(nn.downstream_route_measure,
      FLOOR(
        LEAST(nn.upstream_route_measure,
          (ST_LineLocatePoint(nn.geom, ST_ClosestPoint(pt.geom, pt.geom)) * nn.length_metre) + nn.downstream_route_measure
  )))) as downstream_route_measure
  FROM src_pts as pt
  CROSS JOIN LATERAL
  (SELECT
     str.linear_feature_id,
     ST_Distance(str.geom, pt.geom) as distance_to_stream,
     str.blue_line_key,
     str.downstream_route_measure,
     str.upstream_route_measure,
     str.length_metre,
     str.geom
    FROM whse_basemapping.fwa_stream_networks_sp AS str
    -- use lines that have valid local code, are in the network, and within BC
    WHERE str.localcode_ltree IS NOT NULL
      AND NOT str.wscode_ltree <@ '999'
      AND edge_type != 6010
    ORDER BY str.geom <-> pt.geom
    LIMIT 10) as nn                 -- retain up to 10 potential matches
  WHERE nn.distance_to_stream < 50  -- within 50m
)

-- get only the nearest distinct result per blue line key
-- (more than one geometry from the same stream could be near the point)
SELECT DISTINCT ON (stream_crossing_id, blue_line_key)
  c.stream_crossing_id,
  c.linear_feature_id,
  c.distance_to_stream,
  str.blue_line_key,
  c.downstream_route_measure,
  FWA_LocateAlong(c.blue_line_key::integer, c.downstream_route_measure::float) as geom
FROM candidates c
INNER JOIN whse_basemapping.fwa_stream_networks_sp str
ON c.linear_feature_id = str.linear_feature_id
INNER JOIN src_pts
ON c.stream_crossing_id = src_pts.stream_crossing_id
ORDER BY c.stream_crossing_id, str.blue_line_key, c.distance_to_stream;
```

### Check results

### Query downstream

### Query upstream

### Generate watershed
