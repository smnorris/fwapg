delete from whse_basemapping.fwa_assessment_watersheds_poly where watershed_group_code = :'wsg';

insert into whse_basemapping.fwa_assessment_watersheds_poly
  (
    watershed_feature_id,
    watershed_group_id,
    watershed_type,
    gnis_id_1,
    gnis_name_1,
    gnis_id_2,
    gnis_name_2,
    gnis_id_3,
    gnis_name_3,
    waterbody_id,
    waterbody_key,
    watershed_key,
    fwa_watershed_code,
    local_watershed_code,
    watershed_group_code,
    left_right_tributary,
    watershed_order,
    watershed_magnitude,
    local_watershed_order,
    local_watershed_magnitude,
    area_ha,
    feature_code,
    geom)
select
    watershed_feature_id,
    watershed_group_id,
    watershed_type,
    gnis_id_1,
    gnis_name_1,
    gnis_id_2,
    gnis_name_2,
    gnis_id_3,
    gnis_name_3,
    waterbody_id,
    waterbody_key,
    watershed_key,
    fwa_watershed_code,
    local_watershed_code,
    watershed_group_code,
    left_right_tributary,
    watershed_order,
    watershed_magnitude,
    local_watershed_order,
    local_watershed_magnitude,
    area_ha,
    feature_code,
    st_multi(ST_SetSRID(geom, 3005)) as geom
from fwapg.fwa_assessment_watersheds_poly
where watershed_group_code = :'wsg';

