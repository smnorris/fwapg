# Relate Salmon Conservation Units (CU) to FWA streams


## Processing

1. Download the CUs at [https://data.salmonwatersheds.ca](https://data.salmonwatersheds.ca/result?datasetid=104) (requires a free account) and extract to `pse_conservation_units.gdb`

2. Load to database, planarize the polygons, relate CUs to FWA streams:


        ./pse_conservation_units.sh


## Output

See https://smnorris.github.io/fwapg/03_tables_views.html#psf.pse-conservation-units