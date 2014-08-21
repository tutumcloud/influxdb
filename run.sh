#!/bin/bash

set -m
CONFIG_FILE="/config/config.toml"
#set hostname with IPv4 eth0
HOSTIPNAME=$(ip a show dev eth0 | grep inet | grep eth0 | sed -e 's/^.*inet.//g' -e 's/\/.*$//g')
/usr/bin/perl -p -i -e "s/^# hostname.*$/hostname = \"${HOSTIPNAME}\"/g" ${CONFIG_FILE}

if [ -n ${SEEDS} ]; then
	/usr/bin/perl -p -i -e "s/^# seed-servers.*$/seed-servers = [${SEEDS}]/g" ${CONFIG_FILE}
fi

if [ "${PRE_CREATE_DB}" == "**None**" ]; then
    unset PRE_CREATE_DB
fi

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
            curl http://localhost:8086/ping 2> /dev/null
            RET=$?
        done
        echo ""

        for x in $arr
        do
            echo "=> Creating database: ${x}"
            curl -s -X POST -d "{\"name\":\"${x}\"}" $(echo 'http://localhost:8086/db?u=root&p='${PASS})
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
