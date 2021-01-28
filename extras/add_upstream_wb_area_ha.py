import pgdata
import psycopg2


def create_temp_table():
    # create new table
    db = pgdata.connect()
    db.execute("DROP TABLE IF EXISTS whse_basemapping.temp_upstream_wb_area_ha")
    db.execute(
        """
        CREATE TABLE whse_basemapping.temp_upstream_wb_area_ha
        (linear_feature_id bigint primary key,
         upstream_lake_ha double precision,
         upstream_reservoir_ha double precision,
         upstream_wetland_ha double precision)
        """
    )
    groups = [
        r[0]
        for r in db.query(
            """
            SELECT watershed_group_code
            FROM whse_basemapping.fwa_watershed_groups_poly
            WHERE watershed_group_code in ('BULK','MORR','HORS','LNIC','ELKR')
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
        cur.execute(db.queries["temp_upstream_wb_area_ha"], (wsg,))
        conn.commit()
        cur.close()


def apply_updates():
    """apply updates rather than re-loading to another temp table"""
    db = pgdata.connect()
    # add new columns if not present
    db.execute("ALTER TABLE whse_basemapping.fwa_stream_networks_sp ADD COLUMN IF NOT EXISTS upstream_lake_ha double precision")
    db.execute("ALTER TABLE whse_basemapping.fwa_stream_networks_sp ADD COLUMN IF NOT EXISTS upstream_reservoir_ha double precision")
    db.execute("ALTER TABLE whse_basemapping.fwa_stream_networks_sp ADD COLUMN IF NOT EXISTS upstream_wetland_ha double precision")
    groups = [
        r[0]
        for r in db.query(
            """
            SELECT watershed_group_code
            FROM whse_basemapping.fwa_watershed_groups_poly
            WHERE watershed_group_code in ('BULK','MORR','HORS','LNIC','ELKR')
            ORDER BY watershed_group_code
            """
        )
    ]
    conn = psycopg2.connect("")
    for wsg in groups:
        print(wsg)
        cur = conn.cursor()
        cur.execute(db.queries["update_upstream_wb_area_ha"], (wsg,))
        conn.commit()
        cur.close()


create_temp_table()
apply_updates()
# drop temp table when done
