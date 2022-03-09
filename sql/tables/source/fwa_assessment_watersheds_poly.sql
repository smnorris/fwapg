CREATE TABLE IF NOT EXISTS whse_basemapping.fwa_assessment_watersheds_poly (
    watershed_feature_id integer PRIMARY KEY,
    watershed_group_id integer,
    watershed_type character varying(1),
    gnis_id_1 integer,
    gnis_name_1 character varying(80),
    gnis_id_2 integer,
    gnis_name_2 character varying(80),
    gnis_id_3 integer,
    gnis_name_3 character varying(80),
    waterbody_id bigint,
    waterbody_key bigint,
    watershed_key bigint,
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    watershed_group_code character varying(4),
    left_right_tributary character varying(7),
    watershed_order integer,
    watershed_magnitude integer,
    local_watershed_order integer,
    local_watershed_magnitude integer,
    area_ha double precision,
    feature_code character varying(10),
    geom geometry,
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED
);

CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly (gnis_name_1);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly (waterbody_id);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly (waterbody_key);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly (watershed_key);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly USING BTREE (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_assessment_watersheds_poly USING GIST(geom);