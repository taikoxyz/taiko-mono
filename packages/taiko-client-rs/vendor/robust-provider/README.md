# Robust Provider

[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://opensource.org/licenses/MIT)

> Robust, retrying wrapper around Alloy providers.
>
> _Currently production-ready for supported features. The API surface is still evolving and future feature additions may introduce breaking changes and/or changes in assumptions._

## About

Robust Provider is a Rust library that wraps [Alloy](https://github.com/alloy-rs/alloy) providers with production-ready resilience features. It adds automatic retries, timeouts, and transparent failover between multiple RPC endpoints - making it ideal for applications that need reliable blockchain connectivity.

---

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Usage](#usage)
  - [Building a Provider](#building-a-provider)
  - [Configuration Options](#configuration-options)
  - [Subscriptions](#subscriptions)
- [Provider Conversion](#provider-conversion)
- [Testing](#testing)
- [RPC Endpoint Coverage](#rpc-endpoint-coverage)
- [Extensibility](#extensibility)

---

## Features

- **Bounded timeouts** - per-call timeouts prevent indefinite hangs on unresponsive RPC endpoints.
- **Exponential backoff retries** - automatic retry with configurable backoff for transient failures.
- **Transparent failover** - seamlessly switch from a primary provider to one or more fallback providers.
- **Resilient subscriptions** - WebSocket block subscriptions with automatic reconnection and lag detection.

---

## Quick Start

Add `robust-provider` to your `Cargo.toml`:

```toml
[dependencies]
robust-provider = "1.0.2"
```

Create a robust provider with automatic retries and fallback:

```rust
use alloy::providers::{Provider, ProviderBuilder};
use robust_provider::RobustProviderBuilder;
use std::time::Duration;
use tokio_stream::StreamExt;

async fn run() -> anyhow::Result<()> {
    let ws = ProviderBuilder::new().connect("ws://localhost:8545").await?;
    let ws_fallback = ProviderBuilder::new().connect("ws://localhost:8546").await?;

    let robust = RobustProviderBuilder::new(ws)
        .fallback(ws_fallback)
        .call_timeout(Duration::from_secs(30))
        .subscription_timeout(Duration::from_secs(120))
        .build()
        .await?;

    // Make RPC calls with automatic retries and fallback
    let block_number = robust.get_block_number().await?;
    println!("Current block: {}", block_number);

    // Create subscriptions that automatically reconnect on failure
    let sub = robust.subscribe_blocks().await?;
    let mut stream = sub.into_stream();
    while let Some(response) = stream.next().await {
        match response {
            Ok(block) => println!("New block: {:?}", block),
            Err(e) => println!("Got error: {:?}", e),
        }
    }

    Ok(())
}
```

---

## Usage

### Building a Provider

`RobustProviderBuilder` provides a fluent API for constructing a `RobustProvider` with custom settings:

```rust
use alloy::providers::ProviderBuilder;
use robust_provider::RobustProviderBuilder;
use std::time::Duration;

// Standard configuration with retries
let provider = ProviderBuilder::new().connect("ws://localhost:8545").await?;
let robust = RobustProviderBuilder::new(provider)
    .call_timeout(Duration::from_secs(30))
    .max_retries(3)
    .build()
    .await?;

// With multiple fallback providers
let primary = ProviderBuilder::new().connect("ws://primary:8545").await?;
let fallback_1 = ProviderBuilder::new().connect("ws://fallback1:8545").await?;
let fallback_2 = ProviderBuilder::new().connect_http("http://fallback2:8545".parse()?);

let robust = RobustProviderBuilder::new(primary)
    .fallback(fallback_1)
    .fallback(fallback_2)
    .build()
    .await?;
```

### Configuration Options

| Option                         | Default | Description                                                                |
| ------------------------------ | ------- | -------------------------------------------------------------------------- |
| `call_timeout`                 | 60s     | Maximum time for RPC operations before timing out                          |
| `subscription_timeout`         | 120s    | Maximum time to wait for subscription messages                             |
| `max_retries`                  | 3       | Number of retry attempts before failing over                               |
| `min_delay`                    | 1s      | Base delay for exponential backoff between retries                         |
| `reconnect_interval`           | 30s     | Interval between primary provider reconnection attempts (for subscription) |
| `subscription_buffer_capacity` | 128     | Buffer size for subscription streams                                       |

### Subscriptions

`RobustSubscription` wraps Alloy's block subscriptions with automatic failover and reconnection:

```rust
let robust = RobustProviderBuilder::new(provider)
    .fallback(fallback)
    .subscription_timeout(Duration::from_secs(120))
    .reconnect_interval(Duration::from_secs(30))
    .build()
    .await?;

let subscription = robust.subscribe_blocks().await?;
let mut stream = subscription.into_stream();

while let Some(result) = stream.next().await {
    match result {
        Ok(block) => {
            println!("Block {}: {}", block.number, block.hash);
        }
        Err(e) => {
            // Errors are propagated but the stream continues
            // (except for Closed errors which terminate the stream)
            eprintln!("Subscription error: {:?}", e);
        }
    }
}
```

**Subscription behaviour:**

- If no block arrives within `subscription_timeout`, the provider automatically fails over to fallbacks.
- While on a fallback, the subscription periodically attempts to reconnect to the primary provider (every `reconnect_interval`).
- When a fallback fails, the primary is tried first before moving to the next fallback.
- The `Lagged` error indicates the consumer is not keeping pace with incoming blocks.

#### HTTP-based subscriptions (feature flag)

By default, subscriptions use WebSocket/pubsub-capable providers. Normally, HTTP-only providers are skipped during subscription retries. If your environment only exposes HTTP endpoints, you can enable HTTP-based block subscriptions via polling using the `http-subscription` Cargo feature:

```toml
[dependencies]
robust-provider = { version = "1.0.2", features = ["http-subscription"] }
```

With this feature enabled and `allow_http_subscriptions(true)` is set, those HTTP providers can also act as subscription sources via polling, and are treated like regular pubsub-capable providers in the retry/failover logic:

```rust
let robust = RobustProviderBuilder::new(http_provider)
    .allow_http_subscriptions(true)
    // Optional: tune how often to poll for new blocks (defaults to ~12s)
    .poll_interval(Duration::from_secs(12))
    .build()
    .await?;
```

---

## Provider Conversion

The library provides two conversion traits for flexible provider handling:

### `IntoRootProvider`

Converts various types into an Alloy `RootProvider`. Implementations are provided for:

- `RobustProvider`
- `RootProvider`
- `&str` (connection URL)
- `Url`
- `FillProvider`
- `CacheProvider`
- `DynProvider`
- `CallBatchProvider`

### `IntoRobustProvider`

Converts any `IntoRootProvider` type directly into a `RobustProvider` with default settings:

```rust
use robust_provider::IntoRobustProvider;

// Convert a URL directly to a RobustProvider
let robust: RobustProvider<Ethereum> = "ws://localhost:8545".into().await?;

// Or convert an existing provider
let provider = ProviderBuilder::new().connect("ws://localhost:8545").await?;
let robust: RobustProvider<Ethereum> = provider.into().await?;
```

---

## Testing

Run the test suite:

```bash
cargo nextest run
```

The tests use local Anvil instances to verify retry logic, failover behaviour, and subscription resilience.

---

## Extensibility

The library exposes `try_operation_with_failover`, allowing you to wrap any custom logic with the full retry and failover logic:

```rust
use alloy::providers::Provider;

// Use try_operation_with_failover to call a combination of RPC methods with full resilience
let block = robust
    .try_operation_with_failover(
        |provider| async move {
            let latest_number = provider.get_block_number().await?;
            provider.get_block_by_number(latest_number.into()).await
        },
        false,
    )
    .await?;

```

This gives you the same automatic retries, timeouts, and failover behaviour for any RPC method supported by your node.
