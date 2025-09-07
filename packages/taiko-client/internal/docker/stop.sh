#!/bin/bash

source scripts/common.sh

if [ "$L2_NODE" == "l2_geth" ];then
    DOCKER_SERVICE_LIST=("l1_node" "l2_geth" "postgresql" "protocol_indexer")
  else
    DOCKER_SERVICE_LIST=("l1_node" "postgresql" "protocol_indexer")
fi

echo "stop docker compose service: ${DOCKER_SERVICE_LIST[*]}"

compose_down "${DOCKER_SERVICE_LIST[@]}"
