#!/bin/bash

source scripts/common.sh

if [ "$L2_NODE" == "l2_geth" ];then
    DOCKER_SERVICE_LIST=("l1_node" "l2_geth" "postgresql" "protocol_indexer")
  else
    DOCKER_SERVICE_LIST=("l1_node" "postgresql" "protocol_indexer")
fi

# start docker compose services
echo "starting docker compose service: ${DOCKER_SERVICE_LIST[*]}"

compose_up "${DOCKER_SERVICE_LIST[@]}"

# show all the running containers
echo
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}\t{{.Status}}"
