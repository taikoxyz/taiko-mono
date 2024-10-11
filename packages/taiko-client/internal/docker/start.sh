#!/bin/bash

source scripts/common.sh

DOCKER_SERVICE_LIST=("l1_node" "l2_execution_engine" "l2_execution_engine_geth")

# start docker compose service list
echo "start docker compose service: ${DOCKER_SERVICE_LIST[*]}"

compose_up "${DOCKER_SERVICE_LIST[@]}"

# show all the running containers
echo
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}\t{{.Status}}"
