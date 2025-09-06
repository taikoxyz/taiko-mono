# Protocol Indexer

An event indexer implementation for the protocol built with [rindexer](https://github.com/joshstevens19/rindexer).

## Overview

This indexer monitors and processes events from the Taiko protocol smart contracts, providing real-time event tracking and data persistence. It's designed to efficiently index blockchain events such as `Proposed`, `Proved`, and `BondInstructed` from the protocol `Inbox` contract.

## Prerequisites

- Rust 1.81+ (install via [rustup](https://rustup.rs/))
- PostgreSQL database (for event storage)

## Installation

### Clone the Repository

```bash
git clone https://github.com/taikoxyz/taiko-mono
cd packages/protocol-indexer
```

### Build

```bash
cargo build
```

## `rindexer` Configuration

The `rindexer.yaml` file contains the core indexer configuration:

- **Networks**: Define the blockchain networks to connect to
- **Contracts**: Specify which contracts and events to index
- **Storage**: Configure database settings
- **Start Block**: Set the block number to start indexing from

## Usage

### Starting the Indexer

Run all indexers defined in the configuration:

```bash
cargo run
```

## Working with [`rindexer`](https://github.com/joshstevens19/rindexer)

### Code Generation

rindexer generates Rust code based on your contract ABIs. You need to place your updated ABI JSON file in the `abis/` directory, update the `rindexer.yaml`, and run the codegen command:

```bash
rindexer codegen
```

After generating the code, build the project:

```bash
cargo build
```

Generated code will be placed in `src/rindexer_lib/` and includes:
- Type-safe event definitions
- Database models
- Event handlers

## Docker Deployment

### Build the Docker Image

```bash
docker build -t protocol-indexer .
```

### Run with Docker Compose

```bash
docker-compose up -d
```

This will start a PostgreSQL database.
