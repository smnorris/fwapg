-- sooke
SELECT COUNT(*) = 0 as result FROM FWA_UpstreamBorderCrossings(354153927, 100);

-- tamihi (chilliwack)
SELECT DISTINCT border = 'USA_49' as result FROM FWA_UpstreamBorderCrossings(356346812, 10800);

-- similkameen
SELECT DISTINCT border = 'USA_49' as result FROM FWA_UpstreamBorderCrossings(356570170, 116410);

-- kettle
SELECT DISTINCT border = 'USA_49' as result FROM FWA_UpstreamBorderCrossings(356570045, 141000);

-- pouce coupe
SELECT DISTINCT border = 'AB_120' as result FROM FWA_UpstreamBorderCrossings(359566563, 99248);

-- liard
SELECT DISTINCT border = 'YTNWT_60' as result FROM FWA_UpstreamBorderCrossings(359573055, 519779);