import pgdata
import psycopg2

db = pgdata.connect()

# create new table
db.execute("DROP TABLE IF EXISTS whse_basemapping.fwa_stream_networks_sp_upstr_area")
db.execute("CREATE TABLE whse_basemapping.fwa_stream_networks_sp_upstr_area (linear_feature_id bigint primary key, upstream_area_ha double precision)")
groups = [
    r[0]
    for r in db.query(
        """
        SELECT watershed_group_code
        FROM whse_basemapping.fwa_watershed_groups_poly
        ORDER BY watershed_group_code
        """
    )
]

# use a raw connection so that our queries are not wrapped in transactions -
# postgres will therefore clear the on disk temp files and we won't run out of disk space...
conn = psycopg2.connect("")

# insert per watershed group
for wsg in groups:
    print(wsg)
    cur = conn.cursor()
    cur.execute(db.queries["add_upstream_area_ha"], (wsg,))
    conn.commit()
    cur.close()


# above just creates a table with upstream areas, load this to the streams table
db.execute("DROP TABLE IF EXISTS whse_basemapping.fwa_stream_networks_sp_tmp")
db.execute("CREATE TABLE whse_basemapping.fwa_stream_networks_sp_tmp (LIKE whse_basemapping.fwa_stream_networks_sp INCLUDING ALL)")
for wsg in groups:
    print(wsg)
    cur = conn.cursor()
    sql = """INSERT INTO whse_basemapping.fwa_stream_networks_sp_tmp
    (linear_feature_id, watershed_group_id,
      edge_type, blue_line_key, watershed_key, fwa_watershed_code, local_watershed_code,
      watershed_group_code, downstream_route_measure, length_metre, feature_source, gnis_id, gnis_name,
      left_right_tributary, stream_order, stream_magnitude, waterbody_key, blue_line_key_50k,
      watershed_code_50k, watershed_key_50k, watershed_group_code_50k, feature_code, upstream_area_ha, geom)
    SELECT
      s.linear_feature_id,
      s.watershed_group_id,
      s.edge_type,
      s.blue_line_key,
      s.watershed_key,
      s.fwa_watershed_code,
      s.local_watershed_code,
      s.watershed_group_code,
      s.downstream_route_measure,
      s.length_metre,
      s.feature_source,
      s.gnis_id,
      s.gnis_name,
      s.left_right_tributary,
      s.stream_order,
      s.stream_magnitude,
      s.waterbody_key,
      s.blue_line_key_50k,
      s.watershed_code_50k,
      s.watershed_key_50k,
      s.watershed_group_code_50k,
      s.feature_code,
      u.upstream_area_ha,
      s.geom
    FROM whse_basemapping.fwa_stream_networks_sp s
    LEFT OUTER JOIN whse_basemapping.fwa_stream_networks_sp_upstr_area u
    ON s.linear_feature_id = u.linear_feature_id
    WHERE s.watershed_group_code = %s
    """
    cur.execute(sql, (wsg,))
    conn.commit()
    cur.close()

conn.close()

db.execute("ALTER TABLE whse_basemapping.fwa_stream_networks_sp RENAME TO fwa_stream_networks_sp_deleteme")
db.execute("ALTER TABLE whse_basemapping.fwa_stream_networks_sp_tmp RENAME TO fwa_stream_networks_sp")
db.execute("DROP TABLE whse_basemapping.fwa_stream_networks_sp_upstr_area")
print("Processing complete.")
print("If all looks good, drop temp streams table: whse_basemapping.fwa_stream_networks_sp_deleteme")

