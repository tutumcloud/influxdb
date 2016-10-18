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

    tutum/influxdb:latest -> influxdb 1.0
    tutum/influxdb:0.13   -> influxdb 0.13.x
    tutum/influxdb:0.12   -> influxdb 0.12.x
    tutum/influxdb:0.10   -> influxdb 0.10.x
    tutum/influxdb:0.9    -> influxdb 0.9.x
    tutum/influxdb:0.8.8  -> influxdb 0.8.8

Running your InfluxDB image
---------------------------

Start your image binding the external ports `8083` and `8086` in all interfaces to your container. Ports `8090` and `8099` are only used for clustering and should not be exposed to the internet:

    docker run -d -p 8083:8083 -p 8086:8086 tutum/influxdb

`Docker` containers are easy to delete. If you delete your container instance and your cluster goes offline, you'll lose the InfluxDB store and configuration. If you are serious about keeping InfluxDB data persistently, then consider adding a volume mapping to the containers `/data` folder:

    docker run -d --volume=/var/influxdb:/data -p 8083:8083 -p 8086:8086 tutum/influxdb

**Note**: `influxdb:0.9` is **NOT** backwards compatible with `0.8.x`. If you need version `0.8.x`, please run:

    docker run -d -p 8083:8083 -p 8086:8086 tutum/influxdb:0.8.8

Configuring your InfluxDB
-------------------------
Open your browser to access `localhost:8083` to configure InfluxDB. Fill the port which maps to `8086`. *There is no default user anymore in version 0.9 but you can set `auth-enabled: true` in the config.toml.*

Alternatively, you can use RESTful API to talk to InfluxDB on port `8086`. For example, if you have problems with the initial database creation for version `0.9.x`, you can use the new `influx` cli tool to configure the database. While the container is running, you launch the tool with the following command:

  ```
  docker exec -ti influxdb-container-name /usr/bin/influx
  Visit https://enterprise.influxdata.com to register for updates, InfluxDB server management, and monitoring.
  Connected to http://localhost:8086 version 0.9.6.1
  InfluxDB shell 0.9.6.1
  >
  ```

Initially create Database
-------------------------
Use `-e PRE_CREATE_DB="db1;db2;db3"` to create database named "db1", "db2", and "db3" on the first time the container starts automatically. Each database name is separated by `;`. For example:

```docker run -d -p 8083:8083 -p 8086:8086 -e ADMIN_USER="root" -e INFLUXDB_INIT_PWD="somepassword" -e PRE_CREATE_DB="db1;db2;db3" tutum/influxdb:latest```

Alternatively, create a database and user with the InfluxDB 0.9 shell:

