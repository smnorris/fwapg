-- relate CUs to FWA streams
drop table if exists whse_basemapping.fwa_streams_pse_conservation_units_lut;

create table whse_basemapping.fwa_streams_pse_conservation_units_lut (
	linear_feature_id bigint,
	cuid integer
);

insert into whse_basemapping.fwa_streams_pse_conservation_units_lut (
  linear_feature_id,
  cuid
)
select distinct
  s.linear_feature_id,
  unnest(cu.cuids) as cuid
from bcfishpass.streams s
-- Find streams that properly intersect (not just touch) a poly (Interior Intersects)
inner join psf.pse_conservation_units_planarized cu on s.geom && cu.geom AND ST_Relate(cu.geom, s.geom,'T********')
left outer join bcfishpass.habitat_linear_ch ch on s.segmented_stream_id = ch.segmented_stream_id
left outer join bcfishpass.habitat_linear_cm cm on s.segmented_stream_id = cm.segmented_stream_id
left outer join bcfishpass.habitat_linear_co co on s.segmented_stream_id = co.segmented_stream_id
left outer join bcfishpass.habitat_linear_pk pk on s.segmented_stream_id = pk.segmented_stream_id
left outer join bcfishpass.habitat_linear_sk sk on s.segmented_stream_id = sk.segmented_stream_id
left outer join bcfishpass.habitat_linear_co st on s.segmented_stream_id = st.segmented_stream_id;