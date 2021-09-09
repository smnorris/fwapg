CREATE TABLE whse_basemapping.fwa_watershed_groups_poly (
    watershed_group_id integer PRIMARY KEY,
    watershed_group_code character varying(4),
    watershed_group_name character varying(80),
    area_ha double precision,
    feature_code character varying(10),
    geom public.geometry
);

CREATE INDEX ON whse_basemapping.fwa_watershed_groups_poly (watershed_group_code);
CREATE INDEX ON whse_basemapping.fwa_watershed_groups_poly USING GIST (geom);