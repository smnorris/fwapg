FROM osgeo/gdal:ubuntu-small-3.4.0

RUN apt-get update && apt-get --assume-yes upgrade \
&& apt-get -qq install -y --no-install-recommends make \
&& apt-get -qq install -y --no-install-recommends wget \
&& apt-get -qq install -y --no-install-recommends zip \
&& apt-get -qq install -y --no-install-recommends unzip \
&& apt-get -qq install -y --no-install-recommends parallel

RUN apt-get -qq install -y --no-install-recommends postgresql-common \
&& apt-get -qq install -y --no-install-recommends yes \
&& apt-get -qq install -y --no-install-recommends gnupg \
&& yes '' | sh /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh \
&& apt-get -qq install -y --no-install-recommends postgresql-client-14 \
&&  apt-get -qq install -y --no-install-recommends python3-pip python3-psycopg2 \
&& apt-get -qq install -y --no-install-recommends git \
&& pip3 install --upgrade numpy \
&& pip3 install bcdata minio

# install bcdata, its such a fat image already don't see point in
# breaking up into two step build
RUN python3 -m pip install bcdata minio

WORKDIR /home/fwapg
COPY ["sql", "sql/"]
COPY ["extras", "extras/"]
COPY [".env.docker", "Makefile", "./"]