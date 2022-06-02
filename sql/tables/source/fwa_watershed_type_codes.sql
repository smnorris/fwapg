drop table if exists whse_basemapping.fwa_watershed_type_codes;

create table whse_basemapping.fwa_watershed_type_codes (
    watershed_type character varying(1),
    watershed_description character varying(255)
);

insert into whse_basemapping.fwa_watershed_type_codes
select watershed_type, watershed_description
from whse_basemapping.fwa_watershed_type_codes;