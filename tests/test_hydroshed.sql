-- Test hydroshed. It should work anywhere in North America.
-- Lets work the db and request the Yukon River
SELECT ROUND(ST_Area(geom)::numeric) = 833037431420 as result
FROM hydroshed(-163.4568, 62.0730, 4326);