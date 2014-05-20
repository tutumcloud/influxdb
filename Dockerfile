FROM ubuntu:trusty
MAINTAINER Feng Honglin <hfeng@tutum.co>
 
# Install InfluxDB
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y wget
RUN wget http://s3.amazonaws.com/influxdb/influxdb_latest_amd64.deb
RUN sudo dpkg -i influxdb_latest_amd64.deb

ADD run.sh /run.sh
RUN chmod 755 /*.sh

EXPOSE 8083 
EXPOSE 8086 
EXPOSE 8090 
EXPOSE 8099

CMD ["/run.sh"]
