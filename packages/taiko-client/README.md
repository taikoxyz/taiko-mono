# taiko-client

[![CI](https://github.com/taikoxyz/taiko-mono/actions/workflows/taiko-client--test.yml/badge.svg)](https://github.com/taikoxyz/taiko-mono/actions/workflows/taiko-client--test.yml)

[![Codecov](https://codecov.io/gh/taikoxyz/taiko-mono/graph/badge.svg?&token=E468X2PTJC&flag=taiko-client)](https://codecov.io/gh/taikoxyz/taiko-mono/packages/taiko-client)

Taiko Alethia protocol's client software implementation in Go. Learn more about Taiko Alethia nodes with [the docs](https://docs.taiko.xyz/guides/run-a-node).

## Project structure

| Path                  | Description                                                                                                                                                   |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bindings/`           | [Go contract bindings](https://geth.ethereum.org/docs/developers/dapp-developer/native-bindings) for Taiko smart contracts, and few related utility functions |
| `cmd/`                | Main executable for this project                                                                                                                              |
| `docs/`               | Documentation                                                                                                                                                 |
| `driver/`             | Driver sub-command                                                                                                                                            |
| `integration_test/`   | Scripts to do the integration testing of all client software                                                                                                  |
| `internal/metrics/`   | Metrics related                                                                                                                                               |
| `pkg/`                | Library code which used by all sub-commands                                                                                                                   |
| `proposer/`           | Proposer sub-command                                                                                                                                          |
| `prover/`             | Prover sub-command                                                                                                                                            |
| `scripts/`            | Helpful scripts                                                                                                                                               |
| `internal/testutils/` | Test utils                                                                                                                                                    |
| `internal/version/`   | Version information                                                                                                                                           |

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

### Local proposal metadata API

The driver can expose a disabled-by-default, loopback-only Shasta proposal metadata API for co-located
TDX provers:

```sh
bin/taiko-client driver --proposalApi.enabled --proposalApi.addr 127.0.0.1:9876 ...
```

The API rejects non-loopback bind addresses. The only endpoint is:

```sh
GET /internal/shasta/proposals/{proposal_id}
```

The response contains the reconstructed Shasta proposal, its `hashProposal` value, and the source L1
event coordinates. It is intended for local validation by a prover running on the same machine, not as
a public API.

## Testing

Ensure you have Docker running, and pnpm installed.

Then, run the integration tests:

1. Start Docker locally
2. Perform a `pnpm install` in `taiko-mono/packages/protocol`
3. Execute:

```sh
make test
```
