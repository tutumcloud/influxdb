#!/bin/bash

set -m
CONFIG_FILE="/config/config.toml"
#CONFIG_FILE="test"

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

API_URL="http://localhost:8086"
if [ -n "${SSL_CERT}" ]; then 
    echo "=> Found ssl cert file, using ssl api instead"
    echo "=> Listening on port 8084(https api), disabling port 8086(http api)"
    echo -e "${SSL_CERT}" > /cert.pem
    sed -i -r -e 's/^# ssl-/ssl-/g' -e 's/^port *= * 8086/# port = 8086/' ${CONFIG_FILE}
    API_URL="https://localhost:8084"
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
