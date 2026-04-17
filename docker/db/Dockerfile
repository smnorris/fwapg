FROM postgis/postgis:16-3.5

COPY db/schema.sql /docker-entrypoint-initdb.d/01_schema.sql

COPY docker/db/search_path.sh /docker-entrypoint-initdb.d/02_search_path.sh
RUN chmod +x /docker-entrypoint-initdb.d/02_search_path.sh