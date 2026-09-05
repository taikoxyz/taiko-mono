[![Event Indexer](https://app.codecov.io/gh/taikoxyz/taiko-mono/flags/main?flags%5B0%5D=eventindexer)](https://codecov.io/gh/taikoxyz/taiko-mono)

# Indexer

Catches events, stores them in the database to be queried via API.

## Running the app

run `cp .default.env .env`, and configure your environment variables. You need to be running a MySQL instance, and replace all the `MYSQL_` env vars with yours.

Run `go run cmd/main.go --help` to see the available configuration flags. Configure the database, source-chain RPC, and layer-specific variables before starting the indexer.

## Layer-specific Inbox configuration

Set `LAYER=l1` with `SHASTA_INBOX_ADDRESS` pointing to the Shasta Inbox on the
source L1. The L1 indexer uses this binding to filter `Proposed` and `Proved`
events. A checkpointed `SYNC_MODE=sync` resumes from the database without
calling `activationTimestamp()`; a fresh sync or `resync` uses that timestamp
to find the first Shasta block.

Set `LAYER=l2` without `SHASTA_INBOX_ADDRESS`. The L2 indexer starts from its
database checkpoint or block zero and never queries an L1 Inbox.

# Block data

1. parse data
2. store
3. cron job that updates every 24 hours
