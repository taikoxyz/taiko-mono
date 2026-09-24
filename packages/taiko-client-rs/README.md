# taiko-client-rs

A Rust implementation of the Taiko Alethia protocol client, designed as an alternative to the Go implementation, for Shasta and subsequent protocol forks.

## Project structure

| Path                   | Description                                                  |
| ---------------------- | ------------------------------------------------------------ |
| `bin/client/`          | Main executable for the Taiko client                         |
| `crates/bindings/`     | Rust contract bindings for Taiko smart contracts             |
| `crates/driver/`       | Driver implementation for proposal derivation and syncing    |
| `crates/proposer/`     | Proposer implementation for submitting block proposals to L1 |
| `crates/protocol/`     | Core protocol types and data structures                      |
| `crates/rpc/`          | RPC client utilities and helper functions                    |
| `crates/test-harness/` | Test utilities and harness for integration tests             |
| `script/`              | Helpful scripts for development and deployment               |
| `tests/`               | Integration and end-to-end tests                             |

## Prerequisites

- Rust toolchain (1.95 or later)
- Docker (for running tests)
- Just (for simplified commands)

## Build the source

Building the `taiko-client` binary requires a Rust compiler. Once installed, run:

```sh
cargo build --release
```

### Usage

Then review all available sub-commands:

```sh
./target/release/taiko-client --help
```

## L1 beacon node requirements

The driver reads each proposal's blobs from the L1 beacon node set by `--l1.beacon`, through `GET /eth/v1/beacon/blobs/{block_id}?versioned_hashes=...`, and checks every blob against its versioned hash. On Prysm, use v7.1.8 or later: v6.1.0 to v7.1.7 drop the connection when a requested blob appears twice in its block ([OffchainLabs/prysm#17199](https://github.com/OffchainLabs/prysm/pull/17199)), and the driver then needs the blob server set by `--blob.server`.

Since Fulu (PeerDAS), a beacon node keeps only the data columns it custodies, so only a **supernode** (custodies every column) or a **semi-supernode** (custodies half of them, enough to reconstruct every blob) can serve full blobs. Point `--l1.beacon` at such a node, or set `--blob.server` to another blob source: when the beacon node cannot return a blob, the driver asks the blob server, and without one derivation stalls until the blob is available.

Beacon nodes also prune blobs after 4096 epochs (about 18 days), so syncing older proposals needs `--blob.server` as well.

## Development

### Format code

```sh
just fmt
```

### Run lints

```sh
just clippy
```

### Run tests

```sh
just test
```

## License

See the [LICENSE](../../LICENSE) file for details.
