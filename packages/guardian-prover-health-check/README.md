[![Golang](https://github.com/taikoxyz/taiko-mono/actions/workflows/golang.yml/badge.svg)](https://github.com/taikoxyz/taiko-mono/actions/workflows/golang.yml)
[![GuardianProverHealthCheck](https://codecov.io/gh/taikoxyz/taiko-mono/branch/main/graph/badge.svg?token=E468X2PTJC&flag=guardianproverhealthcheck)](https://codecov.io/gh/taikoxyz/taiko-mono)

# Guardian Prover Health Check Service

A service that watches the guardian provers and pings them for uptime availability metrics.

## Build the source

Building the `taiko-client` binary requires a Go compiler. Once installed, run:

```sh
make build
```

## Configuration

Run migrations:
`cd migrations`
`goose mysql "user:pass@/dbname?parseTime=true" up`

To run the health check service:
`ENV_FILE=.env go run cmd/main.go healthchecker`

To run the stats generator:
`ENV_FILE=.generator.env go run cmd/main.go generator`

## Usage

Review all available sub-commands:

```sh
bin/guardian-prover-health-check --help
```

Review each sub-command's command line flags:

```sh
bin/guardian-prover-health-check <sub-command> --help
```
