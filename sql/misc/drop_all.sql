-- delete all data/functions created by fwapg 

-- source fwa tables
drop table if exists whse_basemapping.fwa_assessment_watersheds_poly;
drop table if exists whse_basemapping.fwa_bays_and_channels_poly;
drop table if exists whse_basemapping.fwa_coastlines_sp;
drop table if exists whse_basemapping.fwa_edge_type_codes;
drop table if exists whse_basemapping.fwa_glaciers_poly;
drop table if exists whse_basemapping.fwa_islands_poly;
drop table if exists whse_basemapping.fwa_lakes_poly;
drop table if exists whse_basemapping.fwa_manmade_waterbodies_poly;
drop table if exists whse_basemapping.fwa_named_point_features_sp;
drop table if exists whse_basemapping.fwa_named_watersheds_poly;
drop table if exists whse_basemapping.fwa_obstructions_sp;
drop table if exists whse_basemapping.fwa_rivers_poly;
drop table if exists whse_basemapping.fwa_streams_20k_50k;
drop table if exists whse_basemapping.fwa_stream_networks_sp;
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
drop table if exists whse_basemapping.fwa_stream_order_parent;

-- additional data
drop table if exists usgs.wdbhu12;
drop table if exists hydrosheds.hybas_lev12_v1c;

-- functions
drop function if exists cdb_makehexagon;
drop function if exists st_safe_repair;

drop function if exists fwa_huc12;
drop function if exists fwa_hydroshed;
drop function if exists fwa_indexpoint;

drop function if exists fwa_upstream(ltree,ltree,ltree,ltree);
drop function if exists fwa_upstream(integer,double precision,ltree,ltree,integer,double precision,ltree,ltree,boolean,double precision);
drop function if exists fwa_upstream(integer,double precision,double precision,ltree,ltree,integer,double precision,ltree,ltree,boolean,double precision);

drop function if exists fwa_downstream(ltree,ltree,ltree,ltree);
drop function if exists fwa_downstream(integer,double precision,ltree,ltree,integer,double precision,ltree,ltree,boolean,double precision);
drop function if exists fwa_downstream(integer,double precision,double precision,ltree,ltree,integer,double precision,ltree,ltree,boolean,double precision);

drop function if exists fwa_upstreambordercrossings;
drop function if exists fwa_slicewatershedatpoint;
drop function if exists fwa_watershedexbc;
drop function if exists fwa_watershedatmeasure;
drop function if exists fwa_watershedhex;
drop function if exists fwa_watershedstream;
drop function if exists fwa_locatealong;
drop function if exists fwa_locatealonginterval;

drop schema if exists fwapg cascade;
