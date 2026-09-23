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

## L1 beacon node requirements

The driver reads each proposal's blobs from the L1 beacon node set by `--l1.beacon`, through `GET /eth/v1/beacon/blobs/{block_id}?versioned_hashes=...`, and checks every blob against its versioned hash. While consensus clients still serve it, a node that answers `404` there is asked again through the deprecated `GET /eth/v1/beacon/blob_sidecars/{block_id}`, which [ethereum/beacon-APIs#577](https://github.com/ethereum/beacon-APIs/pull/577) removed from the spec.

Since Fulu (PeerDAS), a beacon node keeps only the data columns it custodies, so only a **supernode** (custodies every column) or a **semi-supernode** (custodies half of them, enough to reconstruct every blob) can serve full blobs. Point `--l1.beacon` at such a node, or set `--blob.server` to another blob source: when the beacon node cannot return a blob, the driver asks the blob server, and without one derivation stalls until the blob is available.

Beacon nodes also prune blobs after 4096 epochs (about 18 days), so syncing older proposals needs `--blob.server` as well.

## Testing

Ensure you have Docker running, and pnpm installed.

Then, run the integration tests:

1. Start Docker locally
2. Perform a `pnpm install` in `taiko-mono/packages/protocol`
3. Execute:

```sh
make test
```
