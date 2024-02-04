-- create user/rol featureserver_fwa for serving FWA data via pgfs

CREATE USER featureserver_fwa WITH PASSWORD :'pwd';

-- grant usage of functions in postgisftw
GRANT USAGE ON SCHEMA postgisftw TO featureserver_fwa;

-- prevent FWA functions from being served by other pgfs instances
REVOKE EXECUTE ON FUNCTION postgisftw.FWA_IndexPoint FROM public;
REVOKE EXECUTE ON FUNCTION postgisftw.FWA_LocateAlong FROM public;
REVOKE EXECUTE ON FUNCTION postgisftw.FWA_LocateAlongInterval FROM public;
REVOKE EXECUTE ON FUNCTION postgisftw.FWA_UpstreamTrace FROM public;
REVOKE EXECUTE ON FUNCTION postgisftw.FWA_WatershedAtMeasure FROM public;
REVOKE EXECUTE ON FUNCTION postgisftw.FWA_WatershedHex FROM public;
REVOKE EXECUTE ON FUNCTION postgisftw.FWA_WatershedStream FROM public;
REVOKE EXECUTE ON FUNCTION postgisftw.hydroshed FROM public;

-- but allow via FWA pgfs
GRANT EXECUTE ON FUNCTION postgisftw.FWA_IndexPoint to featureserver_fwa;
GRANT EXECUTE ON FUNCTION postgisftw.FWA_LocateAlong to featureserver_fwa;
GRANT EXECUTE ON FUNCTION postgisftw.FWA_LocateAlongInterval to featureserver_fwa;
GRANT EXECUTE ON FUNCTION postgisftw.FWA_UpstreamTrace to featureserver_fwa;
GRANT EXECUTE ON FUNCTION postgisftw.FWA_WatershedAtMeasure to featureserver_fwa;
GRANT EXECUTE ON FUNCTION postgisftw.FWA_WatershedHex to featureserver_fwa;
GRANT EXECUTE ON FUNCTION postgisftw.FWA_WatershedStream to featureserver_fwa;
GRANT EXECUTE ON FUNCTION postgisftw.hydroshed to featureserver_fwa;

-- grant access to whse_basemapping schema and various FWA tables within
GRANT USAGE ON SCHEMA whse_basemapping TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_approx_borders TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_assessment_watersheds_lut TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_assessment_watersheds_poly TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_assessment_watersheds_streams_lut TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_basins_poly TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_bays_and_channels_poly TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_bcboundary TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_coastlines_sp TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_edge_type_codes TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_glaciers_poly TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_islands_poly TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_lakes_poly TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_linear_boundaries_sp TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_manmade_waterbodies_poly TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_named_streams TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_named_watersheds_poly TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_obstructions_sp TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_rivers_poly TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_stream_networks_sp TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_streams_20k_50k TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_waterbodies TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_waterbodies_20k_50k TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_waterbody_type_codes TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_watershed_groups_poly TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_watershed_type_codes TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_watersheds_poly TO featureserver_fwa;
GRANT SELECT ON whse_basemapping.fwa_wetlands_poly TO featureserver_fwa;

-- streams view with value added data (area upstream / discharge / precip / channel width)
GRANT SELECT ON whse_basemapping.fwa_streams_vw TO featureserver_fwa;

-- also grant access to data from neighbouring jurisdictions
GRANT USAGE ON SCHEMA hydrosheds TO featureserver_fwa;
GRANT SELECT ON ALL TABLES IN SCHEMA hydrosheds TO featureserver_fwa;
ALTER DEFAULT PRIVILEGES IN SCHEMA hydrosheds GRANT SELECT ON TABLES TO featureserver_fwa;

GRANT USAGE ON SCHEMA usgs TO featureserver_fwa;
GRANT SELECT ON ALL TABLES IN SCHEMA usgs TO featureserver_fwa;
ALTER DEFAULT PRIVILEGES IN SCHEMA usgs GRANT SELECT ON TABLES TO featureserver_fwa;