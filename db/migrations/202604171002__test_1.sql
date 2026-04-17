BEGIN;
 
	select count(*) from whse_basemapping.fwa_stream_networks_sp;
	create table fwapg.temp (id integer, name text);
 
COMMIT;
