#!/bin/bash

# Database connection parameters (can be overridden by environment variables)
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-protocol_indexer}
DB_USER=${DB_USER:-postgres}
DB_PASSWORD=${DB_PASSWORD:-rindexer}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Initializing Indexer Database${NC}"
echo "=================================="

# Function to execute SQL file
execute_sql() {
    local file=$1
    local description=$2

    echo -e "${YELLOW}Executing: ${description}${NC}"

    if [ -z "$DB_PASSWORD" ]; then
        PGPASSWORD="" psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $file
    else
        PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $file
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ${description} completed${NC}"
    else
        echo -e "${RED}✗ ${description} failed${NC}"
        exit 1
    fi
}

# Check if database exists
echo "Checking database connection..."
if [ -z "$DB_PASSWORD" ]; then
    PGPASSWORD="" psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1" > /dev/null 2>&1
else
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1" > /dev/null 2>&1
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}Cannot connect to database. Please check your connection parameters.${NC}"
    echo "DB_HOST=$DB_HOST"
    echo "DB_PORT=$DB_PORT"
    echo "DB_NAME=$DB_NAME"
    echo "DB_USER=$DB_USER"
    exit 1
fi

echo -e "${GREEN}Database connection successful${NC}"

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Execute migrations in order
execute_sql "$SCRIPT_DIR/001_create_schema.sql" "Creating schema"
execute_sql "$SCRIPT_DIR/002_create_tables.sql" "Creating tables"

echo ""
echo -e "${GREEN}Database initialization completed successfully!${NC}"
echo ""
