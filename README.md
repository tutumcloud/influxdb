tutum-docker-influxdb
=====================

[![Deploy to Tutum](https://s.tutum.co/deploy-to-tutum.svg)](https://dashboard.tutum.co/stack/deploy/)

InfluxDB image


Usage
-----

To create the image `tutum/influxdb`, execute the following command on tutum-docker-influxdb folder:

    docker build -t tutum/influxdb .

You can now push new image to the registry:

    docker push tutum/influxdb
    
Tags
----

    tutum/influxdb:latest -> influxdb 0.9.1
    tutum/influxdb:0.9    -> influxdb 0.9.1
    tutum/influxdb:0.8.8  -> influxdb 0.8.8

Running your InfluxDB image
--------------------------

Start your image binding the external ports `8083` and `8086` in all interfaces to your container. Ports `8090` and `8099` are only used for clustering and should not be exposed to the internet.

    docker run -d -p 8083:8083 -p 8086:8086 tutum/influxdb

**Note**: `influxdb:0.9` is **NOT** backwards compatible with `0.8.x`. If you need version `0.8.x`, please run:

	docker run -d -p 8083:8083 -p 8086:8086 tutum/influxdb:0.8.8


Configuring your InfluxDB
-------------------------
Open your browse to access `localhost:8083` to configure InfluxDB. Fill the port which maps to `8086`. The default credential is `root:root`. Please change it as soon as possible.

Alternatively, you can use RESTful API to talk to InfluxDB on port `8086`


Initially create Database
-------------------------
Use `-e PRE_CREATE_DB="db1;db2;db3"` to create database named "db1", "db2", and "db3" on the first time the container starts automatically. Each database name is separated by `;`. For example:

```docker run -d -p 8083:8083 -p 8084:8084 -e PRE_CREATE_DB="db1;db2;db3" tutum/influxdb:latest```

SSL support (Available only in influxdb:0.8.8)
---------------------------------------------
By default, Influx DB uses port 8086 for HTTP API. If you want to use SSL API, you can set `SSL_SUPPORT` to `true`  as an environment variable. In that case, you can use HTTP API on port 8086 and HTTPS API on port 8084. Please do not publish port 8086 if you want to only allow HTTPS connection.

If you provide `SSL_CERT`, system will use user provided ssl certificate. Otherwise system will create a self-signed certificated, which usually has an unauthorized cerificated problem, not recommend.

The cert file should be an combination of Private Key and Public Certificate. In order to pass it as an environment variable, you need specifically convert `newline` to `\n`(two characters). In order to do this, you can simply run the command `awk 1 ORS='\\n' <your_cert.pem>`. For example:

```docker run -d -p 8083:8083 -p 8084:8084 -e SSL_SUPPORT="True" -e SSL_CERT="`awk 1 ORS='\\n' ~/cert.pem`" tutum/influxdb:latest```

UDP support (Available in influxdb:0.8.8)
----------------------------------------
If you provide a `UDP_DB`, influx will open a UDP port (4444 or if provided `UDP_PORT`) for reception of events for the named database.

```docker run -d -p 8083:8083 -p 8086:8086 --expose 8090 --expose 8099 --expose 4444 -e UDP_DB="my_db" tutum/influxdb```

Clustering (Available in influxdb:0.8.8)
----------------------------------------
Use :

* `-e SEEDS="host1:8090, host2:8090"` to pass seeds nodes to your container.
* `-e REPLI_FACTOR=x` where x is the replicator factor of shards through the cluster (defaults to 1)
* `-e FORCE_HOSTNAME="auto"` to force the hostname in the config file to be set to the container IPv4 eth0 address (usefull to test clustering on a single docker host)
* `-e FORCE_HOSTNAME="<whatever>" ` to force the hostname in the config file to be set to 'whatever'

Example on a single docker host :

* launch first container :
```
docker run -p 8083:8083 -p 8086:8086 --expose 8090 --expose 8099 \
  -e FORCE_HOSTNAME="auto" -e REPLI_FACTOR=2 \
  -d --name masterinflux tutum/influxdb
```
* then launch one or more "slaves":
```
docker run --link masterinflux:master -p 8083 -p 8086 --expose 8090 --expose 8099 \
  -e SEEDS="master:8090" -e FORCE_HOSTNAME="auto" \
  -d  tutum/influxdb
```
