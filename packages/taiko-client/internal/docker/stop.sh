#!/bin/bash

source scripts/common.sh

DOCKER_SERVICE_LIST=("l1_node" "l2_execution_engine" "l2_execution_engine_geth")

echo "stop docker compose service: ${DOCKER_SERVICE_LIST[*]}"

compose_down "${DOCKER_SERVICE_LIST[@]}"
