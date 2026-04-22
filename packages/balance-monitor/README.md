# Balance Monitor

balance-monitor is a service that monitors Ethereum L1/L2 addresses and their token balances, and exports these metrics to Prometheus for easy monitoring and alerting.

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
