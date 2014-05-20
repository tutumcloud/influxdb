#!/bin/bash
CONFIG_FILE_1="/opt/influxdb/shared/config.toml"
CONFIG_FILE_2="/usr/local/etc/influxdb.conf"

if [[ -f $CONFIG_FILE_1 ]]; then
    CONFIG_FILE=$CONFIG_FILE_1
elif [[ -f $CONFIG_FILE_2 ]]; then
    CONFIG_FILE=$CONFIG_FILE_2
else
    echo "=> No configuration file found either in $CONFIG_FILE_1 or $CONFIG_FILE_2"
    CONFIG_FILE=""
fi

if [[ -n CONFIG_FILE ]]; then
    echo "=> Using $CONFIG_FILE to start InfluxDB"
    echo "=> Starting InfluxDB"
    exec /usr/bin/influxdb  -config=$CONFIG_FILE
else
    echo "=> Faild to start InfluxDB"
fi
