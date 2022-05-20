#!/bin/bash -e

export KAFKA_HOME=/root/kafka
export SCALA_VERSION=2.13
export KAFKA_VERSION=3.1.0
export FILENAME="kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"

export HOSTNAME_COMMAND="route -n | awk '/UG[ \t]/{print \$2}'"

export KAFKA_PORT=9092
export KAFKA_ZOOKEEPER_PORT=2181
export KAFKA_BROKER_ID=1
export KAFKA_CREATE_TOPICS=Topic1:1:3,Topic2:1:1:compact
export KAFKA_CREATE_TOPICS_SEPARATOR=","
export KAFKA_ZOOKEEPER_CONNECT=zookeeper:2181
#export KAFKA_ADVERTISED_HOST_NAME=localhost
export KAFKA_ADVERTISED_LISTENERS=INSIDE://:9093,OUTSIDE://_{HOSTNAME_COMMAND}:9092
#export KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://broker:29092,PLAINTEXT_HOST://localhost:9092
export KAFKA_LISTENERS=INSIDE://:9093,OUTSIDE://:9092
export KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=INSIDE:PLAINTEXT,OUTSIDE:PLAINTEXT
#export KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
#export KAFKA_INTER_BROKER_LISTENER_NAME=INSIDE
export KAFKA_INTER_BROKER_LISTENER_NAME=PLAINTEXT
export KAFKA_AUTO_CREATE_TOPICS_ENABLE=true
export KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1
export KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1
export KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1
export KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS=100

if [[ -z "$KAFKA_PORT" ]]; then
    export KAFKA_PORT=9092
fi

#if [[ -z "$KAFKA_ADVERTISED_PORT" && \
#  -z "$KAFKA_LISTENERS" && \
#  -z "$KAFKA_ADVERTISED_LISTENERS" && \
#  -S /var/run/docker.sock ]]; then
#    KAFKA_ADVERTISED_PORT=$(docker port "$(hostname)" $KAFKA_PORT | sed -r 's/.*:(.*)/\1/g' | head -n1)
#    export KAFKA_ADVERTISED_PORT
#fi

if [[ -n "$HOSTNAME_COMMAND" ]]; then
    HOSTNAME_VALUE=$(eval "$HOSTNAME_COMMAND")

    # Replace any occurrences of _{HOSTNAME_COMMAND} with the value
    IFS=$'\n'
    for VAR in $(env); do
        if [[ $VAR =~ ^KAFKA_ && "$VAR" =~ "_{HOSTNAME_COMMAND}" ]]; then
            eval "export ${VAR//_\{HOSTNAME_COMMAND\}/$HOSTNAME_VALUE}"
        fi
    done
    IFS=$ORIG_IFS
fi

# Try and configure minimal settings or exit with error if there isn't enough information
if [[ -z "$KAFKA_LISTENERS" ]]; then
    if [[ -n "$KAFKA_ADVERTISED_LISTENERS" ]]; then
        echo "ERROR: Missing environment variable KAFKA_LISTENERS. Must be specified when using KAFKA_ADVERTISED_LISTENERS"
        exit 1
    elif [[ -z "$HOSTNAME_VALUE" ]]; then
        echo "ERROR: No listener or advertised hostname configuration provided in environment."
        echo "       Please define KAFKA_LISTENERS / (deprecated) KAFKA_ADVERTISED_HOST_NAME"
        exit 1
    fi

    # Maintain existing behaviour
    # If HOSTNAME_COMMAND is provided, set that to the advertised.host.name value if listeners are not defined.
    export KAFKA_ADVERTISED_HOST_NAME="$HOSTNAME_VALUE"
fi

if [[ -z "$KAFKA_BROKER_ID" ]]; then
    if [[ -n "$BROKER_ID_COMMAND" ]]; then
        KAFKA_BROKER_ID=$(eval "$BROKER_ID_COMMAND")
        export KAFKA_BROKER_ID
    else
        # By default auto allocate broker ID
        export KAFKA_BROKER_ID=-1
    fi
fi

if [[ -z "$KAFKA_LOG_DIRS" ]]; then
    export KAFKA_LOG_DIRS="$KAFKA_HOME/kafka-logs"
fi

if [[ -n "$KAFKA_HEAP_OPTS" ]]; then
    sed -r -i 's/(export KAFKA_HEAP_OPTS)="(.*)"/\1="'"$KAFKA_HEAP_OPTS"'"/g' "$KAFKA_HOME/bin/kafka-server-start.sh"
    unset KAFKA_HEAP_OPTS
fi

