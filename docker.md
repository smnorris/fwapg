# Docker

Download the repo, create containers, create database, load data:

    git clone https://github.com/smnorris/fwapg.git
    cd fwapg
    docker compose build
    docker compose up -d
    docker compose run --rm loader make --debug=basic

(note that docker images specified in `docker-compose.yml` may not be available on ARM based systems)

The database (`$PGDATA`) is written to `postgres-data` - even if containers are deleted, the database will be retained here.
If you have shut down Docker or the container, start it up again with this command:

    docker-compose up -d

Connect to the db from your host OS via the port specified in `docker-compose.yml`:

    psql -p 8000 -U postgres fwapg

Once data is loaded, see it in the browser as vector tiles/geojson features:

    http://localhost:7800/
    http://localhost:9000/

Stop the containers (without deleting):

    docker compose stop

Delete the containers:

    docker compose down

