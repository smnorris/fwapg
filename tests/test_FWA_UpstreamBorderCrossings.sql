-- sooke
SELECT FWA_UpstreamBorderCrossings(354153927, 100) IS NULL as result;

-- sooke lake - lake outlet precision issues
SELECT FWA_UpstreamBorderCrossings(354153927, 19912) IS NULL as result;

-- tamihi (chilliwack)
SELECT FWA_UpstreamBorderCrossings(356346812, 10800) = 'USA_49' as result;

-- similkameen
SELECT FWA_UpstreamBorderCrossings(356570170, 116410) = 'USA_49' as result;

-- kettle
SELECT FWA_UpstreamBorderCrossings(356570045, 141000) = 'USA_49' as result;

-- pouce coupe
SELECT FWA_UpstreamBorderCrossings(359566563, 99248) = 'AB_120' as result;

-- liard
SELECT FWA_UpstreamBorderCrossings(359573055, 519779) = 'YTNWT_60' as result;