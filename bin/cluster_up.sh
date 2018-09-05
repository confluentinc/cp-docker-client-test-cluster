#!/usr/bin/env bash

DOCKER_BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DOCKER_BIN}/../.env

await_http() {
    local exit_code
    local attempt=0

    curl -s "$2" > /dev/null; exit_code=$?
    while [ "${exit_code}" -ne 0 ] && [ "${attempt}" -lt 5 ]; do
        echo "awaiting $1..."
        curl -s "$2" > /dev/null; exit_code=$?
        let "attempt+=1"
        sleep 5
    done

    if [ ${exit_code} -eq "0" ]; then
        return
    fi

    echo "$1 readiness test failed aborting..."
    exit 1
}

echo "Configure Environment..."
source ${DOCKER_SOURCE}/.env

echo "Generate SSL certs..."
${DOCKER_BIN}/certify.sh

echo "Deploying cluster..."
docker-compose -f ${DOCKER_CONTEXT} up -d

echo "Setting throttle for throttle test..."
docker-compose -f ${DOCKER_CONTEXT} exec kafka sh -c "
        /usr/bin/kafka-configs  --zookeeper zookeeper:2181 \
                --alter --add-config 'producer_byte_rate=1,consumer_byte_rate=1,request_percentage=001' \
                --entity-name throttled_client --entity-type clients"

await_http "schema-registry" "http://localhost:8081"
await_http "schema-registry-basic-auth" "http://localhost:8083"
