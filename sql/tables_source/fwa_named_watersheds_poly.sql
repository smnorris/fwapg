CREATE TABLE whse_basemapping.fwa_named_watersheds_poly (
    named_watershed_id integer PRIMARY KEY,
    gnis_id integer,
    gnis_name character varying(80),
    blue_line_key integer,
    watershed_key integer,
    fwa_watershed_code character varying(143),
    stream_order integer,
    stream_magnitude integer,
    area_ha double precision,
    feature_code character varying(10),
    geom public.geometry(MultiPolygon,3005),
    wscode_ltree public.ltree GENERATED ALWAYS AS ((replace(replace((fwa_watershed_code)::text, '-000000'::text, ''::text), '-'::text, '.'::text))::public.ltree) STORED
);


CREATE INDEX ON whse_basemapping.fwa_named_watersheds_poly (gnis_name);
CREATE INDEX ON whse_basemapping.fwa_named_watersheds_poly (blue_line_key);
CREATE INDEX ON whse_basemapping.fwa_named_watersheds_poly (fwa_watershed_code);
CREATE INDEX ON whse_basemapping.fwa_named_watersheds_poly USING GIST (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_named_watersheds_poly USING BTREE (wscode_ltree);
CREATE INDEX ON whse_basemapping.fwa_named_watersheds_poly USING GIST (geom);