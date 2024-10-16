#!/bin/bash

source scripts/common.sh

if [ "$L2_NODE" == "l2_reth" ];then
    DOCKER_SERVICE_LIST=("l1_node" "l2_reth")
  elif [ "$L2_NODE" == "l2_geth" ];then
    DOCKER_SERVICE_LIST=("l1_node" "l2_geth")
  else
    echo "unsupported L2_NODE: $L2_NODE"
    exit 1
fi

# start docker compose service list
echo "start docker compose service: ${DOCKER_SERVICE_LIST[*]}"

compose_up "${DOCKER_SERVICE_LIST[@]}"

# show all the running containers
echo
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}\t{{.Status}}"
