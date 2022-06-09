drop table if exists fwapg.fwa_watersheds_poly;

create table fwapg.fwa_watersheds_poly (
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

insert into fwapg.fwa_watersheds_poly (
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
  (data -> 'properties' ->> 'WATERSHED_FEATURE_ID')::integer as watershed_feature_id,
  (data -> 'properties' ->> 'WATERSHED_GROUP_ID')::integer as watershed_group_id,
  (data -> 'properties' ->> 'WATERSHED_TYPE') as watershed_type,
  (data -> 'properties' ->> 'GNIS_ID_1')::integer as gnis_id_1,
  (data -> 'properties' ->> 'GNIS_NAME_1') as gnis_name_1,
  (data -> 'properties' ->> 'GNIS_ID_2')::integer as gnis_id_2,
  (data -> 'properties' ->> 'GNIS_NAME_2') as gnis_name_2,
  (data -> 'properties' ->> 'GNIS_ID_3')::integer as gnis_id_3,
  (data -> 'properties' ->> 'GNIS_NAME_3') as gnis_name_3,
  (data -> 'properties' ->> 'WATERBODY_ID')::integer as waterbody_id,
  (data -> 'properties' ->> 'WATERBODY_KEY')::integer as waterbody_key,
  (data -> 'properties' ->> 'WATERSHED_KEY')::integer as watershed_key,
  (data -> 'properties' ->> 'FWA_WATERSHED_CODE') as fwa_watershed_code,
  (data -> 'properties' ->> 'LOCAL_WATERSHED_CODE') as local_watershed_code,
  (data -> 'properties' ->> 'WATERSHED_GROUP_CODE') as watershed_group_code,
  (data -> 'properties' ->> 'LEFT_RIGHT_TRIBUTARY') as left_right_tributary,
  (data -> 'properties' ->> 'WATERSHED_ORDER')::integer as watershed_order,
  (data -> 'properties' ->> 'WATERSHED_MAGNITUDE')::integer as watershed_magnitude,
  (data -> 'properties' ->> 'LOCAL_WATERSHED_ORDER')::integer as local_watershed_order,
  (data -> 'properties' ->> 'LOCAL_WATERSHED_MAGNITUDE')::integer as local_watershed_magnitude,
  (data -> 'properties' ->> 'AREA_HA')::double precision as area_ha,
  (data -> 'properties' ->> 'RIVER_AREA')::double precision as river_area,
  (data -> 'properties' ->> 'LAKE_AREA')::double precision as lake_area,
  (data -> 'properties' ->> 'WETLAND_AREA')::double precision as wetland_area,
  (data -> 'properties' ->> 'MANMADE_AREA')::double precision as manmade_area,
  (data -> 'properties' ->> 'GLACIER_AREA')::double precision as glacier_area,
  (data -> 'properties' ->> 'AVERAGE_ELEVATION')::double precision as average_elevation,
  (data -> 'properties' ->> 'AVERAGE_SLOPE')::double precision as average_slope,
  (data -> 'properties' ->> 'ASPECT_NORTH')::double precision as aspect_north,
  (data -> 'properties' ->> 'ASPECT_SOUTH')::double precision as aspect_south,
  (data -> 'properties' ->> 'ASPECT_WEST')::double precision as aspect_west,
  (data -> 'properties' ->> 'ASPECT_EAST')::double precision as aspect_east,
  (data -> 'properties' ->> 'ASPECT_FLAT')::double precision as aspect_flat,
  (data -> 'properties' ->> 'FEATURE_CODE') as feature_code,
  st_multi(ST_SetSRID(ST_GeomFromGeoJSON(data -> 'geometry'), 3005)) as geom
from fwapg.fwa_watersheds_poly_load;

-- index
create index on fwapg.fwa_watersheds_poly (gnis_name_1);
create index on fwapg.fwa_watersheds_poly (waterbody_id);
create index on fwapg.fwa_watersheds_poly (waterbody_key);
create index on fwapg.fwa_watersheds_poly (watershed_key);
create index on fwapg.fwa_watersheds_poly (watershed_group_code);
create index on fwapg.fwa_watersheds_poly (watershed_group_id);
create index fwa_watersheds_poly_wscode_ltree_gist_idx on fwapg.fwa_watersheds_poly using gist (wscode_ltree);
create index on fwapg.fwa_watersheds_poly using btree (wscode_ltree);
create index on fwapg.fwa_watersheds_poly using gist (localcode_ltree);
create index on fwapg.fwa_watersheds_poly using btree (localcode_ltree);
create index on fwapg.fwa_watersheds_poly using gist (geom);