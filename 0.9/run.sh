#!/bin/bash

set -m
CONFIG_FILE="/config/config.toml"
INFLUX_HOST="localhost"
INFLUX_API_PORT="8086"
API_URL="http://${INFLUX_HOST}:${INFLUX_API_PORT}"
ADMIN=${ADMIN_USER:-root}
PASS=${INFLUXDB_INIT_PWD:-root}

wait_for_start_of_influxdb(){
    #wait for the startup of influxdb
    RET=1
    while [[ RET -ne 0 ]]; do
        echo "=> Waiting for confirmation of InfluxDB service startup ..."
        sleep 3
        curl -k ${API_URL}/ping 2> /dev/null
        RET=$?
    done
}


# Dynamically change the value of 'max-open-shards' to what 'ulimit -n' returns
sed -i "s/^max-open-shards.*/max-open-shards = $(ulimit -n)/" ${CONFIG_FILE}

# Configure InfluxDB Cluster
if [ -n "${FORCE_HOSTNAME}" ]; then
    if [ "${FORCE_HOSTNAME}" == "auto" ]; then
        #set hostname with IPv4 eth0
        HOSTIPNAME=$(ip a show dev eth0 | grep inet | grep eth0 | sed -e 's/^.*inet.//g' -e 's/\/.*$//g')
        /usr/bin/perl -p -i -e "s/hostname = \"localhost\"/hostname = \"${HOSTIPNAME}\"/g" ${CONFIG_FILE}
    else
        /usr/bin/perl -p -i -e "s/hostname = \"localhost\"/hostname = \"${FORCE_HOSTNAME}\"/g" ${CONFIG_FILE}
    fi
fi

# NOTE: 'seed-servers.' is nowhere to be found in config.toml, this cannot work anymore! NEED FOR REVIEW!
# if [ -n "${SEEDS}" ]; then
#     SEEDS=$(eval SEEDS=$SEEDS ; echo $SEEDS | grep '^\".*\"$' || echo "\""$SEEDS"\"" | sed -e 's/, */", "/g')
#     /usr/bin/perl -p -i -e "s/^# seed-servers.*$/seed-servers = [${SEEDS}]/g" ${CONFIG_FILE}
# fi

if [ -n "${REPLI_FACTOR}" ]; then
    /usr/bin/perl -p -i -e "s/replication-factor = 1/replication-factor = ${REPLI_FACTOR}/g" ${CONFIG_FILE}
fi

if [ "${PRE_CREATE_DB}" == "**None**" ]; then
    unset PRE_CREATE_DB
fi

# NOTE: It seems this is not used anymore...
#
# if [ "${SSL_CERT}" == "**None**" ]; then
#     unset SSL_CERT
# fi
#
# if [ "${SSL_SUPPORT}" == "**False**" ]; then
#     unset SSL_SUPPORT
# fi

# Add Graphite support
if [ -n "${GRAPHITE_DB}" ]; then
    echo "GRAPHITE_DB: ${GRAPHITE_DB}"
    sed -i -r -e "/^\[\[graphite\]\]/, /^$/ { s/false/true/; s/\"graphitedb\"/\"${GRAPHITE_DB}\"/g; }" ${CONFIG_FILE}
fi

if [ -n "${GRAPHITE_BINDING}" ]; then
    echo "GRAPHITE_BINDING: ${GRAPHITE_BINDING}"
    sed -i -r -e "/^\[\[graphite\]\]/, /^$/ { s/\:2003/${GRAPHITE_BINDING}/; }" ${CONFIG_FILE}
fi

if [ -n "${GRAPHITE_PROTOCOL}" ]; then
    echo "GRAPHITE_PROTOCOL: ${GRAPHITE_PROTOCOL}"
    sed -i -r -e "/^\[\[graphite\]\]/, /^$/ { s/tcp/${GRAPHITE_PROTOCOL}/; }" ${CONFIG_FILE}
fi

if [ -n "${GRAPHITE_TEMPLATE}" ]; then
    echo "GRAPHITE_TEMPLATE: ${GRAPHITE_TEMPLATE}"
    sed -i -r -e "/^\[\[graphite\]\]/, /^$/ { s/instance\.profile\.measurement\*/${GRAPHITE_TEMPLATE}/; }" ${CONFIG_FILE}
