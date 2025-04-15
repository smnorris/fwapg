# Relate Salmon Conservation Units (CU) to FWA streams


## Processing

1. Download the CUs at [https://data.salmonwatersheds.ca](https://data.salmonwatersheds.ca/result?datasetid=104) (requires a free account) and extract to `pse_conservation_units.gdb`

2. Load to database, planarize the polygons, relate CUs to FWA streams:


        ./pse_conservation_units.sh


## Output

```
          Table "psf.pse_conservation_units_streams"
      Column       |  Type   | Collation | Nullable | Default
-------------------+---------+-----------+----------+---------
 linear_feature_id | bigint  |           |          |
 cuid              | integer |           |          |
```

## Usage

Join streams to CUs as required. 

For example, find length of all streams associated with CU 289 (Morice) and CU 287 (Bulkley):

```
  select 
    cu.cuid,
    round((sum(st_length(s.geom)) / 1000)::numeric, 2) as length_km
  from bcfishpass.streams s
  join dfo.pse_conservation_units_streams cu using (linear_feature_id)
  where cu.cuid in (289, 287)
  group by cu.cuid;

   cuid | length_km
------+-----------
  287 |   9371.30
  289 |  11538.96
(2 rows)
  
```  