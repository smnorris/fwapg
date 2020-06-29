import pgdata

db = pgdata.connect()

# add new column
db.execute(
    """
    ALTER TABLE whse_basemapping.fwa_stream_networks_sp
    ADD COLUMN IF NOT EXISTS upstream_area_ha double precision
    """
)


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

# run updates in order, running in parallel creates conflicting locks
# updating the entire streams table takes quite some time
for wsg in groups:
    print(wsg)
    db.execute(db.queries["add_upstream_area"], (wsg,))
