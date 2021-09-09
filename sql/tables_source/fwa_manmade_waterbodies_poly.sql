CREATE TABLE whse_basemapping.fwa_manmade_waterbodies_poly (
    waterbody_poly_id integer PRIMARY KEY,
    watershed_group_id integer,
    waterbody_type character varying(1),
    waterbody_key integer,
    area_ha double precision,
    gnis_id_1 integer,
    gnis_name_1 character varying(80),
    gnis_id_2 integer,
    gnis_name_2 character varying(80),
    gnis_id_3 integer,
    gnis_name_3 character varying(80),
    blue_line_key integer,
    watershed_key integer,
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    watershed_group_code character varying(4),
    left_right_tributary character varying(7),
    waterbody_key_50k integer,
    watershed_group_code_50k character varying(4),
    waterbody_key_group_code_50k character varying(55),
    watershed_code_50k character varying(45),
    feature_code character varying(10),
    geom public.geometry,
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED
);

CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly (blue_line_key);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly (watershed_key);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly (waterbody_key);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly (gnis_name_1);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly USING BTREE (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_manmade_waterbodies_poly USING GIST (geom);