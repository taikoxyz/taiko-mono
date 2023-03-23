[![Golang](https://github.com/taikoxyz/taiko-mono/actions/workflows/golang.yml/badge.svg)](https://github.com/taikoxyz/taiko-mono/actions/workflows/golang.yml)
[![Relayer](https://codecov.io/gh/taikoxyz/taiko-mono/branch/main/graph/badge.svg?token=E468X2PTJC&flag=relayer)](https://codecov.io/gh/taikoxyz/taiko-mono)

# Indexer

Catches events, stores them in the database to be queried via API.

## Running the app

run `cp .default.env .env`, and add your own private key as `RELAYER_ECDSA_KEY` in `.env`. You need to be running a MySQL instance, and replace all the `MYSQL_` env vars with yours.

Run `go run cmd/main.go --help` to see a list of possible configuration flags, or `go run cmd/main.go` to run with defaults, which will process messages from L1 to L2, and from L2 to L1, and start indexing blocks from 0.
