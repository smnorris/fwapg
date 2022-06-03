drop table if exists fwapg.fwa_watershed_type_codes;

create table fwapg.fwa_watershed_type_codes (
    watershed_type character varying(1),
    watershed_description character varying(255)
);

insert into fwapg.fwa_watershed_type_codes
select watershed_type, watershed_description
from fwapg.fwa_watershed_type_codes_load;