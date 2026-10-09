# taiko-client-rs

A Rust implementation of the Taiko Alethia protocol client. The Shasta driver, proposer and whitelist preconfirmation driver have been removed; networks before the Etna activation keep using the previous release.

## Project structure

| Path                   | Description                                                  |
| ---------------------- | ------------------------------------------------------------ |
| `bin/client/`          | Main executable for the Taiko client                         |
| `crates/abci/`         | ABCI++ application of the Etna PoS chain (CometBFT)          |
| `crates/bindings/`     | Rust contract bindings for the Taiko Anchor contract         |
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

`taiko-client abci` serves the Etna PoS chain's ABCI++ application to a CometBFT node
(`proxy_app`, default `tcp://127.0.0.1:26658`) on top of alethia-reth and an own L1 node:

```sh
./target/release/taiko-client abci \
  --l1.http http://localhost:8545 \
  --l2.http http://localhost:28545 --l2.auth http://localhost:28551 --jwt.secret ./jwt.hex \
  --data-dir ./abci-data
```

A safety halt (a committed block or the execution engine contradicting the app state) exits
the process with status 2; investigate before restarting.

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
