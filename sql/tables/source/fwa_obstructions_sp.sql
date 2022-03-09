DROP TABLE IF EXISTS whse_basemapping.fwa_obstructions_sp;

CREATE TABLE whse_basemapping.fwa_obstructions_sp (
    obstruction_id integer PRIMARY KEY,
    watershed_group_id integer,
    linear_feature_id integer,
    gnis_id integer,
    gnis_name character varying(80),
    obstruction_type character varying(20),
    blue_line_key integer,
    watershed_key integer,
    fwa_watershed_code character varying(143),
    local_watershed_code character varying(143),
    watershed_group_code character varying(4),
    route_measure double precision,
    feature_source character varying(15),
    feature_code character varying(10),
    geom public.geometry(Point,3005),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED,
    localcode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((local_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED
);

CREATE INDEX ON whse_basemapping.fwa_obstructions_sp (linear_feature_id);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp (blue_line_key);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp (watershed_key);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp (obstruction_type);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp (gnis_name);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp USING GIST (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp USING BTREE (localcode_ltree);
CREATE INDEX ON whse_basemapping.fwa_obstructions_sp USING GIST (geom);