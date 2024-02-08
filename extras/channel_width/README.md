# Modelled channel width

Most channel width predictors used by this script are available in the FWA, but it also requires Mean Annual Precipitation (MAP) from ClimateBC be downloaded and integraged with the FWA - run scripts in ../precipitation first.


## Channel width

Channel width is derived via three methods:

- measured: field measurements of channel width are available from FISS and PSCIS (averaging measurements where more than one is available for the same stream)
- mapped: we can derive the width of FWA river polygons (measuring the width between banks at intervals and averaging the result)
- modelled: calculate the modelled channel width based on upstream area and mean annual precipitation

To run these calculations and load the data:

    make

Note that a modelled channel width is generated for *all* segments in the stream network where no field measurement or river polygon is available. Filter the results as per your requirements (ie, remove network connections where a channel width value does not make sense - lakes, wetlands, etc)

## Output 

Chanel width is recorded once per linear_feature_id. A single value per stream is retained, with descending order of priority being measured, mapped, modelled.

```
        Table "whse_basemapping.fwa_stream_networks_channel_width"
        Column        |       Type       | Collation | Nullable | Default
----------------------+------------------+-----------+----------+---------
 linear_feature_id    | bigint           |           | not null |
 channel_width_source | text             |           |          |
 channel_width        | double precision |           |          |
Indexes:
    "fwa_stream_networks_channel_width_pkey" PRIMARY KEY, btree (linear_feature_id)
```


## References

- Thorley, J.L., Norris, S. & Irvine A. (2021) [*Channel Width 2021b. A Poisson Consulting Analysis Appendix*](https://www.poissonconsulting.ca/f/859859031)