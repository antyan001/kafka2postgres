#!/bin/sh -e

. ./versions.sh
. ./load.env.sh

if [ $# -lt 1 ]; then
    echo 1>&2 "$0: Not enough arguments. Starting kafka broker with default values."
    $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties 2>&1>/dev/null &
else

    IFS=" "; for id in $@; do
        DEFAULT_PORT=$KAFKA_PORT
        PORT=$(($DEFAULT_PORT + $id))

        BROKER_ID="$id"
        LOG_LOCATION=$KAFKA_LOG_DIRS/kafka-$BROKER_ID-logs

        echo "Starting Kafka Server with BrokerId=$BROKER_ID on port=$PORT"

        $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties \
                --override broker.id=$BROKER_ID \
                --override listeners=PLAINTEXT://:$PORT \
                --override port=$PORT \
                --override log.dirs=$LOG_LOCATION  2>&1>/dev/null &
    done
fi
