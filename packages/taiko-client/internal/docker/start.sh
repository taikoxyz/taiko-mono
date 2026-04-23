#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

source "$PROJECT_ROOT/scripts/common.sh"

# Default to l2_geth if L2_NODE is not set (preserves backward compatibility with dev_net)
L2_NODE="${L2_NODE:-l2_geth}"

# Support multiple L2 node types
case "$L2_NODE" in
  l2_geth)
    DOCKER_SERVICE_LIST=("l1_node" "l2_geth")
    ;;
  l2_reth)
    DOCKER_SERVICE_LIST=("l1_node" "l2_reth")
    ;;
  l2_nmc)
    DOCKER_SERVICE_LIST=("l1_node" "l2_nmc")
    # For NMC, we need to dynamically inject the uzenTimestamp into the chainspec
    # because Nethermind uses a static chainspec file unlike taiko-geth which uses CLI flags.
    # We use a template file to avoid modifying the original and to ensure clean state on each run.
    NMC_CHAINSPEC_DIR="$PROJECT_ROOT/internal/docker/nodes/nmc/chainspec"
    NMC_CHAINSPEC_TEMPLATE="${NMC_CHAINSPEC_DIR}/taiko-devnet.template.json"
    NMC_CHAINSPEC="${NMC_CHAINSPEC_DIR}/taiko-devnet.json"
    
    if [ -f "$NMC_CHAINSPEC_TEMPLATE" ]; then
      SHASTA_HEX=$(printf "0x%x" 0)
      UZEN_HEX=$(printf "0x%x" 0)
      echo "Generating NMC chainspec with shastaTimestamp=$SHASTA_HEX (Shasta active from genesis), uzenTimestamp=$UZEN_HEX (Uzen active from genesis)"
      # Generate chainspec from template with dynamic shastaTimestamp and uzenTimestamp
      jq --arg shasta "$SHASTA_HEX" --arg uzen "$UZEN_HEX" \
        '.engine.Taiko.shastaTimestamp = $shasta | .engine.Taiko.uzenTimestamp = $uzen' \
        "$NMC_CHAINSPEC_TEMPLATE" > "$NMC_CHAINSPEC"
    fi
    ;;
  *)
    echo "Error: Unknown L2_NODE: '$L2_NODE'. Supported values: l2_geth, l2_reth, l2_nmc"
    exit 1
    ;;
esac

# start docker compose services
echo "starting docker compose service: ${DOCKER_SERVICE_LIST[*]}"

compose_up "${DOCKER_SERVICE_LIST[@]}"

# show all the running containers
echo
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}\t{{.Status}}"
