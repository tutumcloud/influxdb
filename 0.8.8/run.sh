#!/bin/bash

set -m
CONFIG_FILE="/config/config.toml"

# Dynamically change the value of 'max-open-shards' to what 'ulimit -n' returns
sed -i "s/^max-open-shards.*/max-open-shards = $(ulimit -n)/" ${CONFIG_FILE}

# Configure InfluxDB Cluster
if [ -n "${FORCE_HOSTNAME}" ]; then
    if [ "${FORCE_HOSTNAME}" == "auto" ]; then
        #set hostname with IPv4 eth0
        HOSTIPNAME=$(ip a show dev eth0 | grep inet | grep eth0 | sed -e 's/^.*inet.//g' -e 's/\/.*$//g')
        /usr/bin/perl -p -i -e "s/^# hostname.*$/hostname = \"${HOSTIPNAME}\"/g" ${CONFIG_FILE}
    else
        /usr/bin/perl -p -i -e "s/^# hostname.*$/hostname = \"${FORCE_HOSTNAME}\"/g" ${CONFIG_FILE}
    fi
fi

if [ -n "${SEEDS}" ]; then
    SEEDS=$(eval SEEDS=$SEEDS ; echo $SEEDS | grep '^\".*\"$' || echo "\""$SEEDS"\"" | sed -e 's/, */", "/g')
    /usr/bin/perl -p -i -e "s/^# seed-servers.*$/seed-servers = [${SEEDS}]/g" ${CONFIG_FILE}
fi

if [ -n "${REPLI_FACTOR}" ]; then
    /usr/bin/perl -p -i -e "s/replication-factor = 1/replication-factor = ${REPLI_FACTOR}/g" ${CONFIG_FILE}
fi

if [ "${PRE_CREATE_DB}" == "**None**" ]; then
    unset PRE_CREATE_DB
fi

if [ "${SSL_CERT}" == "**None**" ]; then
    unset SSL_CERT
fi

if [ "${SSL_SUPPORT}" == "**False**" ]; then
    unset SSL_SUPPORT
fi

# Add UDP support
if [ -n "${UDP_DB}" ]; then
    sed -i -r -e "/^\s+\[input_plugins.udp\]/, /^$/ { s/false/true/; s/#//g; s/\"\"/\"${UDP_DB}\"/g; }" ${CONFIG_FILE}
fi
if [ -n "${UDP_PORT}" ]; then
    sed -i -r -e "/^\s+\[input_plugins.udp\]/, /^$/ { s/4444/${UDP_PORT}/; }" ${CONFIG_FILE}
fi

# SSL SUPPORT (Enable https support on port 8084)
API_URL="http://localhost:8086"
CERT_PEM="/cert.pem"
SUBJECT_STRING="/C=US/ST=NewYork/L=NYC/O=Tutum/CN=*"
if [ -n "${SSL_SUPPORT}" ]; then
    echo "=> SSL Support enabled, using SSl api ..."
    echo "=> Listening on port 8084(https api), disabling port 8086(http api)"
    if [ -n "${SSL_CERT}" ]; then 
        echo "=> Use user uploaded certificate"
        echo -e "${SSL_CERT}" > ${CERT_PEM}
    else
        echo "=> Use self-signed certificate"
        if [  -f ${CERT_PEM} ]; then
            echo "=> Certificate found, skip ..."
        else
            echo "=> Generating certificate ..."
            openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj ${SUBJECT_STRING} -keyout /server.key -out /server.crt >/dev/null 2>&1
            cat /server.key /server.crt > ${CERT_PEM}
            rm -f /server.key /server.crt
        fi
    fi
    sed -i -r -e 's/^# ssl-/ssl-/g' ${CONFIG_FILE}
fi


# Pre create database on the initiation of the container
if [ -n "${PRE_CREATE_DB}" ]; then
    echo "=> About to create the following database: ${PRE_CREATE_DB}"
    if [ -f "/data/.pre_db_created" ]; then
        echo "=> Database had been created before, skipping ..."
    else
        echo "=> Starting InfluxDB ..."
        exec /usr/bin/influxdb -config=${CONFIG_FILE} &
        PASS=${INFLUXDB_INIT_PWD:-root}
        arr=$(echo ${PRE_CREATE_DB} | tr ";" "\n")

        #wait for the startup of influxdb
        RET=1
        while [[ RET -ne 0 ]]; do
            echo "=> Waiting for confirmation of InfluxDB service startup ..."
            sleep 3 
            curl -k ${API_URL}/ping 2> /dev/null
            RET=$?
        done
        echo ""

        for x in $arr
        do
            echo "=> Creating database: ${x}"
            curl -s -k -X POST -d "{\"name\":\"${x}\"}" $(echo ${API_URL}'/db?u=root&p='${PASS})
        done
        echo ""

        touch "/data/.pre_db_created"
        fg
        exit 0
    fi
else
    echo "=> No database need to be pre-created"
fi

echo "=> Starting InfluxDB ..."

exec /usr/bin/influxdb -config=${CONFIG_FILE}
