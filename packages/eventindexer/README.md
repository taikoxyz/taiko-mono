[![Golang](https://github.com/taikoxyz/taiko-mono/actions/workflows/golang.yml/badge.svg)](https://github.com/taikoxyz/taiko-mono/actions/workflows/golang.yml)
[![Relayer](https://codecov.io/gh/taikoxyz/taiko-mono/branch/main/graph/badge.svg?token=E468X2PTJC&flag=relayer)](https://codecov.io/gh/taikoxyz/taiko-mono)

# Indexer

Catches events, stores them in the database to be queried via API.

## Running the app

run `cp .default.env .env`, and add your own private key as `RELAYER_ECDSA_KEY` in `.env`. You need to be running a MySQL instance, and replace all the `MYSQL_` env vars with yours.

Run `go run cmd/main.go --help` to see a list of possible configuration flags, or `go run cmd/main.go` to run with defaults, which will process messages from L1 to L2, and from L2 to L1, and start indexing blocks from 0.

# Block data

1. parse data
2. store
3. cron job that updates every 24 hours

ACCOUNTS

1. accounts growth
2. new accounts per day

PROPOSING

1. total unique proposers
2. unique proposers per day
3. proposeBlock tx per day
4. total proposeBlock tx per day

PROVING

1. total unique provers
2. unique provers per day
3. proveBlock tx per day
4. total proveBlock tx

VERIFICATION

1. total verifiedBlocks
2. verifiedBlocks per day

TRANSACTIONS

1. total transactions - done
2. transactions per day - done

BLOCKS

1. total blocks - done
2. blocks per day - done

CONTRACTS

1. total deployed contracts
2. deployed contracts per day

NETWORK

1. latestVerifiedId over time
2. proposalFee over time
3. blockReward over time
