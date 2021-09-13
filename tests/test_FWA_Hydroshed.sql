-- Test FWA_hydroshed. It should work anywhere in North America.
-- Lets work the db and request the Yukon River
SELECT ROUND(ST_Area(FWA_hydroshed(8120247210))::numeric) = 833037431420 as result;