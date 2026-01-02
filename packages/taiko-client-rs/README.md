# taiko-client-rs

A Rust implementation of the Taiko Alethia protocol client, designed as an alternative to the Go implementation, for Shasta and subsequent protocol forks.

## Project structure

| Path              | Description                                                                                             |
| ----------------- | ------------------------------------------------------------------------------------------------------- |
| `bin/client/`     | Main executable for the Taiko client                                                                    |
| `crates/bindings/` | Rust contract bindings for Taiko smart contracts                                                       |
| `crates/driver/`   | Driver implementation for proposal derivation and syncing                                              |
| `crates/proposer/` | Proposer implementation for submitting block proposals to L1                                           |
| `crates/protocol/` | Core protocol types and data structures                                                                |
| `crates/rpc/`     | RPC client utilities and helper functions                                                               |
| `script/`         | Helpful scripts for development and deployment                                                          |
| `tests/`          | Integration and end-to-end tests                                                                        |

## Prerequisites

- Rust toolchain (1.88 or later)
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
