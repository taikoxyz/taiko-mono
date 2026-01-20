#!/bin/bash

source scripts/common.sh

# Support multiple L2 node types
case "$L2_NODE" in
  l2_geth)
    DOCKER_SERVICE_LIST=("l1_node" "l2_geth")
    ;;
  l2_nmc)
    DOCKER_SERVICE_LIST=("l1_node" "l2_nmc")
    ;;
  *)
    echo "Error: Unknown L2_NODE: '$L2_NODE'. Supported values: l2_geth, l2_nmc"
    exit 1
    ;;
esac

echo "stop docker compose service: ${DOCKER_SERVICE_LIST[*]}"

compose_down "${DOCKER_SERVICE_LIST[@]}"
