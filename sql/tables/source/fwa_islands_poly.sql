DROP TABLE IF EXISTS fwapg.fwa_islands_poly;

CREATE TABLE fwapg.fwa_islands_poly (
    island_id integer PRIMARY KEY,
    island_type character varying(12),
    gnis_id_1 integer,
    gnis_name_1 character varying(80),
    gnis_id_2 integer,
    gnis_name_2 character varying(80),
    gnis_id_3 integer,
    gnis_name_3 character varying(80),
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    area_ha double precision,
    feature_code character varying(10),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    geom public.geometry(multipolygon,3005)
);

insert into fwapg.fwa_islands_poly (
  island_id,
  island_type,
  gnis_id_1,
  gnis_name_1,
  gnis_id_2,
  gnis_name_2,
  gnis_id_3,
  gnis_name_3,
  fwa_watershed_code,
  local_watershed_code,
  area_ha,
  feature_code,
  geom
)
select
  island_id::integer,
  island_type,
  gnis_id_1::integer,
  gnis_name_1,
  gnis_id_2::integer,
  gnis_name_2,
  gnis_id_3::integer,
  gnis_name_3,
  fwa_watershed_code,
  local_watershed_code,
  area_ha,
  feature_code,
  st_multi(geom) as geom
from fwapg.fwa_islands_poly_load;

CREATE INDEX ON fwapg.fwa_islands_poly (gnis_name_1);
CREATE INDEX ON fwapg.fwa_islands_poly (gnis_name_2);
CREATE INDEX ON fwapg.fwa_islands_poly USING GIST (wscode_ltree);
CREATE INDEX ON fwapg.fwa_islands_poly USING BTREE (wscode_ltree);
CREATE INDEX ON fwapg.fwa_islands_poly USING GIST (localcode_ltree);
CREATE INDEX ON fwapg.fwa_islands_poly USING BTREE (localcode_ltree);
CREATE INDEX ON fwapg.fwa_islands_poly USING GIST (geom);