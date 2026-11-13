-- named streams need st_linemerge to be properly labelled, plus add smoothing to help as well

BEGIN;
 
  TRUNCATE whse_basemapping.fwa_named_streams;

  INSERT INTO whse_basemapping.fwa_named_streams
    (gnis_name, blue_line_key, stream_order, watershed_group_code, geom)
  SELECT
    str.gnis_name,
    str.blue_line_key,
    max(str.stream_order),
    str.watershed_group_code,
    ST_Multi(
      ST_Force2D(
        ST_ChaikinSmoothing(
          ST_SimplifyPreserveTopology(
            ST_LineMerge(
              ST_Union(str.geom)
            ),
            25
          ),
          2
        )
      )
    ) AS geom
  FROM whse_basemapping.fwa_stream_networks_sp str
  LEFT OUTER JOIN whse_basemapping.fwa_lakes_poly lk
  ON str.waterbody_key = lk.waterbody_key
  LEFT OUTER JOIN whse_basemapping.fwa_manmade_waterbodies_poly mmwb
  ON str.waterbody_key = mmwb.waterbody_key
  WHERE gnis_name IS NOT NULL
  AND lk.waterbody_key IS NULL
  AND mmwb.waterbody_key IS NULL
  AND str.edge_type != 1450
  GROUP BY str.gnis_name, str.blue_line_key, str.watershed_group_code;
 
COMMIT;
