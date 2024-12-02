# taiko-client

[![CI](https://github.com/taikoxyz/taiko-mono/actions/workflows/taiko-client--test.yml/badge.svg)](https://github.com/taikoxyz/taiko-mono/actions/workflows/taiko-client-test.yml)

<!-- TODO(d1onys1us): fix codecov integration -->
<!-- [![Codecov](https://img.shields.io/codecov/c/github/taikoxyz/taiko-mono/packages/taiko-client?logo=codecov&token=OH6BJMVP6O)](https://codecov.io/gh/taikoxyz/taiko-mono/packages/taiko-client) -->

Taiko protocol's client software implementation in Go. Learn more about Taiko nodes with [the docs](https://docs.taiko.xyz/core-concepts/taiko-nodes/).

## Project structure

| Path                | Description                                                                                                                              |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `bindings/`         | [Go contract bindings](https://geth.ethereum.org/docs/dapp/native-bindings) for Taiko smart contracts, and few related utility functions |
| `cmd/`              | Main executable for this project                                                                                                         |
| `docs/`             | Documentation                                                                                                                            |
| `driver/`           | Driver sub-command                                                                                                                       |
| `integration_test/` | Scripts to do the integration testing of all client software                                                                             |
| `metrics/`          | Metrics related                                                                                                                          |
| `pkg/`              | Library code which used by all sub-commands                                                                                              |
| `proposer/`         | Proposer sub-command                                                                                                                     |
| `prover/`           | Prover sub-command                                                                                                                       |
| `scripts/`          | Helpful scripts                                                                                                                          |
| `testutils/`        | Test utils                                                                                                                               |
| `version/`          | Version information                                                                                                                      |

## Build the source

Building the `taiko-client` binary requires a Go compiler. Once installed, run:

```sh
make build
```

## Usage

Review all available sub-commands:

```sh
bin/taiko-client --help
```

Review each sub-command's command line flags:

```sh
bin/taiko-client <sub-command> --help
```

## Testing

Ensure you have Docker running, and pnpm installed.

Then, run the integration tests:

1. Start Docker locally
2. Perform a `pnpm install` in `taiko-mono/packages/protocol`
3. Replace `<PATH_TO_TAIKO_MONO_REPO>` and execute:

```sh
make test
```
