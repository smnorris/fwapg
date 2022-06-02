DROP TABLE IF EXISTS whse_basemapping.fwa_edge_type_codes;

CREATE TABLE whse_basemapping.fwa_edge_type_codes (
    edge_type bigint,
    edge_description character varying(100)
);

insert into whse_basemapping.fwa_edge_type_codes
select edge_type, edge_description
from fwapg.fwa_edge_type_codes;