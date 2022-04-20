-- delete all data/functions created by fwapg 

-- source FWA tables
DROP TABLE IF EXISTS whse_basemapping.fwa_assessment_watersheds_poly;
DROP TABLE IF EXISTS whse_basemapping.fwa_bays_and_channels_poly;
DROP TABLE IF EXISTS whse_basemapping.fwa_coastlines_sp;
DROP TABLE IF EXISTS whse_basemapping.fwa_edge_type_codes;
DROP TABLE IF EXISTS whse_basemapping.fwa_glaciers_poly;
DROP TABLE IF EXISTS whse_basemapping.fwa_islands_poly;
DROP TABLE IF EXISTS whse_basemapping.fwa_lakes_poly;
DROP TABLE IF EXISTS whse_basemapping.fwa_manmade_waterbodies_poly;
DROP TABLE IF EXISTS whse_basemapping.fwa_named_point_features_sp;
DROP TABLE IF EXISTS whse_basemapping.fwa_named_watersheds_poly;
DROP TABLE IF EXISTS whse_basemapping.fwa_obstructions_sp;
DROP TABLE IF EXISTS whse_basemapping.fwa_rivers_poly;
DROP TABLE IF EXISTS whse_basemapping.fwa_streams_20k_50k;
DROP TABLE IF EXISTS whse_basemapping.fwa_waterbodies_20k_50k;
DROP TABLE IF EXISTS whse_basemapping.fwa_waterbody_type_codes;
DROP TABLE IF EXISTS whse_basemapping.fwa_watershed_groups_poly;
DROP TABLE IF EXISTS whse_basemapping.fwa_watershed_type_codes;
DROP TABLE IF EXISTS whse_basemapping.fwa_wetlands_poly;

-- value added FWA tables
DROP TABLE IF EXISTS whse_basemapping.fwa_approx_borders;
DROP TABLE IF EXISTS whse_basemapping.fwa_basins_poly;
DROP TABLE IF EXISTS whse_basemapping.fwa_bcboundary;
DROP TABLE IF EXISTS whse_basemapping.fwa_named_streams;
DROP TABLE IF EXISTS whse_basemapping.fwa_waterbodies;
DROP TABLE IF EXISTS whse_basemapping.fwa_stream_order_parent;

-- additional data
DROP TABLE IF EXISTS usgs.wdbhu12;
DROP TABLE IF EXISTS hydrosheds.hybas_lev12_v1c;

-- functions 
DROP FUNCTION IF EXISTS CDB_MakeHexagon;
DROP FUNCTION IF EXISTS ST_Safe_Repair;

DROP FUNCTION IF EXISTS FWA_huc12;
DROP FUNCTION IF EXISTS FWA_hydroshed;
DROP FUNCTION IF EXISTS FWA_IndexPoint;

DROP FUNCTION FWA_Upstream(ltree,ltree,ltree,ltree);
DROP FUNCTION FWA_Upstream(integer,double precision,ltree,ltree,integer,double precision,ltree,ltree,boolean,double precision);
DROP FUNCTION FWA_Upstream(integer,double precision,double precision,ltree,ltree,integer,double precision,ltree,ltree,boolean,double precision);

DROP FUNCTION FWA_Downstream(ltree,ltree,ltree,ltree);
DROP FUNCTION FWA_Downstream(integer,double precision,ltree,ltree,integer,double precision,ltree,ltree,boolean,double precision);
DROP FUNCTION FWA_Downstream(integer,double precision,double precision,ltree,ltree,integer,double precision,ltree,ltree,boolean,double precision);

DROP FUNCTION IF EXISTS FWA_UpstreamBorderCrossings;
DROP FUNCTION IF EXISTS FWA_SliceWatershedAtPoint;
DROP FUNCTION IF EXISTS FWA_WatershedExBC;
DROP FUNCTION IF EXISTS FWA_WatershedAtMeasure;
DROP FUNCTION IF EXISTS FWA_WatershedHex;
DROP FUNCTION IF EXISTS FWA_WatershedStream;
DROP FUNCTION IF EXISTS FWA_LocateAlong;
DROP FUNCTION IF EXISTS FWA_LocateAlongInterval;

-- schema
DROP SCHEMA postgisftw CASCADE;