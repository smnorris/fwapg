## Stream discharge

The [Pacific Climate Impacts Consortium](https://www.pacificclimate.org/) (PCIC) provides modelled base flow and runoff for the Peace, Fraser and Columbia basins. 
Time series rasters (~30km2 resolution) are available for download as NetCDF and other formats [here](https://www.pacificclimate.org/data/gridded-hydrologic-model-output). 
We combine base flow and runoff rasters to model discharge, then link the results to FWA fundamental watersheds and streams. 
No upsampling of the PCIC data is performed (the discharge values could potentially be weighted via higher resolution precipitation data).


## Requirements

The `postgis_raster` postgresql extension must be available for install.

The `cdo` [Climate Data Operators](https://code.mpimet.mpg.de/projects/cdo) tool is required, install via your package manager of choice or build from source:

- `conda install cdo` (this may not work on ARM based Macs) 
- `brew install cdo` 
- `apt install cdo`
- [from source](https://code.mpimet.mpg.de/projects/cdo/wiki/Cdo#Download-Compile-Install)


## Processing

To run:

    ./discharge.sh

This job:
    
  - downloads PCIC base flow and runoff rasters
  - combines the PCIC rasters into a discharge raster (where values are discharge for each cell, not cumulative discharge)
  - loads the discharge raster to postgres
  - find discharge for each FWA fundamental watershed from the PCIC raster
  - for each fundamental watershed, calculate the cumulative discharge from all upstream watersheds to that watershed
  - convert this cumulative discharge to mm per m2 per year
  - join FWA streams to the discharge value for their associated watershed, dump result to file


## Output table

                           Table "whse_basemapping.fwa_stream_networks_discharge"
            Column        |       Type       | Collation | Nullable | Default
    ----------------------+------------------+-----------+----------+---------
     linear_feature_id    | integer          |           |          |
     watershed_group_code | text             |           |          |
     mad_mm               | double precision |           |          |
     mad_m3s              | double precision |           |          |


## Caveat

Calculating discharge for major systems is computationally intensive - to speed processing, rivers of order >= 8 are excluded


### Data Citation

Pacific Climate Impacts Consortium, University of Victoria, (January 2020). VIC-GL BCCAQ CMIP5: Gridded Hydrologic Model Output.