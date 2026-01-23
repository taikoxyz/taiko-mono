[![Event Indexer](https://app.codecov.io/gh/taikoxyz/taiko-mono/flags/main?flags%5B0%5D=eventindexer)](https://codecov.io/gh/taikoxyz/taiko-mono)

# Indexer

Catches events, stores them in the database to be queried via API .

## Running the app

run `cp .default.env .env`, and configure your environment variables. You need to be running a MySQL instance, and replace all the `MYSQL_` env vars with yours.

Run `go run cmd/main.go --help` to see a list of possible configuration flags, or `go run cmd/main.go` to run with defaults, which will start indexing events and blocks from block 0.

# Block data

1. parse data
2. store
3. cron job that updates every 24 hours
