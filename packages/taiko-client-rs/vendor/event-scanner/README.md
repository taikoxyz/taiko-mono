# Event Scanner

[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://opensource.org/licenses/MIT)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/OpenZeppelin/Event-Scanner/badge)](https://api.securityscorecards.dev/projects/github.com/OpenZeppelin/Event-Scanner)

## Node compatibility

Event Scanner's test suite and examples are exercised against Foundry's `anvil` dev node.

While the library is intended to work with other EVM nodes and RPC providers, behaviour may vary across implementations. If you encounter errors when using a different node/provider, please open an issue at:

https://github.com/OpenZeppelin/Event-Scanner/issues

## About

Event Scanner is a Rust library for streaming EVM-based smart contract events. It is built on top of the [`alloy`](https://github.com/alloy-rs/alloy) ecosystem and focuses on in-memory scanning without a backing database. Applications provide event filters; the scanner takes care of fetching historical ranges, bridging into live streaming mode, all whilst delivering the events as streams of data.

---

## Table of Contents

- [Features](#features)
- [Architecture Overview](#architecture-overview)
- [Quick Start](#quick-start)
- [Usage](#usage)
  - [Building a Scanner](#building-a-scanner)
  - [Defining Event Filters](#defining-event-filters)
  - [Scanning Modes](#scanning-modes)
    - [HTTP Subscription Support](#http-subscription-support)
- [Examples](#examples)
- [Testing](#testing)

---

## Features

- **Historical replay** – stream events from past block ranges.
- **Live subscriptions** – stay up to date with latest events via WebSocket, IPC, or HTTP transports (HTTP requires the `http-subscription` feature flag).
- **Hybrid flow** – automatically transition from historical catch-up into streaming mode.
- **Latest events fetch** – one-shot rewind to collect the most recent matching logs.
- **Composable filters** – register one or many contract + event signature pairs.
- **No database** – processing happens in-memory; persistence is left to the host application.

---

## Architecture Overview

The library exposes two primary layers:

- `EventScanner` – the main scanner type the application will interact with.
- `BlockRangeScanner` – lower-level component that streams block ranges, handles reorg, batching, and provider subscriptions.

---

## Quick Start

Add `event-scanner` to your `Cargo.toml`:

```toml
[dependencies]
event-scanner = "1.1.2"
```

Create an event stream for the given event filters registered with the `EventScanner`:

```rust
use alloy::{network::Ethereum, providers::ProviderBuilder, sol_types::SolEvent};
use event_scanner::{EventFilter, EventScannerBuilder, Message};
use robust_provider::RobustProviderBuilder;
use tokio_stream::StreamExt;
use tracing::{error, info};

use crate::MyContract;

async fn run_scanner(
    ws_url: &str,
    contract: alloy::primitives::Address,
) -> Result<(), Box<dyn std::error::Error>> {
    // Connect to provider
    let provider = ProviderBuilder::new().connect(ws_url).await?;
    let robust_provider = RobustProviderBuilder::new(provider).build().await?;

    // Configure scanner with custom batch size (optional)
    let mut scanner = EventScannerBuilder::live()
        .max_block_range(500)  // Process up to 500 blocks per batch
        .connect(robust_provider)
        .await?;

    // Register an event listener
    let filter = EventFilter::new()
        .contract_address(contract)
        .event(MyContract::SomeEvent::SIGNATURE);

    let subscription = scanner.subscribe(filter);

    // Start the scanner and get the proof
    let proof = scanner.start().await?;

    // Access the stream using the proof
    let mut stream = subscription.stream(&proof);

    // Process messages from the stream
    while let Some(message) = stream.next().await {
        match message {
            Ok(Message::Data(logs)) => {
                for log in logs {
                    info!("Callback successfully executed with event {:?}", log.inner.data);
                }
            }
            Ok(Message::Notification(notification)) => {
                info!("Received notification: {:?}", notification);
            }
            Err(e) => {
                error!("Received error: {}", e);
            }
        }
    }

    Ok(())
}
```

---

## Usage

### Building a Scanner

`EventScannerBuilder` provides mode-specific constructors and functions to configure settings before connecting.
Once configured, connect using:

- `connect(provider)` - Connect using a [Robust Provider](https://github.com/OpenZeppelin/Robust-Provider) wrapping your alloy provider or using an alloy provider directly

This will connect the `EventScanner` and allow you to create event streams and start scanning in various [modes](#scanning-modes).

```rust
use alloy::providers::ProviderBuilder;
use event_scanner::EventScannerBuilder;
use robust_provider::RobustProviderBuilder;

// Connect to provider (example with WebSocket)
let provider = ProviderBuilder::new().connect("ws://localhost:8545").await?;

// Live streaming mode
let scanner = EventScannerBuilder::live()
    .max_block_range(500)  // Optional: set max blocks per read (default: 1000)
    .block_confirmations(12)  // Optional: set block confirmations (default: 12)
    .connect(provider.clone())
    .await?;

// Historical block range mode
let scanner = EventScannerBuilder::historic()
    .from_block(1_000_000)
    .to_block(2_000_000)
    .max_block_range(500)
    .connect(provider.clone())
    .await?;

// we can also wrap the provider in a RobustProvider
// for more advanced configurations like retries and fallbacks
let robust_provider = RobustProviderBuilder::new(provider).build().await?;

// Latest events mode
let scanner = EventScannerBuilder::latest(100)
    // .from_block(1_000_000)  // Optional: set start of search range
    // .to_block(2_000_000)    // Optional: set end of search range
    .max_block_range(500)
    .connect(robust_provider.clone())
    .await?;

// Sync from block then switch to live mode
let scanner = EventScannerBuilder::sync()
    .from_block(100)
    .max_block_range(500)
    .block_confirmations(12)
    .connect(robust_provider.clone())
    .await?;

// Sync the latest 60 events then switch to live mode
let scanner = EventScannerBuilder::sync()
    .from_latest(60)
    .block_confirmations(12)
    .connect(robust_provider)
    .await?;
```

Invoking `scanner.start()` starts the scanner in the specified mode and returns a `StartProof` that must be passed to `subscription.stream()` to access the event stream. This compile-time guarantee ensures the scanner is started before attempting to read events.

### Defining Event Filters

Create an `EventFilter` for each event stream you wish to process. The filter specifies the contract address where events originated, and event signatures (tip: you can use the value stored in `SolEvent::SIGNATURE`).

```rust
use alloy::sol_types::SolEvent;
use event_scanner::EventFilter;

// Track a SPECIFIC event from a SPECIFIC contract
let specific_filter = EventFilter::new()
    .contract_address(*my_contract.address())
    .event(MyContract::SomeEvent::SIGNATURE);

// Track multiple events from a SPECIFIC contract
let specific_filter = EventFilter::new()
    .contract_address(*my_contract.address())
    .event(MyContract::SomeEvent::SIGNATURE)
    .event(MyContract::OtherEvent::SIGNATURE);

// Track a SPECIFIC event from ALL contracts
let specific_filter = EventFilter::new()
    .event(MyContract::SomeEvent::SIGNATURE);

// Track ALL events from SPECIFIC contracts
let all_contract_events_filter = EventFilter::new()
    .contract_address(*my_contract.address())
    .contract_address(*other_contract.address());

// Track ALL events from ALL contracts
let all_events_filter = EventFilter::new();
```

Register multiple filters by invoking `subscribe` repeatedly.

The flexibility provided by `EventFilter` allows you to build sophisticated event monitoring systems that can track events at different granularities depending on your application's needs.

### Event Filter Batch Builders

Batch builder examples:

```rust
// Multiple contract addresses at once
let multi_addr = EventFilter::new()
    .contract_addresses([*my_contract.address(), *other_contract.address()]);

// Multiple event names at once
let multi_events = EventFilter::new()
    .events([MyContract::SomeEvent::SIGNATURE, MyContract::OtherEvent::SIGNATURE]);

// Multiple event signature hashes at once
let multi_sigs = EventFilter::new()
    .event_signatures([
        MyContract::SomeEvent::SIGNATURE_HASH,
        MyContract::OtherEvent::SIGNATURE_HASH,
    ]);
```

### Message Types

The scanner delivers three types of messages through the event stream:

- **`Message::Data(Vec<Log>)`** – Contains a batch of matching event logs. Each log includes the raw event data, transaction hash, block number, and other metadata.
- **`Message::Notification(Notification)`** – Notifications from the scanner.
- **`ScannerError`** – Errors indicating that the scanner has encountered issues (e.g., RPC failures, connection problems, or a lagging consumer).

Always handle all message types in your stream processing loop to ensure robust error handling and proper reorg detection.

Notes:

- Ordering is guaranteed only within a single subscription stream. There is no global ordering guarantee across multiple subscriptions.
- When the scanner detects a reorg, it emits `Notification::ReorgDetected`. Consumers should assume the same events might be delivered more than once around reorgs (i.e. benign duplicates are possible). Depending on the application's needs, this could be handled via idempotency/deduplication or by rolling back application state on reorg notifications.
- In **Historic** mode specifically, reorg checks are only performed while streaming the **non-finalized** portion of the requested range. Blocks at or below the chain's `finalized` height are streamed without reorg checks.

### Scanning Modes

- **Live** – scanner that streams new blocks as they arrive.
- **Historic** – scanner for streaming events from a past block range (default: genesis..=latest). For non-finalized blocks, the scanner may re-stream parts of the range if it detects a reorg, and will emit `Notification::ReorgDetected`.
- **Latest Events** – scanner that collects up to `count` most recent events per listener. Final delivery is in chronological order (oldest to newest).
- **Sync from Block** – scanner that streams events from a given start block up to the current confirmed tip, then automatically transitions to live streaming.
- **Sync from Latest Events** - scanner that collects the most recent `count` events, then automatically transitions to live streaming.

#### HTTP Subscription Support

By default, live block subscriptions rely on WebSocket or IPC transports. If your provider only supports HTTP, enable the `http-subscription` feature flag and opt in on the `RobustProviderBuilder`:

```toml
[dependencies]
event-scanner = { version = "1.1.2", features = ["http-subscription"] }
```

```rust
let robust_provider = RobustProviderBuilder::new(provider)
    .allow_http_subscriptions(true)
    .build()
    .await?;
```

Both steps are required — the feature flag makes the API available, and `.allow_http_subscriptions(true)` enables it at runtime.

This applies to all modes that include a live streaming phase: **Live**, **Sync from Block**, and **Sync from Latest Events**.

#### Important Notes

- Set `max_block_range` based on your RPC provider's limits (e.g., Alchemy, Infura may limit queries to 2000 blocks). Default is 1000 blocks.
- The modes come with sensible defaults; for example, not specifying a start block for historic mode automatically sets it to the genesis block.
- In live mode, if the block subscription lags and the scanner needs to catch up by querying past blocks, catch-up queries are performed in ranges bounded by `max_block_range` to respect provider limits.

---

## Examples

- `examples/live_scanning` – minimal live-mode scanner using `EventScannerBuilder::live()`
- `examples/live_scanning_http` – live-mode scanner over HTTP transport using the `http-subscription` feature flag
- `examples/historical_scanning` – demonstrates replaying historical data using `EventScannerBuilder::historic()`
- `examples/sync_from_block_scanning` – demonstrates replaying from genesis (block 0) before continuing to stream the latest blocks using `EventScannerBuilder::sync().from_block(block_id)`
- `examples/latest_events_scanning` – demonstrates scanning the latest events using `EventScannerBuilder::latest()`
- `examples/sync_from_latest_scanning` – demonstrates scanning the latest events before switching to live mode using `EventScannerBuilder::sync().from_latest(count)`.

Run an example with:

```bash
RUST_LOG=info cargo run --example live_scanning --features example
```

For the HTTP subscription example:

```bash
RUST_LOG=info cargo run --example live_scanning_http --features "example http-subscription"
```

This will also enable `event-scanner` internal logs in the example.

All examples spin up a local `anvil` instance, deploy a demo counter contract, and demonstrate using event streams to process events.

If you run into issues when using a different node/provider, please report them at https://github.com/OpenZeppelin/Event-Scanner/issues.

---

## Testing

(We recommend using [nextest](https://crates.io/crates/cargo-nextest) to run the tests)

Integration tests cover all modes:

Note: Tests are exercised against a local Foundry [anvil][anvil] instance.

```bash
cargo nextest run --features test-utils
```

[anvil]: https://github.com/foundry-rs/foundry?tab=readme-ov-file#anvil
