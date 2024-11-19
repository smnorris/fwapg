#!/bin/bash
set -euxo pipefail

# cache to s3 for (much) faster downloads
# also, add .gdb to filename so files can be accessed directly via /vsizip//vsicurl

curl -o /tmp/FWA_BC.gdb.zip ftp://ftp.geobc.gov.bc.ca/sections/outgoing/bmgs/FWA_Public/FWA_BC.zip
curl -o /tmp/FWA_LINEAR_BOUNDARIES_SP.gdb.zip ftp://ftp.geobc.gov.bc.ca/sections/outgoing/bmgs/FWA_Public/FWA_LINEAR_BOUNDARIES_SP.zip
curl -o /tmp/FWA_WATERSHEDS_POLY.gdb.zip ftp://ftp.geobc.gov.bc.ca/sections/outgoing/bmgs/FWA_Public/FWA_WATERSHEDS_POLY.zip
curl -o /tmp/FWA_STREAM_NETWORKS_SP.gdb.zip ftp://ftp.geobc.gov.bc.ca/sections/outgoing/bmgs/FWA_Public/FWA_STREAM_NETWORKS_SP.zip

aws s3 cp /tmp/FWA_BC.gdb.zip s3://bchamp/fwapg/FWA_BC.gdb.zip --acl public-read 
aws s3 cp /tmp/FWA_LINEAR_BOUNDARIES_SP.gdb.zip s3://bchamp/fwapg/FWA_LINEAR_BOUNDARIES_SP.gdb.zip --acl public-read
aws s3 cp /tmp/FWA_WATERSHEDS_POLY.gdb.zip s3://bchamp/fwapg/FWA_WATERSHEDS_POLY.gdb.zip --acl public-read
aws s3 cp /tmp/FWA_STREAM_NETWORKS_SP.gdb.zip s3://bchamp/fwapg/FWA_STREAM_NETWORKS_SP.gdb.zip --acl public-read
