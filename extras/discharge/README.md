## Stream discharge

The [Pacific Climate Impacts Consortium](https://www.pacificclimate.org/) provides modelled base flow and runoff for the Peace, Fraser and Columbia basins. Time series rasters are available for download as NetCDF and other formats [here](https://www.pacificclimate.org/data/gridded-hydrologic-model-output). We combine base flow and runoff to model discharge, then link the results to FWA fundamental watersheds and streams.

## Requirements

The makefile will automatically install `postgis_raster` extension if it is not present in the database.

The `cdo` [Climate Data Operators](https://code.mpimet.mpg.de/projects/cdo) tool is also required, install via your package manager of choice or build from source:

- `conda install cdo` (this may not work on ARM based Macs) 
- `brew install cdo` 
- `apt install cdo`
- [from source](https://code.mpimet.mpg.de/projects/cdo/wiki/Cdo#Download-Compile-Install)

## Processing

To download PCIC base flow and runoff, combine into discharge, and load to postgres:

    make all


## Output table

                           Table "whse_basemapping.fwa_stream_networks_discharge"
            Column        |       Type       | Collation | Nullable | Default
    ----------------------+------------------+-----------+----------+---------
     linear_feature_id    | integer          |           |          |
     watershed_group_code | text             |           |          |
     mad_mm               | double precision |           |          |
     mad_m3s              | double precision |           |          |

## Caveats

1. Discharge is only accurate where all area contributing to a given stream is within BC (cross border watersheds are not supported)

2. Calculating discharge for major streams is computationally intensive - to speed processing, streams of order >= 8 are excluded


### Data Citation

Pacific Climate Impacts Consortium, University of Victoria, (January 2020). VIC-GL BCCAQ CMIP5: Gridded Hydrologic Model Output.