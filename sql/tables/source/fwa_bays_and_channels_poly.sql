CREATE TABLE IF NOT EXISTS whse_basemapping.fwa_bays_and_channels_poly (
    bay_and_channel_id integer PRIMARY KEY,
    bay_channel_type character varying(14),
    gnis_id integer,
    gnis_name character varying(80),
    area_ha double precision,
    feature_code character varying(10),
    geom geometry
);

CREATE INDEX ON whse_basemapping.fwa_bays_and_channels_poly (gnis_name);
CREATE INDEX ON whse_basemapping.fwa_bays_and_channels_poly USING GIST(geom);