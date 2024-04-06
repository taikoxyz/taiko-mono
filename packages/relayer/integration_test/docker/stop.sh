#!/bin/bash

source integration_test/common.sh

DOCKER_SERVICE_LIST=("l1_node" "l2_execution_engine" "db" "rabbitmq")

echo "stop docker compose service: ${DOCKER_SERVICE_LIST[*]}"

compose_down "${DOCKER_SERVICE_LIST[@]}"
