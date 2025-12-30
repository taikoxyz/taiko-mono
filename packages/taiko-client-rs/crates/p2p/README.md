# P2P SDK (crates/p2p)

High-level SDK for the Taiko preconfirmation P2P network. This crate sits on top
of `preconfirmation-net` and adds validation, storage, deduplication, catch-up
sync, and a typed event/command API for downstream applications.

## Overview

The SDK provides:

- Gossip and req/resp plumbing for commitments and raw txlists
- SDK validation (EOP, parent linkage, block progression, block params)
- Deduplication across messages, commitments, and txlists
- Pending buffer for out-of-order commitments
- Catch-up sync pipeline from local head to network head
- Prometheus metrics

Pending/no-penalty limitation: the SDK can buffer pending commitments locally,
but gossipsub scoring is enforced by `preconfirmation-net`. Peers may still be
penalized by the network layer for messages that the SDK treats as pending.

## Quick Start

```rust
use std::sync::Arc;

use alloy_primitives::Address;
use p2p::{P2pClient, P2pClientConfig, SdkEvent};
use rpc::MockPreconfEngine;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 1) Configure the SDK.
    let mut config = P2pClientConfig::with_chain_id(167_000);
    config.expected_slasher = Some(Address::ZERO);
    config.engine = Some(Arc::new(MockPreconfEngine::default()));

    // 2) Create the client and event receiver.
    let (client, mut events) = P2pClient::new(config)?;

    // 3) Spawn the client loop.
    let handle = client.handle();
    tokio::spawn(async move {
        if let Err(e) = client.run().await {
            eprintln!("client error: {e}");
        }
    });

    // 4) Process SDK events.
    while let Ok(event) = events.recv().await {
        match event {
            SdkEvent::CommitmentGossip { from, .. } => {
                println!("commitment from {from}");
            }
            SdkEvent::HeadSyncStatus { synced } => {
                println!("head sync status: {synced}");
            }
            _ => {}
        }
    }

    // Use the handle for commands (publish, request, catch-up, shutdown).
    let _ = handle;
    Ok(())
}
```

## Key Concepts

- **Network vs SDK**: `preconfirmation-net` handles libp2p and scoring; this SDK
  adds validation, storage, and a typed event/command API.
- **Commitments and txlists**: commitments reference a `raw_tx_list_hash` that
  can be fetched via req/resp if not already known.
- **Events and commands**: `SdkEvent` is the inbound stream; `P2pClientHandle`
  sends outbound `SdkCommand` actions.
- **Pending buffer**: child commitments that arrive before their parents are
  buffered and released when the parent arrives.
- **Catch-up**: on startup or reconnect, the SDK syncs from local head to the
  network head and then transitions to live gossip.

## Configuration

`P2pClientConfig` embeds the network config and adds SDK-specific knobs.

Key fields:

- `network: P2pConfig` (from `preconfirmation-net`)
- `chain_id`: must match `network.chain_id`
- `expected_slasher`: required when no custom network validator is provided
- `engine`: required for execution and applying commitments
- `max_txlist_bytes`, `dedupe_cache_cap`, `max_commitments_per_page`
- `catchup_initial_backoff`, `catchup_max_backoff`, `catchup_max_retries`
- `enable_metrics`

Example network tuning:

```rust
use std::time::Duration;

let mut config = p2p::P2pClientConfig::with_chain_id(167_000);
config.expected_slasher = Some(alloy_primitives::Address::ZERO);
config.engine = Some(std::sync::Arc::new(rpc::MockPreconfEngine::default()));

// Network settings (preconfirmation-net)
config.network.listen_addr = "0.0.0.0:9000".parse().unwrap();
config.network.discovery_listen = "0.0.0.0:9001".parse().unwrap();
config.network.bootnodes = vec!["<enr-or-multiaddr>".to_string()];
config.network.enable_discovery = true;
config.network.request_timeout = Duration::from_secs(10);
```

## Commands and Events

`P2pClientHandle` provides convenience methods for commands. Internally these
map to `SdkCommand` variants:

| Command | Purpose |
| --- | --- |
| `PublishCommitment` | Gossip a signed commitment |
| `PublishRawTxList` | Gossip a raw txlist |
| `RequestCommitments` | Req/resp page of commitments |
| `RequestRawTxList` | Req/resp raw txlist by hash |
| `RequestHead` | Req/resp current head |
| `UpdateHead` | Update local head and broadcast |
| `StartCatchup` | Start catch-up from local to network head |
| `Shutdown` | Graceful shutdown |
| `NotifyReorg` | Emit a reorg signal to consumers |

