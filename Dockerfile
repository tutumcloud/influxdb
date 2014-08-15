FROM ubuntu:trusty
MAINTAINER Feng Honglin <hfeng@tutum.co>
 
# Install InfluxDB
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y wget
RUN wget -P /tmp http://s3.amazonaws.com/influxdb/influxdb_latest_amd64.deb && dpkg -i /tmp/influxdb_latest_amd64.deb && rm /tmp/influxdb_latest_amd64.deb

ADD config.toml /config/config.toml

# Admin server
EXPOSE 8083

# HTTP API
EXPOSE 8086

# HTTPS API
EXPOSE 8084

# Raft port (for clustering, don't expose publicly!)
#EXPOSE 8090

# Protobuf port (for clustering, don't expose publicly!)
#EXPOSE 8099

VOLUME ["/data"]

CMD ["/usr/bin/influxdb", "-config=/config/config.toml"]
