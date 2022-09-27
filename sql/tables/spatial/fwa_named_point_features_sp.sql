delete from whse_basemapping.fwa_named_point_features_sp;
insert into whse_basemapping.fwa_named_point_features_sp (
  named_point_feature_id,
  gnis_id,
  gnis_name,
  named_feature_type,
  feature_code,
  geom
)
select
  named_point_feature_id::integer as named_point_feature_id,
  gnis_id::integer as gnis_id,
  gnis_name,
  named_feature_type,
  feature_code,
  (st_dump(geom)).geom as geom
from fwapg.fwa_named_point_features_sp;
