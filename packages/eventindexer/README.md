[![Event Indexer](https://app.codecov.io/gh/taikoxyz/taiko-mono/flags/main?flags%5B0%5D=eventindexer)](https://codecov.io/gh/taikoxyz/taiko-mono)

# Indexer

Catches events, stores them in the database to be queried via API.

ERC20, ERC721, and ERC1155 transfers are applied sequentially in ascending block
number, transaction index, and log index order. The existing per-transfer
transactions and replay protection remain unchanged; serial writes reduce
parallel write throughput and do not reconcile historical incorrect balances or
duplicate records.

When either balance indexer is enabled, startup obtains a MySQL `GET_LOCK` scoped
to the source chain and database, and refuses to start if another guarded writer
already holds it. The NFT and ERC20 repositories share the dedicated session
holding that lock; a lost session cannot continue balance writes through the
ordinary connection pool. Ownership is checked before each indexing batch, and
lock loss stops indexing and returns a fatal CLI error so the supervisor can
restart the process. Shutdown or failed startup releases and discards the session. Configure at least two open database connections, or an unlimited pool.
All writers must use this guarded version; stop older unguarded writers before
upgrading.

A missing ERC20 sender balance emits a structured warning while preserving the
existing skip behavior. Durable recovery of an interrupted batch is tracked
separately in [#22285](https://github.com/taikoxyz/taiko-mono/issues/22285): the
current restart cursor is still derived from the latest persisted event, rather
than a completed-batch checkpoint.

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
