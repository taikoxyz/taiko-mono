#!/bin/bash

# Docker entrypoint script for protocol-indexer

# Set default values if not provided
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:rindexer@localhost:5432/protocol_indexer}"
LOCAL_RPC="${LOCAL_RPC:-http://localhost:8545}"
HOLESKY_RPC="${HOLESKY_RPC:-http://localhost:8545}"
ETHEREUM_RPC="${ETHEREUM_RPC:-http://localhost:8545}"

# Export environment variables
export DATABASE_URL
export LOCAL_RPC
export HOLESKY_RPC
export ETHEREUM_RPC

echo "Starting Protocol Indexer..."
echo "Database: $DATABASE_URL"
echo "Local RPC: $LOCAL_RPC"
echo "Holesky RPC: $HOLESKY_RPC"
echo "Ethereum RPC: $ETHEREUM_RPC"
echo ""

# Run the compiled binary with all arguments
exec /usr/local/bin/protocol_indexer "$@"
