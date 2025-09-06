#!/bin/bash

# Script for running the protocol indexer locally with cargo

# Set environment variables
export DATABASE_URL="${DATABASE_URL:-postgresql://postgres:rindexer@localhost:5432/protocol_indexer}"
export LOCAL_RPC="${LOCAL_RPC:-http://localhost:8545}"
export HOLESKY_RPC="${HOLESKY_RPC:-http://localhost:8545}"  # Placeholder - update with actual endpoint
export ETHEREUM_RPC="${ETHEREUM_RPC:-http://localhost:8545}" # Placeholder - update with actual endpoint

echo "Starting Protocol Indexer..."
echo "Database: $DATABASE_URL"
echo "Local RPC: $LOCAL_RPC"
echo ""
echo "GraphQL will be available at: http://localhost:3001/graphql"
echo "Playground at: http://localhost:3001/playground"
echo ""

# Run with cargo in release mode
cargo run -- --indexer --graphql
