# Value added table/view reference

## fwa_approx_borders

Lines of latitude / longitude for 49N, 60N, -120W. These are used by fwapg for finding cross-border streams

| Column | Type | Description |
|--------|------|-------------|
| `approx_border_id` | `integer` | Unique identifer |
| `border` | `text` | A code identifying the border (USA49, YTNWT_60, AB_120) |
| `geom` | `geometry(LineString,3005)` | Geometry of the border line |

## fwa_assessment_watersheds_lut

Some workflows require relating `fwa_assessment_watersheds_poly` to fundamental watersheds. There are no existing keys in the data that maintain this link - the query requires a resource intensive spatial function.  Rather than running a spatial query every time, this lookup is provided.

| Column | Type | Description |
|--------|------|-------------|
| watershed_feature_id | integer |           |
| assmnt_watershed_id  | integer |           |

## fwa_assessment_watersheds_streams_lut

Some workflows require relating `fwa_assessment_watersheds_poly` to stream segments. There are no existing keys in the data that maintain this link - the query requires a resource intensive spatial function.  Rather than running a spatial query every time, this lookup is provided.

| Column | Type | Description |
|--------|------|-------------|
| linear_feature_id | integer |           |
| assmnt_watershed_id  | integer |           |

## fwa_basins_poly

Large BC watersheds consisting of at least 2-3 watershed groups, used by fwapg for watershed pre-aggregation

| Column | Type | Description |
|--------|------|-------------|
| `basin_id` | `integer` | Basin unique identifier |
| `basin_name` | `text` | Basin name, eg Thompson River |
| `wscode_ltree` | `ltree` | The watershed code associated with the stream at the outlet of the basin |
| `localcode_ltree` | `ltree` | The local watershed code associated with the stream at the outlet of the basin |
| `geom` | `geometry(Polygon,3005)` | Geometry of the basin |

## fwa_bcboundary

Boundary of BC as defined by FWA - used by FWA_WatershedAtMeasure()

| Column | Type | Description |
|--------|------|-------------|
| `bcboundary_id` | `integer` | Boundary polygon id |
| `geom` | `geometry(Polygon,3005)` | Boundary geometry |

## fwa_named_streams

Named streams of BC, aggregated per watershed group and simplified using a 25m tolerance (primarily for mapping use)

| Column | Type | Description |
|--------|------|-------------|
| `named_streams_id` | `integer` | Named stream unique identifier |
| `gnis_name` | `text` | The BCGNIS (BC Geographical Names Information System) name associated with the stream |
| `blue_line_key` | `bigint` | The blue line key of the named stream, see FWA documentation for blue_line_key description |
| `stream_order` | `integer` | The maximum stream order associated with the stream name |
| `watershed_group_code` | `text` | The watershed group code associated with the named stream |
| `geom` | `geometry(MultiLineString,3005)` | The geometry of the named stream, an aggregation of the source features and simpified by 25m |


## whse_basemapping.fwa_streams

FWA stream networks plus value-added attributes

| Column | Type | Description |
|--------|------|-------------|
| `linear_feature_id` | `bigint` | See FWA documentation |
| `edge_type` | `integer` | See FWA documentation |
| `blue_line_key` | `integer` | See FWA documentation |
| `watershed_key` | `integer` | See FWA documentation |
| `wscode` | `ltree` | FWA watershed code as postgres ltree type, with trailing -000000 strings removed |
| `localcode` | `ltree` | FWA local watershed code as postgres ltree type, with trailing -000000 strings removed |
| `watershed_group_code` | `character varying(4)` | See FWA documentation |
| `downstream_route_measure` | `double precision` | See FWA documentation |
| `upstream_route_measure` | `double precision` | See FWA documentation |
| `length_metre` | `double precision` | See FWA documentation |
| `waterbody_key` | `integer` | See FWA documentation |
| `gnis_name` | `character varying(80)` | See FWA documentation |
| `stream_order` | `integer` | See FWA documentation |
| `stream_magnitude` | `integer` | See FWA documentation |
| `feature_code` | `character varying(10)` | See FWA documentation |
| `gradient` | `double precision` | See FWA documentation |
| `left_right_tributary` | `character varying(7)` | See FWA documentation |
| `stream_order_parent` | `integer` | Stream order of parent stream at confluence with stream having `blue_line_key` of the stream segment |
| `stream_order_max` | `integer` | Maxiumum order of the stream with equivalent `blue_line_key` as given segment) |
| `upstream_area_ha` | `double precision` | Area (ha) upstream of the stream segment (including all fundamental watersheds with equivalent watershed code) |
| `map_upstream` | `integer` | Area weighted average mean annual precipitation upstream of the stream segment, source ClimateBC |
| `channel_width` | `double precision` | Channel width of the stream segment in metres, with source as per channel_width_source |
| `channel_width_source` | `text` | Data source for channel_width at given segment, with values (FIELD_MEASURMENT, FWA_RIVERS_POLY, MODELLED). FIELD_MEASUREMENT is derived from PSCIS and FISS data, MODELLED is taken from Thorley et al, 2021 |
| `mad_m3s` | `double precision` | Modelled mean annual discharge at the stream segment (Pacific Climate Impacts Consortium, University of Victoria, (January 2020) VIC-GL BCCAQ CMIP5: Gridded Hydrologic Model Output) |
| `geom` | `geometry(LineStringZM,3005)` |  |

## fwa_streams_watersheds_lut

A convenience lookup for quickly relating streams and fundamental watersheds

| Column | Type | Description |
|--------|------|-------------|
| `linear_feature_id` | `bigint` | FWA stream segment unique identifier |
| `watershed_feature_id` | `integer` | FWA fundamental watershed unique identifer |


## fwa_waterbodies

All FWA waterbodies in one table for convenience (lakes, wetlands, rivers, manmade waterbodies, glaciers). 
Note that this table is meant for connectivity purposes only, only features connected to the network are included (waterbodies with watershed code  `999.999999` are excluded). For column descriptions see FWA docs for the various waterbody tables.

| Column | Type | Description |
|--------|------|-------------|
| `waterbody_key` | `integer` |  |
| `waterbody_type` | `character varying(1)` |  |
| `blue_line_key` | `integer` |  |
| `downstream_route_measure` | `double precision` |  |
| `wscode_ltree` | `ltree` |  |
| `localcode_ltree` | `ltree` |  |


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


## psf.pse_conservation_units_streams

Lookup relating Pacific Salmon Explorer Conservation Units to FWA streams

|      Column       |  Type   | Description |
--------------------|---------|-----------  |
| linear_feature_id | bigint  |             |  
| cuid              | integer |             |  


For example, to find length of all streams associated with CU 289 (Morice) and CU 287 (Bulkley):

```
  SELECT
    cu.cuid,
    round((sum(st_length(s.geom)) / 1000)::numeric, 2) AS length_km
  FROM whse_basemapping.fwa_streams_vw s
  JOIN psf.pse_conservation_units_streams cu USING (linear_feature_id)
  WHERE cu.cuid IN (289, 287)
  GROUP BY cu.cuid;

 cuid | length_km
------+-----------
  287 |   9371.21
  289 |  11534.82

```  