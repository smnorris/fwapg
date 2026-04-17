# Extras

Value added FWA data that generally requires several hours to generate. 
Rather than re-generate the lookups each time the database is loaded, `fwapg` loads this data from files cached to nrs.objectstore.

## Updates 

Updates to the lookups are generally required whenever the source FWA geometries and codes have changed.
Update source FWA files in your database, then regenerate the cached data files using scripts in this folder.
When complete, upload to nrs.objectstore:

	aws s3 cp channel_width/fwa_stream_networks_channel_width.csv.gz s3://bchamp/fwapg/fwa_stream_networks_channel_width.csv.gz --acl public-read
	aws s3 cp discharge/fwa_stream_networks_discharge.csv.gz s3://bchamp/fwapg/fwa_stream_networks_discharge.csv.gz --acl public-read
	aws s3 cp precipitation/fwa_stream_networks_mean_annual_precip.csv.gz s3://bchamp/fwapg/fwa_stream_networks_mean_annual_precip.csv.gz --acl public-read
	aws s3 cp lookups/fwa_assessment_watersheds_lut.csv.gz s3://bchamp/fwapg/fwa_assessment_watersheds_lut.csv.gz --acl public-read
	aws s3 cp lookups/fwa_assessment_watersheds_streams_lut.csv.gz s3://bchamp/fwapg/fwa_assessment_watersheds_streams_lut.csv.gz --acl public-read
	aws s3 cp lookups/fwa_waterbodies_upstream_area.csv.gz s3://bchamp/fwapg/fwa_waterbodies_upstream_area.csv.gz --acl public-read
	aws s3 cp lookups/fwa_watersheds_upstream_area.csv.gz s3://bchamp/fwapg/fwa_watersheds_upstream_area.csv.gz --acl public-read

Note that no metadata is currently provided to link versions of these add-ons to a given version of the FWA data (this is a to-do).