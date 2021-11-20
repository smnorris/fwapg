FROM osgeo/gdal:ubuntu-small-3.4.0

RUN apt-get -qq install -y --no-install-recommends make
RUN apt-get -qq install -y --no-install-recommends wget
RUN apt-get -qq install -y --no-install-recommends zip
RUN apt-get -qq install -y --no-install-recommends unzip
RUN apt-get -qq install -y --no-install-recommends parallel
RUN apt-get -qq install -y --no-install-recommends postgresql-common
RUN apt-get -qq install -y --no-install-recommends yes
RUN apt-get -qq install -y --no-install-recommends gnupg
RUN yes '' | sh /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
RUN apt-get -qq install -y --no-install-recommends postgresql-client-14

WORKDIR /home/fwapg