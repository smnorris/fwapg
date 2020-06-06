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