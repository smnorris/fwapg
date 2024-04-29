-- delete all data/functions created by fwapg 

-- source fwa tables
drop table if exists whse_basemapping.fwa_assessment_watersheds_poly;
drop table if exists whse_basemapping.fwa_bays_and_channels_poly;
drop table if exists whse_basemapping.fwa_coastlines_sp;
drop table if exists whse_basemapping.fwa_edge_type_codes;
drop table if exists whse_basemapping.fwa_glaciers_poly;
drop table if exists whse_basemapping.fwa_islands_poly;
drop table if exists whse_basemapping.fwa_lakes_poly;
drop table if exists whse_basemapping.fwa_linear_boundaries_sp;
drop table if exists whse_basemapping.fwa_manmade_waterbodies_poly;
drop table if exists whse_basemapping.fwa_named_point_features_sp;
drop table if exists whse_basemapping.fwa_named_watersheds_poly;
drop table if exists whse_basemapping.fwa_obstructions_sp;
drop table if exists whse_basemapping.fwa_rivers_poly;
drop table if exists whse_basemapping.fwa_streams_20k_50k;
drop table if exists whse_basemapping.fwa_stream_networks_sp cascade;
drop table if exists whse_basemapping.fwa_waterbodies_20k_50k;
drop table if exists whse_basemapping.fwa_waterbody_type_codes;
drop table if exists whse_basemapping.fwa_watersheds_poly;
drop table if exists whse_basemapping.fwa_watershed_groups_poly;
drop table if exists whse_basemapping.fwa_watershed_type_codes;
drop table if exists whse_basemapping.fwa_wetlands_poly;

-- value added fwa tables
drop table if exists whse_basemapping.fwa_approx_borders;
drop table if exists whse_basemapping.fwa_basins_poly;
drop table if exists whse_basemapping.fwa_bcboundary;
drop table if exists whse_basemapping.fwa_named_streams;
drop table if exists whse_basemapping.fwa_waterbodies;

drop table if exists whse_basemapping.fwa_assessment_watersheds_lut;
drop table if exists whse_basemapping.fwa_assessment_watersheds_streams_lut;
drop table if exists whse_basemapping.fwa_streams_watersheds_lut;
drop table if exists whse_basemapping.fwa_waterbodies_upstream_area;
drop table if exists whse_basemapping.fwa_watersheds_upstream_area;

drop table if exists whse_basemapping.fwa_stream_networks_order_max;
drop table if exists whse_basemapping.fwa_stream_networks_order_parent;
drop table if exists whse_basemapping.fwa_stream_networks_discharge;
drop table if exists whse_basemapping.fwa_stream_networks_mean_annual_precip;
drop table if exists whse_basemapping.fwa_stream_networks_channel_width;

-- additional data
drop table if exists usgs.wbdhu12;
drop table if exists hydrosheds.hybas_lev12_v1c;

-- functions
drop function if exists cdb_makehexagon;
drop function if exists whse_basemapping.fwa_downstream(ltree,ltree,ltree,ltree);
drop function if exists whse_basemapping.fwa_downstream(integer,double precision,ltree,ltree,integer,double precision,ltree,ltree,boolean,double precision);
drop function if exists whse_basemapping.fwa_downstream(integer,double precision,double precision,ltree,ltree,integer,double precision,ltree,ltree,boolean,double precision);
drop function if exists whse_basemapping.fwa_indexpoint;
drop function if exists whse_basemapping.fwa_locatealong;
drop function if exists whse_basemapping.fwa_locatealonginterval;
drop function if exists whse_basemapping.fwa_slicewatershedatpoint;
drop function if exists whse_basemapping.fwa_streamsasmvt;
drop function if exists whse_basemapping.fwa_upstream(ltree,ltree,ltree,ltree);
drop function if exists whse_basemapping.fwa_upstream(integer,double precision,ltree,ltree,integer,double precision,ltree,ltree,boolean,double precision);
drop function if exists whse_basemapping.fwa_upstream(integer,double precision,double precision,ltree,ltree,integer,double precision,ltree,ltree,boolean,double precision);
drop function if exists whse_basemapping.fwa_upstreambordercrossings;
drop function if exists whse_basemapping.fwa_upstreamtrace;
drop function if exists whse_basemapping.fwa_watershedatmeasure;
drop function if exists whse_basemapping.fwa_watershedhex;
drop function if exists whse_basemapping.fwa_watershedstream;
drop function if exists usgs.huc12;
drop function if exists hydrosheds.hydroshed;
drop function if exists st_safe_repair;

drop schema if exists fwapg cascade;
