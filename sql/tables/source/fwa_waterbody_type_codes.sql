drop table if exists whse_basemapping.fwa_waterbody_type_codes;

create table whse_basemapping.fwa_waterbody_type_codes (
    waterbody_type character varying(1),
    waterbody_description character varying(180)
);

insert into whse_basemapping.fwa_waterbody_type_codes
select waterbody_type, waterbody_description
from fwapg.fwa_waterbody_type_codes;