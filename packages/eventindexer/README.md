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

1. accounts growth - DONE
2. new accounts per day - DONE

PROPOSING

1. total unique proposers - DONE
2. unique proposers per day - DONE
3. proposeBlock tx per day - DONE
4. total proposeBlock tx per day - DONE

PROVING

1. total unique provers - DONE
2. unique provers per day - DONE
3. proveBlock tx per day - DONE
4. total proveBlock tx - DONE

VERIFICATION

1. total verifiedBlocks
2. verifiedBlocks per day

TRANSACTIONS

1. total transactions - DONE
2. transactions per day - DONE

BLOCKS

1. total blocks - DONE
2. blocks per day - DONE

CONTRACTS

1. total deployed contracts - DONE
2. deployed contracts per day - DONE

BRIDGE

1. bridge messages sent per day
2. total bridge messages sent
3. bridge messages claimed per day
4. total bridge messages claimed
5. bridge processing fee average per day
6. total bridge processing fee average
