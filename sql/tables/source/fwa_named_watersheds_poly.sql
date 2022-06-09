drop table if exists fwapg.fwa_named_watersheds_poly;

create table fwapg.fwa_named_watersheds_poly (
  named_watershed_id integer primary key,
  gnis_id integer,
  gnis_name character varying(80),
  blue_line_key integer,
  watershed_key integer,
  fwa_watershed_code character varying(143),
  stream_order integer,
  stream_magnitude integer,
  area_ha double precision,
  feature_code character varying(10),
  wscode_ltree public.ltree generated always as
    ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) stored,
  geom public.geometry(multipolygon,3005)
);

insert into fwapg.fwa_named_watersheds_poly (
  named_watershed_id,
  gnis_id,
  gnis_name,
  blue_line_key,
  watershed_key,
  fwa_watershed_code,
  stream_order,
  stream_magnitude,
  area_ha,
  feature_code,
  geom
)
select
  (data -> 'properties' ->> 'NAMED_WATERSHED_ID')::integer as named_watershed_id,
  (data -> 'properties' ->> 'GNIS_ID')::integer as gnis_id,
  data -> 'properties' ->> 'GNIS_NAME' as gnis_name,
  (data -> 'properties' ->> 'BLUE_LINE_KEY')::integer as blue_line_key,
  (data -> 'properties' ->> 'WATERSHED_KEY')::integer as watershed_key,
  data -> 'properties' ->> 'FWA_WATERSHED_CODE' as fwa_watershed_code,
  (data -> 'properties' ->> 'STREAM_ORDER')::integer as stream_order,
  (data -> 'properties' ->> 'STREAM_MAGNITUDE')::integer as stream_magnitude,
  (data -> 'properties' ->> 'AREA_HA')::double precision as area_ha,
  data -> 'properties' ->> 'FEATURE_CODE' as feature_code,
  st_multi(ST_SetSRID(ST_GeomFromGeoJSON(data -> 'geometry'), 3005)) as geom
from fwapg.fwa_named_watersheds_poly_load;

create index on fwapg.fwa_named_watersheds_poly (gnis_name);
create index on fwapg.fwa_named_watersheds_poly (blue_line_key);
create index on fwapg.fwa_named_watersheds_poly (fwa_watershed_code);
create index on fwapg.fwa_named_watersheds_poly using gist (wscode_ltree);
create index on fwapg.fwa_named_watersheds_poly using btree (wscode_ltree);
create index on fwapg.fwa_named_watersheds_poly using gist (geom);