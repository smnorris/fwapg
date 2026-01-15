# Mean annual precipitation 

Mean annual precipitation (MAP) referenced to FWA watersheds and streams

## Method

1. Overlay ClimateBC MAP raster with fundamental watersheds, deriving MAP for each fundamental watershed
2. Overlay `climr` derived MAP raster with transboundary watersheds, deriving MAP for each transboundary watershed
3. Calculate average (area-weighted) upstream MAP for each distinct watershed code / local code combination 

The output table can be joined to streams or points on the FWA watershed network.

## Requirements

Raster processing is done with `rasterstats`:

    pip install rasterstats

## Usage

To download, process and generate mean annual precipitation for each stream segment:

    ./mean_annual_precip.sh

## Output

```
Table "whse_basemapping.fwa_stream_networks_mean_annual_precip"
        Column        |  Type   | Collation | Nullable |                          Default
----------------------+---------+-----------+----------+-----------------------------------------------------------
 id                   | integer |           | not null | nextval('bcfishpass.mean_annual_precip_id_seq'::regclass)
 wscode_ltree         | ltree   |           |          |
 localcode_ltree      | ltree   |           |          |
 watershed_group_code | text    |           |          |
 area                 | bigint  |           |          |
 map                  | integer |           |          |
 map_upstream         | integer |           |          |
Indexes:
    "mean_annual_precip_pkey" PRIMARY KEY, btree (id)
    "mean_annual_precip_wscode_ltree_localcode_ltree_key" UNIQUE CONSTRAINT, btree (wscode_ltree, localcode_ltree)
    "mean_annual_precip_localcode_ltree_idx" gist (localcode_ltree)
    "mean_annual_precip_localcode_ltree_idx1" btree (localcode_ltree)
    "mean_annual_precip_wscode_ltree_idx" gist (wscode_ltree)
    "mean_annual_precip_wscode_ltree_idx1" btree (wscode_ltree)
```

## Citations

- Wang, T., Hamann, A., Spittlehouse, D.L., Murdock, T., 2012. *ClimateWNA - High-Resolution Spatial Climate Data for Western North America*. Journal of Applied Meteorology and Climatology, 51: 16-29.*
- Daust K, Mahony C, Tremblay B, Barros C (2024). climr: Downscaling climate data in R. https://bcgov.github.io/climr/. 

## Source data lineage

### Climate BC

ClimateBC mean annual precipitation is used for watersheds in BC - but ClimateBC web and api do not seem to provide stable urls to required climate rasters. 
For easier builds, `Normal_1991_2020` `MAP.tif` from https://climatena.ca/spatialData (manually downloaded 2025-09-17) is cached on NRS object storage.

### climr

Precipitation for watershed areas outside of BC taken from  downloaded from the [climr climate mosaics](https://bcgov.github.io/climr/articles/methods_mosaic.html).

Monthly data was downloaded with the `climr` package in R Studio (2026-01-14, climr v0.2.2), then combined into a single annual raster and cached to NRS object storage.
Note that the download and processing could be modifed to be done fully in R, or via direct connect to the climr database.

1. In RStudio (noting that bbox is (xmin, xmax, ymin, ymax), re-order coordinates if taken from `st_extent` or similar)

        install.packages("remotes")
        remotes::install_github("bcgov/climr")
        bbox = c(-139.7,-112.2,45.4,62.2) 
        input_refmap(
            bbox,
            reference = "refmap_climr",
            cache = TRUE,
            indiv_tiles = FALSE,
            xyz = NULL
        )
        cache_path()

2. Manually copy the tif downloaded to `cache_path` to `data/climr.tif`

3. Extract mean annual precipitation from the resulting `data/climr.tif`

    What does this data look like?

        $ gdal info data/climr.tif --of json | tail -n 10
                "name":"b72",
                "description":"lr_Tmin_12"
              },
              {
                "name":"b73",
                "description":"dem2_WNA"
              }
            ]
          }
        }

    73 bands, but thankfully they are labelled... and conveniently monthly precip is the first 12 bands:
        
        $ gdal info data/climr.tif | grep -B 1 PPT

        Band 1 Block=1150x1 Type=Float32, ColorInterp=Gray
          Description = PPT_01
        --
        Band 2 Block=1150x1 Type=Float32, ColorInterp=Undefined
          Description = PPT_02
        --

    Add them together to get mean annual precipitation (note that this requires gdal compiled with `muparser`):

        gdal raster calc \
          -i "A=data/climr.tif" \
          --calc "A[1]+A[2]+A[3]+A[4]+A[5]+A[6]+A[7]+A[8]+A[9]+A[10]+A[11]+A[12]" \
          -o data/MAP_climr.tif