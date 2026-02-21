#!/bin/bash

source scripts/common.sh

# Default to l2_geth if L2_NODE is not set (preserves backward compatibility with dev_net)
L2_NODE="${L2_NODE:-l2_geth}"

# Support multiple L2 node types
case "$L2_NODE" in
  l2_geth)
    DOCKER_SERVICE_LIST=("l1_node" "l2_geth")
    ;;
  l2_nmc)
    DOCKER_SERVICE_LIST=("l1_node" "l2_nmc")
    # For NMC, we need to dynamically inject the shastaTimestamp into the chainspec
    # because Nethermind uses a static chainspec file unlike taiko-geth which uses CLI flags.
    # We use a template file to avoid modifying the original and to ensure clean state on each run.
    NMC_CHAINSPEC_DIR="internal/docker/nodes/nmc/chainspec"
    NMC_CHAINSPEC_TEMPLATE="${NMC_CHAINSPEC_DIR}/taiko-devnet.template.json"
    NMC_CHAINSPEC="${NMC_CHAINSPEC_DIR}/taiko-devnet.json"
    
    if [ -n "${TAIKO_INTERNAL_SHASTA_TIME:-}" ] && [ -f "$NMC_CHAINSPEC_TEMPLATE" ]; then
      SHASTA_HEX=$(printf "0x%x" "$TAIKO_INTERNAL_SHASTA_TIME")
      echo "Generating NMC chainspec with shastaTimestamp=$SHASTA_HEX (decimal: $TAIKO_INTERNAL_SHASTA_TIME)"
      # Generate chainspec from template with dynamic shastaTimestamp
      jq --arg ts "$SHASTA_HEX" '.engine.Taiko.shastaTimestamp = $ts' "$NMC_CHAINSPEC_TEMPLATE" > "$NMC_CHAINSPEC"
    fi
    ;;
  *)
    echo "Error: Unknown L2_NODE: '$L2_NODE'. Supported values: l2_geth, l2_nmc"
    exit 1
    ;;
esac

# start docker compose services
echo "starting docker compose service: ${DOCKER_SERVICE_LIST[*]}"

compose_up "${DOCKER_SERVICE_LIST[@]}"

# show all the running containers
echo
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}\t{{.Status}}"
