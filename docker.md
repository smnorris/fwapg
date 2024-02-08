# Docker

Download the repo, create containers, create database, load fwa data:

    git clone https://github.com/smnorris/fwapg.git
    cd fwapg
    docker-compose build
    docker-compose up -d
    docker-compose run --rm loader psql -c "CREATE DATABASE fwapg" postgres
    docker-compose run --rm loader make --debug=basic

Note that docker images specified in `docker-compose.yml` may not be available on ARM based systems.
As long as you do not remove the container `fwapg-db`, it will retain all the data you put in it.
If you have shut down Docker or the container, start it up again with this command:

    docker-compose up -d

Connect to the db from your host OS via the port specified in `docker-compose.yml`:

    psql -p 8000 -U postgres fwapg

Or see the FWA data in the browser as vector tiles/geojson features:

    http://localhost:7800/
    http://localhost:9000/

Delete the containers (and associated fwa data):

    docker-compose down
