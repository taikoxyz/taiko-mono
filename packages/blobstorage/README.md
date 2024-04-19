# blob-storage

Repository for BLOB storage (archive and serve data)

## Prerequisites

- Docker engine up and running.
- Go installed on your system.

## Configuration and Setup

### Setting up MySQL

1. **Start MySQL**:

   Navigate to the `docker-compose` directory and start the MySQL service:

   ```bash
   cd ./docker-compose
   docker-compose up -d
   ```

   This command starts your MySQL instance as defined in your `docker-compose.yml` file.

2. **Migrate Database Schema**:

   Navigate to the `migrations` directory to apply database migrations:

   ```bash
   cd ./migrations
   goose mysql "<user>:<password>@tcp(localhost:3306)/blobs" status
   goose mysql "<user>:<password>@tcp(localhost:3306)/blobs" up
   ```

   These commands apply migrations to the `blobs` database.

### Environment Configuration

Ensure your `.default.indexer.env` and `.default.server.env` files are configured with the correct database credentials, host, and any other necessary environment variables.

## Running the Application

1. **Start the Indexer**:

   With the environment file configured, start the indexer:

   ```bash
   ENV_FILE=.default.indexer.env go run cmd/main.go indexer
   ```

   This starts the app from the latest block height by default. Adjust the `STARTING_BLOCK_ID` in the environment file if needed.

2. **Start the Server**:

   Similarly, start the server:

   ```bash
   ENV_FILE=.default.server.env go run cmd/main.go server
   ```

## Testing and Usage

When the `DB`, `blob-catcher` and `server` are running, the `blob-catcher` is outputting the `blobHash` to the terminal (with the `networkName` variable too, though it is not written into the DB). Use that `blobHash` (including the 0x) in

1. **Querying Blob Data via HTTP Request**:

   To retrieve blob data, you can execute a `curl` command. This allows for querying multiple `blobHashes` simultaneously, separated by commas. A single request can yield an array of results:

   ```bash
   curl -X GET "http://localhost:3282/getBlob?blobHash=0x01a2a1cdc7ad221934061642a79a760776a013d0e6fa1a1c6b642ace009c372a,0xWRONG_HASH"
   ```

   **Expected Output**:

   ```bash
   {"data":[{"blob":"0x123...00","kzg_commitment":"0xabd68b406920aa74b83cf19655f1179d373b5a8cba21b126b2c18baf2096c8eb9ab7116a89b375546a3c30038485939e"}, {"blob":"NOT_FOUND","kzg_commitment":"NOT_FOUND"}]}
   ```

2. **Backtesting with a Python Script**:

   This script facilitates querying the database directly based on a specified `blob_hash`. Modify the `blob_hash` variable in the script to match the hash you wish to query.

   To run the script:

   ```bash
   python3 python_query.py
   ```

## Todos

What is still missing is:

- small refinements and DevOps (prod-grade DB with credentials, proper containerization)
