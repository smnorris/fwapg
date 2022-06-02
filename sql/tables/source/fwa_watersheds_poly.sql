drop table if exists whse_basemapping.fwa_watersheds_poly;

create table whse_basemapping.fwa_watersheds_poly (
  watershed_feature_id       integer primary key     ,
  watershed_group_id         integer not null        ,
  watershed_type             character varying(1)    ,
  gnis_id_1                  integer                 ,
  gnis_name_1                character varying(80)   ,
  gnis_id_2                  integer                 ,
  gnis_name_2                character varying(80)   ,
  gnis_id_3                  integer                 ,
  gnis_name_3                character varying(80)   ,
  waterbody_id               integer                 ,
  waterbody_key              integer                 ,
  watershed_key              integer not null        ,
  fwa_watershed_code         character varying(143) not null,
  local_watershed_code       character varying(143) not null,
  watershed_group_code       character varying(4) not null,
  left_right_tributary       character varying(7)    ,
  watershed_order            integer                 ,
  watershed_magnitude        integer                 ,
  local_watershed_order      integer                 ,
  local_watershed_magnitude  integer                 ,
  area_ha                    double precision        ,
  river_area                 double precision        ,
  lake_area                  double precision        ,
  wetland_area               double precision        ,
  manmade_area               double precision        ,
  glacier_area               double precision        ,
  average_elevation          double precision        ,
  average_slope              double precision        ,
  aspect_north               double precision        ,
  aspect_south               double precision        ,
  aspect_west                double precision        ,
  aspect_east                double precision        ,
  aspect_flat                double precision        ,
  feature_code               character varying(10)   ,
  wscode_ltree ltree generated always as (replace(replace(fwa_watershed_code, '-000000', ''), '-', '.')::ltree) stored,
  localcode_ltree ltree generated always as (replace(replace(local_watershed_code, '-000000', ''), '-', '.')::ltree) stored,
  geom                       public.geometry(multipolygon,3005)
 );

insert into whse_basemapping.fwa_watersheds_poly (
  watershed_feature_id,
  watershed_group_id,
  watershed_type,
  gnis_id_1,
  gnis_name_1,
  gnis_id_2,
  gnis_name_2,
  gnis_id_3,
  gnis_name_3,
  waterbody_id,
  waterbody_key,
  watershed_key,
  fwa_watershed_code,
  local_watershed_code,
  watershed_group_code,
  left_right_tributary,
  watershed_order,
  watershed_magnitude,
  local_watershed_order,
  local_watershed_magnitude,
  area_ha,
  river_area,
  lake_area,
  wetland_area,
  manmade_area,
  glacier_area,
  average_elevation,
  average_slope,
  aspect_north,
  aspect_south,
  aspect_west,
  aspect_east,
  aspect_flat,
  feature_code,
  geom
)
select
  watershed_feature_id,
  watershed_group_id::integer,
  watershed_type,
  gnis_id_1::integer,
  gnis_name_1,
  gnis_id_2::integer,
  gnis_name_2,
  gnis_id_3::integer,
  gnis_name_3,
  waterbody_id::integer,
  waterbody_key::integer,
  watershed_key::integer,
  fwa_watershed_code,
  local_watershed_code,
  watershed_group_code,
  left_right_tributary,
  watershed_order,
  watershed_magnitude,
  local_watershed_order,
  local_watershed_magnitude,
  area_ha,
  river_area::numeric,
  lake_area::numeric,
  wetland_area::numeric,
  manmade_area::numeric,
  glacier_area::numeric,
  average_elevation::numeric,
  average_slope::numeric,
  aspect_north::numeric,
  aspect_south::numeric,
  aspect_west::numeric,
  aspect_east::numeric,
  aspect_flat::numeric,
  feature_code,
  st_multi(geom) as geom
from fwapg.fwa_watersheds_poly;

-- index
create index on whse_basemapping.fwa_watersheds_poly (gnis_name_1);
create index on whse_basemapping.fwa_watersheds_poly (waterbody_id);
create index on whse_basemapping.fwa_watersheds_poly (waterbody_key);
create index on whse_basemapping.fwa_watersheds_poly (watershed_key);
create index on whse_basemapping.fwa_watersheds_poly (watershed_group_code);
create index on whse_basemapping.fwa_watersheds_poly (watershed_group_id);
create index fwa_watersheds_poly_wscode_ltree_gist_idx on whse_basemapping.fwa_watersheds_poly using gist (wscode_ltree);
create index on whse_basemapping.fwa_watersheds_poly using btree (wscode_ltree);
create index on whse_basemapping.fwa_watersheds_poly using gist (localcode_ltree);
create index on whse_basemapping.fwa_watersheds_poly using btree (localcode_ltree);
create index on whse_basemapping.fwa_watersheds_poly using gist (geom);