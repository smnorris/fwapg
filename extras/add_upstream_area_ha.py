import pgdata


db = pgdata.connect()

# create new table
db.execute("DROP TABLE IF EXISTS whse_basemapping.fwa_stream_networks_sp_tmp")
db.execute("CREATE TABLE whse_basemapping.fwa_stream_networks_sp_tmp (LIKE whse_basemapping.fwa_stream_networks_sp INCLUDING ALL)")
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

# insert per watershed group
# (this could be run in parallel for some more speed)
for wsg in groups:
    print(wsg)
    db.execute(db.queries["add_upstream_area_ha"], (wsg,))


# drop (or rename) exising table and rename new table
db.execute("ALTER TABLE whse_basemapping.fwa_stream_networks_sp RENAME TO fwa_stream_networks_sp_deleteme")
db.execute("ALTER TABLE whse_basemapping.fwa_stream_networks_sp_tmp RENAME TO fwa_stream_networks_sp")