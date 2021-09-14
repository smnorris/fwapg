# Usage

## Upstream/Downstream

Use `fwa_upstream()` and `fwa_downstream` functions to relate different tables based on a record's position on the network.

For example, find out how many Coho fish observations (referenced to the network using bcfishobs) are upstream of the mouths of several rivers of interest:

```

SELECT
  obstruction_id
FROM whse_basemapping.fwa_obstructions_sp a
INNER JOIN whse_basemapping.fwa_stream_networks_sp b
ON fwa_upstream(
    a.blue_line_key::integer,
    a.route_measure::double precision,
    a.wscode_ltree,
    a.localcode_ltree,
    b.blue_line_key::integer,
    b.downstream_route_measure:: double precision,
    b.wscode_ltree,
    b.localcode_ltree)
WHERE a.wscode_ltree <@ '930.055749'::ltree
AND b.wscode_ltree <@ '930.055749'::ltree
GROUP BY obstruction_id

