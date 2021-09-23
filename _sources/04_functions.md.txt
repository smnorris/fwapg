# Function reference

## FWA_IndexPoint

### Synopsis

```sql
FWA_IndexPoint(
    point geometry(Point, 3005),
    tolerance float DEFAULT 5000,
    num_features integer DEFAULT 1
)

FWA_IndexPoint(
    x float,
    y float,
    srid integer,
    tolerance float DEFAULT 5000,
    num_features integer DEFAULT 1
)
```

### Description

Snaps a point to the stream network. Provided a point (as either a BC Albers point geometry or (`x, y, srid`), return a table containing the point geometry of the closest point on the FWA stream network to the given point, plus additional attributes from the matched stream:

| field                     | type                  | description                                 |
| :-------------------------| --------------------- |-------------------------------------------- |
| `linear_feature_id`       | bigint                | unique identifier of matched stream         |
| `gnis_name`               | text                  | stream name of matched stream               |
| `wscode_ltree`            | ltree                 | stream watershed code                       |
| `localcode_ltree`         | ltree                 | stream local watershed code                 |
| `blue_line_key`           | integer               | stream blue line key (route identifier)     |
| `downstream_route_measure`| double precision      | measure value of output point               |
| `distance_to_stream`      | double precision      | distance from input point to output point   |
| `bc_ind`                  | boolean               | Indicates if the source point is in BC      |
| `geom`                    | geometry(Point, 3005) | The closest point on the FWA stream network |

### Examples

Return the closest point on FWA stream network to a point defined by a lat/lon (within default 5000m tolerance):

```sql
SELECT * FROM FWA_IndexPoint(-123.7028, 48.3858, 4326);
```
```
 linear_feature_id |  gnis_name  | wscode_ltree | localcode_ltree | blue_line_key | downstream_route_measure | distance_to_stream | bc_ind |                        geom
-------------------+-------------+--------------+-----------------+---------------+--------------------------+--------------------+--------+----------------------------------------------------
         710513719 | Sooke River | 930.023810   | 930.023810      |     354153927 |        350.2530543284006 |             24.228 | t      | 0101000020BD0B0000D579287B42DC314198937D515C061741
```

Index a set of point geometries, finding up to 10 features within 100m:

```sql
SELECT
  pts.id,
  i.*
FROM (
  VALUES
  ('07EA004', ST_SetSRID(ST_MakePoint(1054676, 1304723), 3005)),
  ('07EA005', ST_SetSRID(ST_MakePoint(1045356, 1348750), 3005)),
  ('07EA007', ST_SetSRID(ST_MakePoint(1066334, 1356262), 3005)),
  ('07EB002', ST_SetSRID(ST_MakePoint(1126747, 1283184), 3005)),
  ('07EC002', ST_SetSRID(ST_MakePoint(1089342, 1214473), 3005))
) AS pts (id, geom)
LEFT JOIN LATERAL
(
  SELECT *
  FROM
  FWA_IndexPoint(geom, 100, 10)
) i on true;
```
```
   id    | linear_feature_id |   gnis_name    |       wscode_ltree       |         localcode_ltree         | blue_line_key | downstream_route_measure | distance_to_stream | bc_ind |                        geom
---------+-------------------+----------------+--------------------------+---------------------------------+---------------+--------------------------+--------------------+--------+----------------------------------------------------
 07EA004 |          68051401 | Ingenika River | 200.948755.992594        | 200.948755.992594.039418        |     359571145 |        6096.256539019577 |             41.319 | t      | 0101000020BD0B00007FFBC4C0C617304173BF3D23BAE83341
 07EA004 |          68051402 |                | 200.948755.992594.042767 | 200.948755.992594.042767        |     359233576 |                        0 |              46.77 | t      | 0101000020BD0B000023DBF9FEB11730413108AC1CB3E83341
 07EA005 |          49095881 | Finlay River   | 200.948755.999851        | 200.948755.999851.137838        |     359569942 |        42909.36746325051 |             47.258 | t      | 0101000020BD0B0000C3F5289C79E62F41508D976E90943441
 07EA007 |          49083226 | Akie River     | 200.948755.999851.088011 | 200.948755.999851.088011.231827 |     359571761 |        29215.40257114563 |             40.442 | t      | 0101000020BD0B000037B9E4F44B4530410DDF6ACEC1B13441
 07EB002 |         161051216 | Ospika River   | 200.948755.951156        | 200.948755.951156.201899        |     359573063 |       29005.449548147713 |             41.647 | t      | 0101000020BD0B0000D7D491C73F3131419708AD7A50943341
 07EC002 |         115033725 | Omineca River  | 200.948755.944288        | 200.948755.944288.110746        |     359571933 |        29317.40902691083 |             95.125 | t      | 0101000020BD0B000054618DD09A9F3041A0D25C29F4873241
```

## FWA_WatershedAtMeasure

### Synopsis

```sql
FWA_WatershedAtMeasure(
    blue_line_key integer,
    downstream_route_measure float
)
```

### Description

Given a point defined by its position on the FWA stream network (`blue_line_key`,`downstream_route_measure`), return a table containing a polygon geometry that defines the point's upstream watershed.

Watershed delineation following this set of rules, in order of descending priority:

1. If the point is within a lake, return everything upstream of the lake's *outflow*
2. If the point is within a polygonal river/canal the fundamental watersheds are
cut across the banks of the river/canal before being included in the aggregation
3. If the point is < 100m downstream from the top of the fundamental
watershed in which it falls, then that fundamental watershed is not included in the aggregation
4. If the point is < 50 m upstream from the bottom of the fundamental
watershed in which it falls, then that watershed is included in the aggregation

For cross-boundary watersheds, the function returns non-BC areas using these data sources:
    + USGS [huc12 watersheds](https://www.usgs.gov/core-science-systems/ngp/national-hydrography/watershed-boundary-dataset?qt-science_support_page_related_con=4#qt-science_support_page_related_con) for USA (WA, ID, MT only)
    + [hydrosheds](https://www.hydrosheds.org) watersheds for other neighbouring jurisdictions

| field                     | type                    | description                                 |
| :-------------------------| ---------------------   |-------------------------------------------- |
| `wscode_ltree`            | ltree                   | watershed code of the source point          |
| `localcode_ltree`         | ltree                   | local watershed code of the source point    |
| `area_ha`                 | numeric                 | area of output geometry, hectares           |
| `refine_method`           | text                    | how the watershed was processed / what further processing may be required |
| `geom`                    | geometry(Polygon, 3005) | a polygon representing the watershed contributing to the input location |

The `refine_method` field in the output table has several possible values:

| value                     | description                                 |
| :-------------------------|-------------------------------------------- |
| `CUT`                     | Input point falls in a river/canal, output geometry is cut across the banks of the river/canal
| `DEM`                     | Input point falls on a linear stream >50m upstream from outlet of input watershed and >100m downstream from top of watershed, further processing of the fundamental watershed in which the point lies with the DEM would be valuable to improve the output watershed. This is functionally equivalent to the `DROP` value
| `DROP`                    | Input point falls on a linear stream and is <=100m downstream from the top of the fundamental watershed in which it lies - this fundamental watershed is not included in output geometry
| `KEEP`                    | Input point falls on a linear stream and is <=50m upstream from the outlet of the fundamental watershed in which it lies - this fundamental watershed is entirely retained in the output geometry
| `LAKE`                    | Input point falls within a lake/reservoir - watershed returned includes everything upstream of the outlet of the lake/reservoir


### Examples

1. Extract the geometry of the watershed upstream of the Cowichan River at Hwy 19:

    ```sql
    SELECT geom FROM FWA_WatershedAtMeasure(354155148, 49129.75);
    ```

    ![watershed](images/watershed5.png)

2. Extract the watershed upstream of Chilliwack Lake:

    ```sql
    WITH indexed_pt AS
    (
      SELECT
        i.*
      FROM
      (
        -- find a point in the lake
        SELECT st_pointonsurface(geom) AS geom
        FROM whse_basemapping.fwa_lakes_poly
        WHERE gnis_name_1 = 'Chilliwack Lake'
      ) AS pt
      LEFT JOIN LATERAL
      (
        SELECT *
        FROM
        FWA_IndexPoint(geom, 100) -- index the point in the lake to the nearest FWA stream
      ) i on true
    )

    SELECT *
    FROM FWA_WatershedAtMeasure(
      (SELECT blue_line_key from indexed_pt),
      (SELECT downstream_route_measure from indexed_pt)
    );
    ```

    ```
       wscode_ltree    |     localcode_ltree      | area_ha  | refine_method  | geom
    -------------------+--------------------------+----------+----------------+-----
     100.064535.057628 | 100.064535.057628.634957 | 33478.28 | LAKE           |
    ```

    Mapped, the geometry looks like this - FWA heights of land in BC, HUC12 heights of land in the USA:

    ![watershed](images/watershed6.png)
