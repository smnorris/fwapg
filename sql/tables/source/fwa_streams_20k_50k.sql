drop table if exists whse_basemapping.fwa_streams_20k_50k;

create table whse_basemapping.fwa_streams_20k_50k (
    stream_20k_50k_id bigint primary key,
    watershed_group_id_20k integer,
    linear_feature_id_20k bigint,
    blue_line_key_20k integer,
    watershed_key_20k integer,
    fwa_watershed_code_20k character varying(143),
    watershed_group_code_20k character varying(4),
    blue_line_key_50k integer,
    watershed_key_50k integer,
    watershed_code_50k character varying(45),
    watershed_group_code_50k character varying(4),
    match_type character varying(7)
);

insert into whse_basemapping.fwa_streams_20k_50k (
  stream_20k_50k_id,
  watershed_group_id_20k,
  linear_feature_id_20k,
  blue_line_key_20k,
  watershed_key_20k,
  fwa_watershed_code_20k,
  watershed_group_code_20k,
  blue_line_key_50k,
  watershed_key_50k,
  watershed_code_50k,
  watershed_group_code_50k,
  match_type
)
select
  stream_20k_50k_id,
  watershed_group_id_20k,
  linear_feature_id_20k,
  blue_line_key_20k,
  watershed_key_20k,
  fwa_watershed_code_20k,
  watershed_group_code_20k,
  blue_line_key_50k,
  watershed_key_50k,
  watershed_code_50k,
  watershed_group_code_50k,
  match_type
from fwapg.fwa_streams_20k_50k;

create index on whse_basemapping.fwa_streams_20k_50k (watershed_group_id_20k);
create index on whse_basemapping.fwa_streams_20k_50k (linear_feature_id_20k);
create index on whse_basemapping.fwa_streams_20k_50k (watershed_code_50k);