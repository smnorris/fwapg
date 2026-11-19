-- river in LILL, at the head of the blue line (top segment's length_metre is shorter than its geometry)
SELECT (SELECT area_ha = 12161.69 FROM FWA_WatershedAtMeasure(355992999, 177.92130295900984)) IS TRUE as result;
