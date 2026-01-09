-- apply attribute fixes that have not yet made it in to the production database

BEGIN;

    --
    -- STREAMS
    -- 
	-- Birkenhead River, coding problem due to distributary
	UPDATE whse_basemapping.fwa_stream_networks_sp
	SET local_watershed_code = fwa_watershed_code
	WHERE linear_feature_id IN (701704850,701705120,701705172,701705231,701704801,701705079,701705158,701704795,701704635,701705099);

	-- Scar Creek
	UPDATE whse_basemapping.fwa_stream_networks_sp
	SET local_watershed_code = fwa_watershed_code
	WHERE linear_feature_id = 66063417;

	-- Kaouk River
	UPDATE whse_basemapping.fwa_stream_networks_sp
	SET local_watershed_code = '930-665189-814505-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000'
	WHERE linear_feature_id IN (710531051, 710530976, 710530984);

	UPDATE whse_basemapping.fwa_stream_networks_sp
	SET local_watershed_code = '930-665189-862690-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000'
	WHERE linear_feature_id = 710530993;

	-- Memekay
	UPDATE whse_basemapping.fwa_stream_networks_sp
	SET local_watershed_code = '920-722273-347291-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000'
	WHERE linear_feature_id IN (710445801, 710446876);

	--
    -- WATERSHEDS
    -- 
    -- From Dan Weller, DFO
    -- This is the only watershed in BC with a valid non-999 ws code but with a 999 for local code (which doesn't make sense).
    -- This update works to match neighbour wsd but it may make more sense to simply remove this watershed (plus the other two nearby polys (7949160,9343507))
    -- that form inner rings with the greater watershed with this wscode?  That can be left up to the province.
    UPDATE whse_basemapping.fwa_watersheds_poly
    SET local_watershed_code = '100.190442.506118.553154.518315.909924.867616.125039.561050.938874'
    WHERE watershed_feature_id = 9633006
    
    -- this fix associates the watershed with the correct stream but it appears as if the better fix
    -- would be to split 10380498 and include the south portion within 10373702
    UPDATE whse_basemapping.fwa_watersheds_poly
    SET local_watershed_code = fwa_watershed_code
    WHERE watershed_feature_id = 10380498;

COMMIT;