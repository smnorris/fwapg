# Modelled channel width

Most channel width predictors used by this script are available in the FWA, but it also requires Mean Annual Precipitation (MAP) from ClimateBC be downloaded and integraged with the FWA - run scripts in ../precipitation first.


## Channel width

Channel width is derived via three methods:

- mapped: we can derive the width of FWA river polygons (measuring the width between banks at intervals and averaging the result)
- measured: field measurements of channel width are available from FISS and PSCIS (averaging measurements where more than one is available for the same stream)
- modelled: calculate the modelled channel width based on upstream area and mean annual precipitation

To run these calculations and load the data:

    make

Note that a modelled channel width is generated for *all* segments in the stream network where no field measurement or river polygon is available. Filter the results as per your requirements (ie, remove network connections where a channel width value does not make sense - lakes, wetlands, etc)

## Output tables

```
Table "bcfishpass.channel_width_mapped"
        Column        |       Type       | Collation | Nullable | Default
----------------------+------------------+-----------+----------+---------
 linear_feature_id    | bigint           |           | not null |
 watershed_group_code | text             |           |          |
 channel_width_mapped | double precision |           |          |
Indexes:
    "channel_width_mapped_pkey" PRIMARY KEY, btree (linear_feature_id)


Table "bcfishpass.channel_width_measured"
         Column         |       Type       | Collation | Nullable |                                   Default
------------------------+------------------+-----------+----------+-----------------------------------------------------------------------------
 channel_width_id       | integer          |           | not null | nextval('bcfishpass.channel_width_measured_channel_width_id_seq'::regclass)
 stream_sample_site_ids | integer[]        |           |          |
 stream_crossing_ids    | integer[]        |           |          |
 wscode_ltree           | ltree            |           |          |
 localcode_ltree        | ltree            |           |          |
 watershed_group_code   | text             |           |          |
 channel_width_measured | double precision |           |          |

Indexes:
    "channel_width_measured_pkey" PRIMARY KEY, btree (channel_width_id)
    "channel_width_measured_wscode_ltree_localcode_ltree_key" UNIQUE CONSTRAINT, btree (wscode_ltree, localcode_ltree)
    "channel_width_measured_localcode_ltree_idx" gist (localcode_ltree)
    "channel_width_measured_localcode_ltree_idx1" btree (localcode_ltree)
    "channel_width_measured_wscode_ltree_idx" gist (wscode_ltree)
    "channel_width_measured_wscode_ltree_idx1" btree (wscode_ltree)


Table "bcfishpass.channel_width_modelled"
         Column         |       Type       | Collation | Nullable |                                   Default
------------------------+------------------+-----------+----------+-----------------------------------------------------------------------------
 channel_width_id       | integer          |           | not null | nextval('bcfishpass.channel_width_modelled_channel_width_id_seq'::regclass)
 wscode_ltree           | ltree            |           |          |
 localcode_ltree        | ltree            |           |          |
 watershed_group_code   | text             |           |          |
 channel_width_modelled | double precision |           |          |
Indexes:
    "channel_width_modelled_pkey" PRIMARY KEY, btree (channel_width_id)
    "channel_width_modelled_wscode_ltree_localcode_ltree_key" UNIQUE CONSTRAINT, btree (wscode_ltree, localcode_ltree)
    "channel_width_modelled_localcode_ltree_idx" gist (localcode_ltree)
    "channel_width_modelled_localcode_ltree_idx1" btree (localcode_ltree)
    "channel_width_modelled_wscode_ltree_idx" gist (wscode_ltree)
    "channel_width_modelled_wscode_ltree_idx1" btree (wscode_ltree)
```


## References

- Thorley, J.L., Norris, S. & Irvine A. (2021) [*Channel Width 2021b. A Poisson Consulting Analysis Appendix*](https://www.poissonconsulting.ca/f/859859031)