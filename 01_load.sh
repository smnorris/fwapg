ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nln fwa_edge_type_codes \
  FWA.gpkg \
  FWA_EDGE_TYPE_CODES
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nln fwa_streams_20k_50k \
  -lco FID=STREAM_20K_50K_ID \
  -lco FID64=TRUE \
  FWA.gpkg \
  FWA_STREAMS_20K_50K
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nln fwa_waterbodies_20k_50k \
  -lco FID=WATERBODY_20K_50K_ID \
  FWA.gpkg \
  FWA_WATERBODIES_20K_50K
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nln fwa_waterbody_type_codes \
  FWA.gpkg \
  FWA_WATERBODY_TYPE_CODES
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nln fwa_watershed_type_codes \
  FWA.gpkg \
  FWA_WATERSHED_TYPE_CODES
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_assessment_watersheds_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=WATERSHED_FEATURE_ID \
  -dialect SQLITE \
  -sql "SELECT *, REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.') as wscode_ltree, REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.') as localcode_ltree FROM FWA_ASSESSMENT_WATERSHEDS_POLY" \
  FWA.gpkg
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_bays_and_channels_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=BAY_AND_CHANNEL_ID \
  FWA.gpkg \
  FWA_BAYS_AND_CHANNELS_POLY
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTILINESTRING \
  -nln fwa_coastlines_sp \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=LINEAR_FEATURE_ID \
  -dialect SQLITE \
  -sql "SELECT *, REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.') as wscode_ltree, REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.') as localcode_ltree FROM FWA_COASTLINES_SP" \
  FWA.gpkg
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_glaciers_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=WATERBODY_POLY_ID \
  -dialect SQLITE \
  -sql "SELECT *, REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.') as wscode_ltree, REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.') as localcode_ltree FROM FWA_GLACIERS_POLY" \
  FWA.gpkg
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_islands_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=ISLAND_ID \
  -dialect SQLITE \
  -sql "SELECT *, REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.') as wscode_ltree, REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.') as localcode_ltree FROM FWA_ISLANDS_POLY" \
  FWA.gpkg
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_lakes_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=WATERBODY_POLY_ID \
  -dialect SQLITE \
  -sql "SELECT *, REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.') as wscode_ltree, REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.') as localcode_ltree FROM FWA_LAKES_POLY" \
  FWA.gpkg
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_manmade_waterbodies_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=WATERBODY_POLY_ID \
  -dialect SQLITE \
  -sql "SELECT *, REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.') as wscode_ltree, REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.') as localcode_ltree FROM FWA_MANMADE_WATERBODIES_POLY" \
  FWA.gpkg
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOINT \
  -nln fwa_obstructions_sp \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=OBSTRUCTION_ID \
  -dialect SQLITE \
  -sql "SELECT *, REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.') as wscode_ltree, REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.') as localcode_ltree FROM FWA_OBSTRUCTIONS_SP" \
  FWA.gpkg
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_rivers_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=WATERBODY_POLY_ID \
  -dialect SQLITE \
  -sql "SELECT *, REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.') as wscode_ltree, REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.') as localcode_ltree FROM FWA_RIVERS_POLY" \
  FWA.gpkg
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_watershed_groups_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=WATERSHED_GROUP_ID \
  FWA.gpkg \
  FWA_WATERSHED_GROUPS_POLY
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_wetlands_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=WATERBODY_POLY_ID \
  -dialect SQLITE \
  -sql "SELECT *, REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.') as wscode_ltree, REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.') as localcode_ltree FROM FWA_WETLANDS_POLY" \
  FWA.gpkg
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_named_watersheds_poly \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=NAMED_WATERSHED_ID \
  -dialect SQLITE \
  -sql "SELECT *, REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.') as wscode_ltree FROM FWA_NAMED_WATERSHEDS_POLY" \
  FWA.gpkg
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTILINESTRING \
  -nln fwa_linear_boundaries_sp \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco SPATIAL_INDEX=NONE \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=LINEAR_FEATURE_ID \
  -dialect SQLITE \
  -sql "SELECT *, REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.') as wscode_ltree, REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.') as localcode_ltree FROM FWA_LINEAR_BOUNDARIES_SP" \
  FWA.gpkg
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTIPOLYGON \
  -nln fwa_watersheds_poly \
  -t_srs EPSG:3005 \
  -lco SPATIAL_INDEX=NONE \
  -lco GEOMETRY_NAME=geom \
  -dim XY \
  -s_srs EPSG:3005 \
  -lco FID=WATERSHED_FEATURE_ID \
  -dialect SQLITE \
  -sql "SELECT *, REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.') as wscode_ltree, REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.') as localcode_ltree FROM FWA_WATERSHEDS_POLY" \
  FWA.gpkg
ogr2ogr \
  -f PostgreSQL \
  "PG:host=$PGHOST user=$PGUSER dbname=$PGDATABASE port=$PGPORT" \
  -lco OVERWRITE=YES \
  -lco SCHEMA=whse_basemapping \
  -nlt MULTILINESTRING \
  -nln fwa_stream_networks_sp \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -dim XYZ \
  -s_srs EPSG:3005 \
  -lco SPATIAL_INDEX=NONE \
  -lco FID=LINEAR_FEATURE_ID \
  -lco FID64=TRUE \
  -dialect SQLITE \
  -sql "SELECT *, REPLACE(REPLACE(fwa_watershed_code, '-000000', ''), '-', '.') as wscode_ltree, REPLACE(REPLACE(local_watershed_code, '-000000', ''), '-', '.') as localcode_ltree, downstream_route_measure + ST_Length(geom) as upstream_route_measure FROM FWA_STREAM_NETWORKS_SP" \
  FWA.gpkg

echo 'Data load complete, consider removing FWA.gpkg to save disk space'