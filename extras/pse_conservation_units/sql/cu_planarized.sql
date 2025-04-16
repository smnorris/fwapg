-- conservation units are a complex set of overlapping and discontinous polygons
-- simplify queries by flattening into a planarized/non-overlapping geometries

drop table if exists psf.pse_conservation_units_planarized;

create table psf.pse_conservation_units_planarized (
  id serial primary key,
  cuids integer[],
  geom geometry(Polygon, 3005)
);


-- dump poly rings and convert to lines
with rings as
(
  SELECT
    ST_Exteriorring((ST_DumpRings((st_dump(geom)).geom)).geom) AS geom
  FROM psf.pse_conservation_units
),

-- node the lines with st_union and dump to singlepart lines
lines as
(
  SELECT
    (st_dump(st_union(geom, .1))).geom as geom
  FROM rings
),

-- polygonize the resulting noded lines
flattened AS
(
  SELECT
    (ST_Dump(ST_Polygonize(geom))).geom AS geom
  FROM lines
)

-- get the id and aggregate
insert into psf.pse_conservation_units_planarized
  (cuids, geom)
SELECT
  array_agg(cuid order by cuid) as cuids,
  f.geom
FROM flattened f
LEFT OUTER JOIN psf.pse_conservation_units cu
ON ST_Contains(cu.geom, ST_PointOnSurface(f.geom))
group by f.geom;

create index on psf.pse_conservation_units_planarized using gist (geom);