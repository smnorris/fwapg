insert into whse_basemapping.fwa_watershed_type_codes
select watershed_type, watershed_description
from fwapg.fwa_watershed_type_codes;