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

echo "stop docker compose service: ${DOCKER_SERVICE_LIST[*]}"

compose_down "${DOCKER_SERVICE_LIST[@]}"
