# Extras

Value added FWA data that generally requires several hours to generate. 

Rather than re-generate the lookups each time the database is loaded, `fwapg` defaults to loading the tables from cached csvs. 

If updates to the lookups are required, regenerate the csv files using these scripts.


# Publication

To upload data to BC object storage on completion of scripts:

aws s3 cp channel_width/fwa_stream_networks_channel_width.csv.gz s3://$BUCKET --acl public-read
aws s3 cp discharge/fwa_stream_networks_discharge.csv.gz s3://$BUCKET --acl public-read
aws s3 cp precipitation/fwa_stream_networks_mean_annual_precip.csv.gz s3://$BUCKET --acl public-read
aws s3 cp lookups/fwa_assessment_watersheds_lut.csv.gz s3://$BUCKET --acl public-read
aws s3 cp lookups/fwa_assessment_watersheds_streams_lut.csv.gz s3://$BUCKET --acl public-read
aws s3 cp lookups/fwa_waterbodies_upstream_area.csv.gz s3://$BUCKET --acl public-read
aws s3 cp lookups/fwa_watersheds_upstream_area.csv.gz s3://$BUCKET --acl public-read