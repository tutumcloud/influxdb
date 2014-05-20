tutum-docker-influxdb
=====================
InfluxDB image


Usage
-----

To create the image `tutum/influxdb`, execute the following command on tutum-docker-influxdb folder:

    docker build -t tutum/influxdb .

You can now push new image to the registry:
    
    docker push tutum/influxdb


Running your InfluxDB image
--------------------------

Start your image binding the external ports `8083`, `8086`, `8090`, and `8099` in all interface to your container:
    
    docker run -d -p 8083:8083 -p 8086:8086 -p 8090:8090 -p 8099:8099 tutum/influxdb

Feel free to remove any port that you don't want to expose.


Configuring your InfluxDB
-------------------------
Open your browse to access `localhost:8083` to configure InfluxDB. The default credential is `root:root`. Please change it as soon as possible.

Alternatively, you can use RESTful API to talk to InfluxDB on port `8086`
