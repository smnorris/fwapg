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
             710513719 | Sooke River | 930.023810   | 930.023810      |     354153927 |        350.2530543284006 | 24.228 | t      |

This function is available via the `fwapg` [feature service](https://www.hillcrestgeo.ca/fwapg/functions/fwa_indexpoint.html) - you can experiment with it [directly](https://www.hillcrestgeo.ca/fwapg/functions/fwa_indexpoint/items.html?x=-123.7028&y=48.3858&srid=4326) without having to install fwapg (zoom out to see the context in the default web map).


### Reference many points to stream network

Referencing a single point is handy but generally it is necessary to join/snap an entire table of point geometries to FWA streams. Because `FWA_IndexPoint` is a table returning function this is not quite as intuitive as it might be, but by using a `LATERAL` join we can run the function on each of a set of points. Note that `FWA_IndexPoint` accepts point geometries directly, but only as BC Albers (EPSG:3005):

```

SELECT
  pts.stream_crossing_id,
  blue_line_key,
  downstream_route_measure,
  distance_to_stream
FROM
(
  SELECT stream_crossing_id, geom
  FROM whse_fish.pscis_assessment_svw
  LIMIT 10
) pts
CROSS JOIN LATERAL
(
  SELECT *
  FROM
  FWA_IndexPoint(geom, 100, 10)
) i;


 stream_crossing_id | blue_line_key | downstream_route_measure | distance_to_stream
--------------------+---------------+--------------------------+--------------------
                  1 |     360884282 |        866.1525308411424 |              6.946
                  1 |     360825762 |                        0 |             94.804
                  2 |     360866620 |        36032.59046348071 |              3.703
                  3 |     360844576 |        639.6525834806826 |             12.872
                  3 |     360490551 |        2.699977324188454 |             24.584
                  3 |     360831182 |       29.035744096755185 |              72.04
                  4 |     360844794 |        1992.315839723944 |             45.615
                  5 |     360618851 |       3004.2644276369833 |             17.815
                  6 |     360680835 |        1807.292852891016 |              4.181
                  6 |     360499825 |                        0 |             50.158
                  6 |     360764713 |        413.7116699105115 |             85.648
                  7 |     360762345 |       1178.9361755598632 |              28.83
                  8 |     360611896 |       2001.5442239776783 |              3.576
                 10 |     360845663 |        735.2729701743625 |             20.199
(14 rows)
```

### Check results

### Query downstream

### Query upstream

### Generate watershed
