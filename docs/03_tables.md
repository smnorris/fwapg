# Table reference

## whse_basemapping.fwa_approx_borders

Lines of latitude / longitude for 49N, 60N, -120W. These are used by fwapg for finding cross-border streams

| Column | Type | Description |
|--------|------|-------------|
| `approx_border_id` | `integer` | Unique identifer |
| `border` | `text` | A code identifying the border (USA49, YTNWT_60, AB_120) |
| `geom` | `geometry(LineString,3005)` | Geometry of the border line |

## whse_basemapping.fwa_basins_poly

Large BC waterhseds consisting of at least 2-3 watershed groups, used by fwapg for watershed pre-aggregation

| Column | Type | Description |
|--------|------|-------------|
| `basin_id` | `integer` | Basin unique identifier |
| `basin_name` | `text` | Basin name, eg Thompson River |
| `wscode_ltree` | `ltree` | The watershed code associated with the stream at the outlet of the basin |
| `localcode_ltree` | `ltree` | The local watershed code associated with the stream at the outlet of the basin |
| `geom` | `geometry(Polygon,3005)` | Geometry of the basin |

## whse_basemapping.fwa_bcboundary

Boundary of BC as defined by FWA - used by FWA_WatershedAtMeasure()

| Column | Type | Description |
|--------|------|-------------|
| `bcboundary_id` | `integer` | Boundary polygon id |
| `geom` | `geometry(Polygon,3005)` | Boundary geometry |

## whse_basemapping.fwa_named_streams

Named streams of BC, aggregated per watershed group and simplified using a 25m tolerance (primarily for mapping use)

| Column | Type | Description |
|--------|------|-------------|
| `named_streams_id` | `integer` | Named stream unique identifier |
| `gnis_name` | `text` | The BCGNIS (BC Geographical Names Information System) name associated with the stream |
| `blue_line_key` | `bigint` | The blue line key of the named stream, see FWA documentation for blue_line_key description |
| `stream_order` | `integer` | The maximum stream order associated with the stream name |
| `watershed_group_code` | `text` | The watershed group code associated with the named stream |
| `geom` | `geometry(MultiLineString,3005)` | The geometry of the named stream, an aggregation of the source features and simpified by 25m |

## whse_basemapping.fwa_streams_watersheds_lut

A convenience lookup for quickly relating streams and fundamental watersheds

| Column | Type | Description |
|--------|------|-------------|
| `linear_feature_id` | `bigint` | FWA stream segment unique identifier |
| `watershed_feature_id` | `integer` | FWA fundamental watershed unique identifer |

## whse_basemapping.fwa_waterbodies

All FWA waterbodies in one table for convenience (lakes, wetlands, rivers, manmade waterbodies, glaciers). See FWA docs for column descriptions.

| Column | Type | Description |
|--------|------|-------------|
| `waterbody_key` | `integer` |  |
| `waterbody_type` | `character varying(1)` |  |
| `blue_line_key` | `integer` |  |
| `downstream_route_measure` | `double precision` |  |
| `wscode_ltree` | `ltree` |  |
| `localcode_ltree` | `ltree` |  |


## fwa_watersheds_upstream_area

Area upstream (ha) for all fundamental watersheds as a lookup table. Area *includes* the area of the fundamental watershed indicated by the id.

**NOTE** - output currently includes area upstream **WITHIN BC ONLY**, this will not be accurate in watersheds that have contributing drainage outside of BC!

When working with watersheds, join to this lookup directly via `watershed_feature_id`.
When working with streams, relate the streams to watersheds via the lookup `fwa_streams_watersheds_lut`:

    SELECT
      s.linear_feature_id,
      ua.upstream_area_ha
    FROM whse_basemapping.fwa_stream_networks_sp s
    LEFT OUTER JOIN whse_basemapping.fwa_streams_watersheds_lut l
    ON s.linear_feature_id = l.linear_feature_id
    INNER JOIN whse_basemapping.fwa_watersheds_upstream_area ua
    ON l.watershed_feature_id = ua.watershed_feature_id

| Column | Type | Description |
|--------|------|-------------|
| watershed_feature_id | integer          | |
| upstream_area_ha     | double precision | |

## fwa_waterbodies_upstream_area

A lookup storing area of lake/reservoir/wetland upstream of individual stream segments.
Note that this table differs from `fwa_watersheds_upstream_area` noted above - we use streams as the lookup base rather than watersheds because waterbodies can be nested within fundamental watersheds.

**NOTE** - output currently includes area upstream **WITHIN BC ONLY**, this will not be accurate in watersheds that have contributing drainage outside of BC!

| Column | Type | Description |
|--------|------|-------------|
| linear_feature_id     | bigint           |           |
| upstream_lake_ha      | double precision |           |
| upstream_reservoir_ha | double precision |           |
| upstream_wetland_ha   | double precision |           |

## Assessment watersheds lookups

Some workflows require relating `fwa_assessment_watersheds_poly` to stream segments and fundamental watersheds. There are no existing keys in the data that maintain this link - the query requires a resource intensive spatial function.  Rather than running a spatial query every time, this lookup is provided.

| Column | Type | Description |
|--------|------|-------------|
| watershed_feature_id | integer |           |
| assmnt_watershed_id  | integer |           |
| watershed_group_code | text    |           |
| watershed_group_id   | integer |           |
