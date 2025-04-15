create schema fwapg;                           -- for temp/load tables

-- these may already exist and hold non-fwa data / functions
create schema if not exists whse_basemapping;
create schema if not exists usgs;
create schema if not exists psf;
create schema if not exists hydrosheds;
create schema if not exists postgisftw;        -- for functions served by pg_featureserv
