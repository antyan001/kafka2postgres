#!/bin/sh -e

#KAFKA_HOME=/root/kafka
#SCALA_VERSION=2.13
#KAFKA_VERSION=3.1.0
#FILENAME="kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"

. ./load.env.sh

mkdir -p /root/Downloads/
#curl "https://downloads.apache.org/kafka/3.1.0/kafka_2.13-3.1.0.tgz" -o ~/Downloads/kafka.tgz

url=$(curl --stderr /dev/null "https://www.apache.org/dyn/closer.cgi?path=/kafka/${KAFKA_VERSION}/${FILENAME}&as_json=1" | jq -r '"\(.preferred)\(.path_info)"')

# Test to see if the suggested mirror has this version, currently pre 2.1.1 versions
# do not appear to be actively mirrored. This may also be useful if closer.cgi is down.
if [[ ! $(curl -f -s -r 0-1 "${url}") ]]; then
    echo "Mirror does not have desired version, downloading direct from Apache"
    url="https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/${FILENAME}"
fi

echo "Downloading Kafka from $url"
wget "${url}" -O "/root/Downloads/${FILENAME}"

mkdir -p "$KAFKA_HOME" && cd "$KAFKA_HOME"
tar -xvzf /root/Downloads/$FILENAME --strip 1