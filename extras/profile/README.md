# Stream profile

Extracting a stream profile and/or gradient from FWA geometries is a straightforward, but often repeated task.
Run the required query once and materialize the result in table `whse_basemapping.fwa_stream_profiles` for re-use.

## Process

	./process.sh

## Output	

	                 Table "whse_basemapping.fwa_stream_profiles"
	          Column          |       Type       | Collation | Nullable | Default
	--------------------------+------------------+-----------+----------+---------
	 blue_line_key            | integer          |           |          |
	 downstream_route_measure | double precision |           |          |
	 upstream_route_measure   | double precision |           |          |
	 downstream_elevation     | double precision |           |          |
	 upstream_elevation       | double precision |           |          |

