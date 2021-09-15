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


### Check results

### Query downstream

### Query upstream

### Generate watershed
