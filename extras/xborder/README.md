# Trans boundary watersheds

Where areas outside of BC contribute to BC streams, add the areas outside of BC to the fundamental watersheds layer.
Compiling this data was a manual process, no scripts are included.

## Source 

Data provided by DFO: Dan Weller, 2024-06-19

## Description
Modification to the FWA Fundamnetal Watersheds dataset to include cross-border areas that drain
into BC from other jurisdictions. The modified dataset should include the entire catchment area for any fundamental
watershed within BC. Hierarchical codes have been updated so any flow routing, catchment delineation should still work.

## DFO workflow

1) Identify all fundamental watersheds within BC that receive water from across the border;
2) Use those fundamentals as pour points to delineate corresponding cross-border watersheds from a DEM (first pass);
3) Inspect new watersheds: manually correct boundary misalignments and updated hierarchical codes and any other relevant attributes.

Other notes:
- DEM used for watershed delineation was a combination of CDEM and NED products. If there were elevation
mismatches across the border that led to obvious errors in watershed delineation, the boundaries were manually
adjusted by cross-checking with other sources (usually a combo of satellite imagery, SRTM and/or GMTED). 
- NHD and NHN products were also assessed during the manual correction process.
- The new watersheds were initially assigned the FWA attributes from their associated receiving fundamental 
(i.e., whatever it flows into), which were then modified as needed.
- The hierarchical codes were updated to maintain the correct flow path, but not the exact position, within the network.
Typically, the update involved adding '1' to the highest populated level of the LOCAL code.  For example, if the LOCAL
code for the receiving watershed was '100-123456-123456-...', the new watershed would have a LOCAL code of '100-123456-123457-...'.
This would put the new watershed upstream of the receiving watershed, but the '-123457' level no longer accurately reflects
its position along that stream line.

## Modifications for load to fwapg

- collect data of interest (trans boundary watersheds only) from provided files into a single table 
- add several data fixes to ``../fixes/fixes.sql` (additional data fixes from the DFO file will be submitted to GeoBC at a later date)
- conduct rough QA of boundaries and codes
- update watershed codes in the Chilliwack drainage to reflect FWA wscode updates
- dump resulting table to `fwa_watersheds_xborder_poly.parquet` and load to NR object storage
- modify fwapg load scripts


Output file is available at https://nrs.objectstore.gov.bc.ca/bchamp/fwapg/fwa_watersheds_xborder_poly.parquet.
