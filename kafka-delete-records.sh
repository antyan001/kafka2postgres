#!/usr/bin/env bash

~/kafka/bin/kafka-delete-records.sh --bootstrap-server localhost:9092 --offset-json-file ./offsetfile.json