`SdkEvent` is the inbound stream:

| Event | Meaning |
| --- | --- |
| `PeerConnected` / `PeerDisconnected` | Peer lifecycle |
| `CommitmentGossip` | Validated commitment from gossip |
| `RawTxListGossip` | Validated txlist from gossip |
| `ReqRespCommitments` | Response to `RequestCommitments` |
| `ReqRespRawTxList` | Response to `RequestRawTxList` |
| `ReqRespHead` | Response to `RequestHead` |
| `HeadSyncStatus` | Catch-up sync status updates |
| `Reorg` | L1 reorg signal (consumer re-exec required) |
| `Error` | SDK error surfaced to consumers |

## Validation Rules

Validation lives in `p2p::validation` and is applied to both gossip and
catch-up. The SDK enforces:

- **Signature**: recover signer from commitment signature
- **EOP rule**: non-EOP commitments must have non-zero `raw_tx_list_hash`
- **Parent linkage**: `parent_preconfirmation_hash` must match parent hash
- **Block progression**: child block number must equal parent + 1
- **Block params progression**: timestamp strictly increases; anchor block number
  is monotonic
- **Txlist hash**: keccak256(txlist) matches `raw_tx_list_hash`
- **Txlist size**: size <= `max_txlist_bytes`

Pending commitments (missing parent) are buffered and revalidated when the
parent arrives. Genesis commitments (block 0 with zero parent hash) are allowed
without a stored parent.

You can inject custom block-parameter validation with
`CommitmentValidator::with_hook`. Schedule-based validation at the network
layer is supported via `P2pClient::with_validation_adapter`.

## Catch-up Flow

Catch-up uses a state machine (`CatchupPipeline`) that:

1. Requests the network head (if not provided)
2. Pages commitments from local head to network head
3. Requests missing raw txlists by hash
4. Emits `HeadSyncStatus` when synced

Start catch-up with:

```rust
handle.start_catchup(local_head, 0).await?;
```

Passing `0` for `network_head` tells the SDK to request the head from peers
before syncing. Validation is the same as gossip, and pending commitments are
buffered as needed.

## Storage and Deduplication

`InMemoryStorage` provides:

- Message ID dedupe (topic + payload hash)
- Commitment dedupe (block number + signer)
- Txlist dedupe (block number + hash)
- Pending buffer keyed by parent hash

Note: the SDK currently supports in-memory storage only.

## Metrics

If `P2pClientConfig.enable_metrics` is `true`, the client registers Prometheus
metrics on startup. You can also call `P2pMetrics::init()` early to register
descriptors.

Key metrics:

- `p2p_gossip_received_total` / `p2p_gossip_published_total`
- `p2p_validation_results_total{result=valid|pending|invalid}`
- `p2p_pending_buffer_size`
- `p2p_reqresp_latency_seconds`
- `p2p_head_sync_status`

## Examples

See `crates/p2p/examples/basic.rs` for a minimal flow. It is compile-only by
default; to run the networked example:

```bash
P2P_EXAMPLE_RUN=1 cargo run -p p2p --example basic
```

## Testing

From repo root:

```bash
just test
```

To scope to this crate:

```bash
TEST_CRATE=p2p just test
```

## Troubleshooting

- `config error: expected_slasher is required...`: set `expected_slasher` or
  pass a custom `ValidationAdapter`.
- `config error: chain_id mismatch`: ensure `config.chain_id` matches
  `config.network.chain_id`.
- No events received: confirm `client.run()` is running and you subscribed to
  the broadcast channel.
- Sync stalls with many pending items: parents are missing; verify peers are
  serving older commitments or bootstrap from a known head.
- Example exits immediately: set `P2P_EXAMPLE_RUN=1`.

## Limitations

- Pending/no-penalty semantics are enforced inside the SDK, but gossipsub
  scoring happens in `preconfirmation-net` and may still penalize peers.
- Storage is in-memory only; persistence hooks are not currently exposed.
- Reorg handling emits `SdkEvent::Reorg` but application-specific re-execution
  is up to the consumer.
