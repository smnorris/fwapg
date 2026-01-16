.. fwapg documentation master file, created by
   sphinx-quickstart on Thu Sep  9 14:56:55 2021.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

fwapg
=================================

``fwapg`` extends British Columbia's `Freshwater Atlas <https://www2.gov.bc.ca/gov/content/data/geographic-data-services/topographic-data/freshwater>`_ (FWA) with PostgreSQL/PostGIS. ``fwapg`` provides additional tables, indexes and functions to:

- quickly translate arbitrary point locations (``X,Y``) to a linear reference positions (``blue_line_key, measure``) on the stream network
- enable speedy upstream/downstream queries throughout BC
- quickly and cleanly generate watershed boundaries upstream of arbitrary locations
- enable cross-boundary queries by combining FWA data with data from neighbouring jurisdictions
- enable querying of FWA features via spatial SQL
- provide ``gradient`` values for every FWA stream
- enable quickly serving FWA features as vector tiles (MVT) via ``pg_tileserv``
- enable quickly serving FWA features and custom fwapg functions via ``pg_featureserv``



.. toctree::
   :maxdepth: 2
   :caption: Contents:

   01_usage
   02_tables_views
   03_functions