fi

# Add Collectd support
if [ -n "${COLLECTD_DB}" ]; then
    echo "COLLECTD_DB: ${COLLECTD_DB}"
    sed -i -r -e "/^\[collectd\]/, /^$/ { s/false/true/; s/( *)# *(.*)\"collectd\"/\1\2\"${COLLECTD_DB}\"/g;}" ${CONFIG_FILE}
fi
if [ -n "${COLLECTD_BINDING}" ]; then
    echo "COLLECTD_BINDING: ${COLLECTD_BINDING}"
    sed -i -r -e "/^\[collectd\]/, /^$/ { s/( *)# *(.*)\":25826\"/\1\2\"${COLLECTD_BINDING}\"/g;}" ${CONFIG_FILE}
fi
if [ -n "${COLLECTD_RETENTION_POLICY}" ]; then
    echo "COLLECTD_RETENTION_POLICY: ${COLLECTD_RETENTION_POLICY}"
    sed -i -r -e "/^\[collectd\]/, /^$/ { s/( *)# *(retention-policy.*)\"\"/\1\2\"${COLLECTD_RETENTION_POLICY}\"/g;}" ${CONFIG_FILE}
fi

# Add UDP support
if [ -n "${UDP_DB}" ]; then
    sed -i -r -e "/^\[\[udp\]\]/, /^$/ { s/false/true/; s/#//g; s/\"udpdb\"/\"${UDP_DB}\"/g; }" ${CONFIG_FILE}
fi
if [ -n "${UDP_PORT}" ]; then
    sed -i -r -e "/^\[\[udp\]\]/, /^$/ { s/4444/${UDP_PORT}/; }" ${CONFIG_FILE}
fi


if [ -f "/data/.init_script_executed" ]; then
    echo "=> The initialization script had been executed before, skipping ..."
else
    echo "=> Starting InfluxDB in background ..."
    if [ -n "${JOIN}" ]; then
        exec influxd -config=${CONFIG_FILE} -join ${JOIN} &
    else
        exec influxd -config=${CONFIG_FILE} &
    fi

    wait_for_start_of_influxdb

    #Create the admin user
    if [ -n "${ADMIN_USER}" ] || [ -n "${INFLUXDB_INIT_PWD}" ]; then
        echo "=> Creating admin user"
        influx -host=${INFLUX_HOST} -port=${INFLUX_API_PORT} -execute="CREATE USER ${ADMIN} WITH PASSWORD '${PASS}' WITH ALL PRIVILEGES"
    fi

    # Pre create database on the initiation of the container
    if [ -n "${PRE_CREATE_DB}" ]; then
        echo "=> About to create the following database: ${PRE_CREATE_DB}"
        arr=$(echo ${PRE_CREATE_DB} | tr ";" "\n")

        for x in $arr
        do
            echo "=> Creating database: ${x}"
            echo "CREATE DATABASE ${x}" >> /tmp/init_script.influxql
        done
    fi

    # Execute influxql queries contained inside /init_script.influxql
    if [ -f "/init_script.influxql" ] || [ -f "/tmp/init_script.influxql" ]; then
        echo "=> About to execute the initialization script"

        cat /init_script.influxql >> /tmp/init_script.influxql

        echo "=> Executing the influxql script..."
        influx -host=${INFLUX_HOST} -port=${INFLUX_API_PORT} -username=${ADMIN} -password="${PASS}" -import -path /tmp/init_script.influxql

        echo "=> Influxql script executed."
        touch "/data/.init_script_executed"
    else
        echo "=> No initialization script need to be executed"
    fi

    echo "=> Stopping InfluxDB ..."
    if ! kill -s TERM %1 || ! wait %1; then
        echo >&2 'InfluxDB init process failed.'
        exit 1
    fi
fi

echo "=> Starting InfluxDB in foreground ..."
if [ -n "${JOIN}" ]; then
    exec influxd -config=${CONFIG_FILE} -join ${JOIN}
else
    exec influxd -config=${CONFIG_FILE}
fi
