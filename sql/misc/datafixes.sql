-- Birkenhead River, coding problem due to distributary
UPDATE fwapg.fwa_stream_networks_sp
SET local_watershed_code = fwa_watershed_code
WHERE linear_feature_id IN (701704850,701705120,701705172,701705231,701704801,701705079,701705158,701704795,701704635,701705099);

-- Scar Creek
UPDATE fwapg.fwa_stream_networks_sp
SET local_watershed_code = fwa_watershed_code
WHERE linear_feature_id = 66063417;

-- Kaouk River
UPDATE fwapg.fwa_stream_networks_sp
SET local_watershed_code = '930-665189-814505-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000'
WHERE linear_feature_id IN (710531051, 710530976, 710530984);

UPDATE fwapg.fwa_stream_networks_sp
SET local_watershed_code = '930-665189-862690-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000'
WHERE linear_feature_id = 710530993;

-- Memekay
UPDATE fwapg.fwa_stream_networks_sp
SET local_watershed_code = '920-722273-347291-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000-000000'
WHERE linear_feature_id IN (710445801, 710446876);

-- local code is not populated in obstruction table, get it from streams
UPDATE fwapg.fwa_obstructions_sp o
SET local_watershed_code = s.local_watershed_code
FROM fwapg.fwa_stream_networks_sp s
WHERE o.linear_feature_id = s.linear_feature_id;