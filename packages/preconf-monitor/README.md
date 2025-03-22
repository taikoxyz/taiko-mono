# Preconf Monitor

preconf-monitor is a service that monitors the PreconfWhitelist for changes in operator addition or removal, which require a `consolidate` call, or an operator that has missed sequencing or proposing, which requires a `removeOperator` call.

## Features

- Fetches Ethereum balances for specified addresses on both Layer 1 (L1) and Layer 2 (L2) networks.
- Exports balance data to Prometheus for integration with your monitoring and alerting systems.
- Supports Ethereum and various ERC-20 tokens.
- Provides a simple and extensible framework for adding new metrics.

## Build the source

```sh
go build -o monitor ./cmd/
./monitor
```
