#!/bin/bash

# Docker entrypoint script for protocol-indexer

# Set default values if not provided
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:rindexer@localhost:5432/protocol_indexer}"
LOCAL_RPC="${LOCAL_RPC:-http://localhost:8545}"
HOLESKY_RPC="${HOLESKY_RPC:-http://localhost:8545}"
ETHEREUM_RPC="${ETHEREUM_RPC:-http://localhost:8545}"
RUN_MIGRATION="${RUN_MIGRATION:-false}"

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
echo "Run Migration: $RUN_MIGRATION"
echo ""

# Run migrations if enabled
if [ "$RUN_MIGRATION" = "true" ]; then
    echo "Running database migrations..."
    
    # Set migration environment variables
    export USE_DOCKER=false
    export DB_HOST=$(echo $DATABASE_URL | sed -n 's/.*@\([^:\/]*\).*/\1/p')
    export DB_PORT=$(echo $DATABASE_URL | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
    export DB_NAME=$(echo $DATABASE_URL | sed -n 's/.*\/\([^?]*\).*/\1/p')
    export DB_USER=$(echo $DATABASE_URL | sed -n 's/.*:\/\/\([^:]*\).*/\1/p')
    export DB_PASSWORD=$(echo $DATABASE_URL | sed -n 's/.*:\/\/[^:]*:\([^@]*\).*/\1/p')
    
    # Run the migration script
    if [ -f /app/migrations/init.sh ]; then
        /app/migrations/init.sh
    else
        echo "Migration script not found at /app/migrations/init.sh"
        exit 1
    fi
    
    if [ $? -ne 0 ]; then
        echo "Migration failed!"
        exit 1
    fi
    echo "Migrations completed successfully."
    echo ""
fi

# Run the compiled binary with all arguments
exec /usr/local/bin/protocol_indexer "$@"
