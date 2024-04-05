# eventindexer

Repository dedicated to capturing events, storing them in a database for API queries.

## Prerequisites

- Docker engine should be operational.
- Ensure Go is installed on the system.

## Configuration and Setup

### MySQL Setup

1. **Start MySQL** by navigating to the `docker-compose` directory and executing:

   ```bash
   cd ./docker-compose
   docker-compose up -d
   ```

2. **Migrate Database Schema** within the `migrations` folder:

   ```bash
   cd ./migrations
   goose mysql "root:passw00d@tcp(localhost:3306)/eventindexer" status
   goose mysql "root:passw00d@tcp(localhost:3306)/eventindexer" up
   ```

### Environment Configuration

Configure `.l1.env`, `.l2.env`, and `.default.env` files with the necessary database credentials and other variables.

## Running the Application

Start various components by specifying the environment file with `EVENTINDEXER_ENV_FILE`:

- **Indexer**:
  
  ```bash
  EVENTINDEXER_ENV_FILE=.default.env go run cmd/main.go indexer
  ```

- **API**:
  
  ```bash
  EVENTINDEXER_ENV_FILE=.default.env go run cmd/main.go api
  ```

- **Generator**:

  ```bash
  EVENTINDEXER_ENV_FILE=.l1.env go run cmd/main.go generator
  ```

Choose between `.default.env`, `.l1.env`, or `.l2.env` as per the requirement.

# Block data

1. parse data
2. store
3. cron job that updates every 24 hours
