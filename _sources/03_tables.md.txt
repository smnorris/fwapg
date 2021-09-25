# Table reference

## whse_basemapping.fwa_approx_borders

Lines for 49N, 60N, -120W - used by fwapg for finding cross-border streams

| Column | Type | Description |
|--------|------|-------------|
| `approx_border_id` | `integer` |  |
| `border` | `text` |  |
| `geom` | `geometry(LineString,3005)` |  |

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



| Column | Type | Description |
|--------|------|-------------|
| `linear_feature_id` | `bigint` |  |
| `watershed_feature_id` | `integer` |  |

## whse_basemapping.fwa_waterbodies

All FWA waterbodies in one table for convenience (lakes, wetlands, rivers, manmade waterbodies, glaciers). See FWA docs for column descriptions

| Column | Type | Description |
|--------|------|-------------|
| `waterbody_key` | `integer` |  |
| `waterbody_type` | `character varying(1)` |  |
| `blue_line_key` | `integer` |  |
| `downstream_route_measure` | `double precision` |  |
| `wscode_ltree` | `ltree` |  |
| `localcode_ltree` | `ltree` |  |

## whse_basemapping.fwa_watershed_groups_subdivided

Subdivided watershed groups polygons, use for faster point in poly queries

| Column | Type | Description |
|--------|------|-------------|
| `fwa_watershed_groups_subdivided_id` | `integer` |  |
| `watershed_group_id` | `integer` |  |
| `watershed_group_code` | `text` |  |
| `geom` | `geometry(Polygon,3005)` |  |

