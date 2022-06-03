drop table if exists fwapg.fwa_watershed_groups_poly;

create table fwapg.fwa_watershed_groups_poly (
    watershed_group_id integer primary key,
    watershed_group_code character varying(4),
    watershed_group_name character varying(80),
    area_ha double precision,
    feature_code character varying(10),
    geom public.geometry(multipolygon,3005)
);

insert into fwapg.fwa_watershed_groups_poly (
  watershed_group_id,
  watershed_group_code,
  watershed_group_name,
  area_ha,
  feature_code,
  geom
)
select
  watershed_group_id,
  watershed_group_code,
  watershed_group_name,
  area_ha,
  feature_code,
  st_multi(geom) as geom
from fwapg.fwa_watershed_groups_poly_load;

create index on fwapg.fwa_watershed_groups_poly (watershed_group_code);
create index on fwapg.fwa_watershed_groups_poly using gist (geom);