```
  > CREATE DATABASE db1
  > SHOW DATABASES
  name: databases
  ---------------
  name
  db1
  > USE db1
  > CREATE USER root WITH PASSWORD 'somepassword' WITH ALL PRIVILEGES
  > GRANT ALL PRIVILEGES ON db1 TO root
  > SHOW USERS
  user  admin
  root  true
```
For additional Administration methods with the InfluxDB 0.9 shell, check out the [`Administration`](https://influxdb.com/docs/v0.9/administration/administration.html) guide on the InfluxDB website.


Initially execute influxql script (Available only in influxdb:0.9)
------------------------------------------------------------
Use `-v /tmp/init_script.influxql:init_script.influxql:ro` if you want that script to been executed on the first time the container starts automatically. Each influxql command on separated line. For example:

- Docker run command
```
docker run -d -p 8083:8083 -p 8086:8086 -e ADMIN_USER="root" -e INFLUXDB_INIT_PWD="somepassword" -v /tmp/init_script.influxql:init_script.influxql:ro tutum/influxdb:latest
```

- The influxdb script
```
CREATE DATABASE mydb
CREATE USER writer WITH PASSWORD 'writerpass'
CREATE USER reader WITH PASSWORD 'readerpass'
GRANT WRITE ON mydb TO writer
GRANT READ ON mydb TO reader
```

SSL support (Available only in influxdb:0.8.8)
---------------------------------------------
By default, Influx DB uses port 8086 for HTTP API. If you want to use SSL API, you can set `SSL_SUPPORT` to `true`  as an environment variable. In that case, you can use HTTP API on port 8086 and HTTPS API on port 8084. Please do not publish port 8086 if you want to only allow HTTPS connection.

If you provide `SSL_CERT`, system will use user provided SSL certificate. Otherwise the system will create a self-signed certificate, which usually has an unauthorized certificate error, not recommend.

The cert file should be a combination of Private Key and Public Certificate. In order to pass it as an environment variable, you need specifically convert `newline` to `\n`(two characters). In order to do this, you can simply run the command `awk 1 ORS='\\n' <your_cert.pem>`. For example:

```docker run -d -p 8083:8083 -p 8084:8084 -e SSL_SUPPORT="True" -e SSL_CERT="`awk 1 ORS='\\n' ~/cert.pem`" tutum/influxdb:latest```


Graphite API support
----------------------------------------
InfluxDB has plugin to support the [Graphite Carbon API](http://graphite.readthedocs.org/en/1.0/feeding-carbon.html). This can be customized via the following variables:

- GRAPHITE_DB: name of the database the graphite plugin shall write the incoming metrics to
- GRAPHITE_BINDING: by default the graphite plugin listens on ':2003'. You can provide any `ipaddress:port`
- GRAPHITE_PROTOCOL: 'udp' or 'tcp' (default)
- GRAPHITE_TEMPLATE: By default the template is set to `instance.profile.measurement*` which will parse a metric and create tags from it

```docker run -d -p 8083:8083 -p 8086:8086 -p 2015:2015 -e ADMIN_USER="root" -e INFLUXDB_INIT_PWD="somepassword" -e PRE_CREATE_DB=my_db -e GRAPHITE_DB="my_db" -e GRAPHITE_BINDING=':2015' -e GRAPHITE_PROTOCOL="udp" -e GRAPHITE_template="tag1.tag2.tag3.measurement*" tutum/influxdb```

More details on the configuration of InfluxDB's graphite plugin can be found at: https://github.com/influxdb/influxdb/blob/master/services/graphite/README.md


Collectd support
----------------------------------------
InfluxDB has a plugin to support the [collectd network plugin](https://collectd.org/wiki/index.php/Plugin:Network). This can be customized via the following variables:

- COLLECTD_DB: name of the database the collectd plugin shall write the incoming metrics to
- COLLECTD_BINDING: by default the collectd plugin listens on ':25826'. You can provide any `ipaddress:port`
- COLLECTD_RETENTION_POLICY: custom retention policy
- types.db: default types.db from collectd version 5.5.0 is provided. For custom types consider adding a volume mapping for /usr/share/collectd/types.db

```docker run -d -p 8083:8083 -p 8086:8086 -p 25826:25826/udp -e ADMIN_USER="root" -e INFLUXDB_INIT_PWD="somepassword" -e PRE_CREATE_DB=my_db -e COLLECTD_DB="my_db" -e COLLECTD_BINDING=':25826' -e COLLECTD_RETENTION_POLICY="mypolicy" tutum/influxdb```

More details on the configuration of InfluxDB's collectd plugin can be found at: https://github.com/influxdb/influxdb/blob/master/services/collectd/README.md


UDP support
----------------------------------------
If you provide a `UDP_DB`, influx will open a UDP port (4444 or if provided `UDP_PORT`) for reception of events for the named database.

```docker run -d -p 8083:8083 -p 8086:8086 -p 4444:4444/udp --expose 8090 --expose 8099 --expose 4444 -e UDP_DB="my_db" tutum/influxdb```

Clustering (Available in influxdb:0.9.4.2-1)
----------------------------------------

```bash
# (make sure firewall allows ports 8088, 8089)
docker run -p 8088:8088 -e FORCE_HOSTNAME=192.168.0.1:8088 -t tutum/influxdb
docker run -p 8089:8088 -e FORCE_HOSTNAME=192.168.0.1:8089 -e JOIN=192.168.0.1:8088 -t tutum/influxdb
```


Clustering (Available in influxdb:0.8.8)
----------------------------------------
Use :

* `-e SEEDS="host1:8090, host2:8090"` to pass seeds nodes to your container.
* `-e REPLI_FACTOR=x` where x is the replicator factor of shards through the cluster (defaults to 1)
* `-e FORCE_HOSTNAME="auto"` to force the hostname in the config file to be set to the container IPv4 eth0 address (useful to test clustering on a single docker host)
* `-e FORCE_HOSTNAME="<whatever>" ` to force the hostname in the config file to be set to 'whatever'

Example on a single docker host:

* Launch first container:
```
docker run -p 8083:8083 -p 8086:8086 --expose 8090 --expose 8099 \
  -e FORCE_HOSTNAME="auto" -e REPLI_FACTOR=2 \
  -d --name masterinflux tutum/influxdb
```
* Then launch one or more "slaves":
```
docker run --link masterinflux:master -p 8083 -p 8086 --expose 8090 --expose 8099 \
  -e SEEDS="master:8090" -e FORCE_HOSTNAME="auto" \
  -d  tutum/influxdb
```
