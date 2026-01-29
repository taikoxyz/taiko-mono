# preconfirmation-driver

A preconfirmation integration library for Taiko, combining P2P network participation with embedded driver communication via channels.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   Preconfirmation driver node                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────────┐    ┌───────────────┐  │
│  │  Sidecar     │───>│  P2P Client      │───>│  Embedded     │  │
│  │  JSON-RPC    │    │  (gossip, sync)  │    │  Driver       │  │
│  └──────────────┘    └──────────────────┘    └───────────────┘  │
│        ▲                     │                      │           │
│        │                     ▼                      ▼           │
│  External          Commitment/TxList        Execution Engine    │
│  Clients           Validation              (block production)   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### Preconfirmation driver node (`PreconfirmationDriverNode`)

The main orchestrator that combines:

- **EmbeddedDriverClient**: Channel-based communication with the driver (no serialization overhead)
- **PreconfirmationClient**: P2P network operations (gossip, commitment validation, tip catch-up)
- **PreconfRpcServer**: Preconfirmation sidecar JSON-RPC API for external clients

### RPC API

Preconfirmation sidecar JSON-RPC methods:

| Method                        | Description                                      |
| ----------------------------- | ------------------------------------------------ |
| `preconf_publishCommitment`   | Publish a signed preconfirmation commitment      |
| `preconf_publishTxList`       | Publish an encoded transaction list (RLP + zlib) |
| `preconf_getStatus`           | Get current node status                          |
| `preconf_tip`                 | Get preconfirmation tip block number             |
| `preconf_canonicalProposalId` | Get last canonical proposal ID                   |

## Usage

### Basic Setup

```rust
use preconfirmation_driver::{
    ContractInboxReader, PreconfirmationDriverNode, PreconfirmationDriverNodeConfig,
    PreconfirmationClientConfig, PreconfRpcServerConfig,
};
use preconfirmation_net::P2pConfig;
use alloy_primitives::Address;

// Build the P2P config and lookahead resolver (async).
let p2p_config = P2pConfig::default();
let inbox_address = Address::ZERO;
let provider = /* your alloy Provider */;

let client_config = PreconfirmationClientConfig::new(
    p2p_config,
    inbox_address,
    provider.clone(),
)
.await?;

// Create node configuration
let config = PreconfirmationDriverNodeConfig::new(client_config)
    .with_rpc(PreconfRpcServerConfig::default())
    .with_driver_channel_capacity(256);

// Create the inbox reader for L1 sync state verification
let inbox_instance = /* your Inbox contract instance */;
let inbox_reader = ContractInboxReader::new(inbox_instance);

// Create the node and get driver channels
let (node, channels) = PreconfirmationDriverNode::new(config, inbox_reader)?;

// Wire channels to your driver
// driver.set_input_rx(channels.input_rx);
// driver.set_canonical_id_tx(channels.canonical_proposal_id_tx);
// driver.set_preconf_tip_tx(channels.preconf_tip_tx);

// Start the node
node.run().await?;
```

If you already have a lookahead resolver, build the client config directly:

```rust
use std::sync::Arc;
use preconfirmation_driver::PreconfirmationClientConfig;
use preconfirmation_net::P2pConfig;
use protocol::preconfirmation::PreconfSignerResolver;

let p2p_config = P2pConfig::default();
let resolver: Arc<dyn PreconfSignerResolver + Send + Sync> = /* ... */;

let client_config = PreconfirmationClientConfig::new_with_resolver(p2p_config, resolver);
```

### Using EmbeddedDriverClient Directly

```rust
use preconfirmation_driver::{ContractInboxReader, EmbeddedDriverClient};
use alloy_primitives::U256;
use tokio::sync::{mpsc, watch};

let (input_tx, input_rx) = mpsc::channel(256);
let (canonical_id_tx, canonical_id_rx) = watch::channel(0u64);
let (preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);

// Create the inbox reader for L1 sync state verification
let inbox_instance = /* your Inbox contract instance */;
let inbox_reader = ContractInboxReader::new(inbox_instance);

let client = EmbeddedDriverClient::new(input_tx, canonical_id_rx, preconf_tip_rx, inbox_reader);

// Submit preconfirmation input
// let input = PreconfirmationInput::new(...);
client.submit_preconfirmation(input).await?;

// Query state
let tip = client.preconf_tip().await?;

// Wait for L1 sync (checks Inbox.getCoreState().nextProposalId)
client.wait_event_sync().await?;
```

## Module Structure

```
src/
├── client.rs           # PreconfirmationClient and EventLoop
│   └── mod.rs
├── config.rs           # Configuration types
├── driver_interface/   # Driver communication
│   ├── embedded.rs     # EmbeddedDriverClient
│   ├── payload.rs      # Payload building utilities
│   └── traits.rs       # DriverClient trait
├── error.rs            # Error types
├── metrics.rs          # Prometheus metrics
├── node.rs             # Preconfirmation driver node orchestrator
├── rpc/                # Preconfirmation sidecar JSON-RPC
│   ├── api.rs          # PreconfRpcApi trait
│   ├── server.rs       # HTTP JSON-RPC server
│   └── types.rs        # Request/response types
├── storage/            # Commitment storage
│   └── mod.rs
├── subscription/       # P2P event handling
│   └── mod.rs
├── sync/               # Tip catch-up logic
│   └── mod.rs
└── validation/         # Commitment validation
    └── mod.rs
```

## Testing

```bash
# Run unit tests
cargo test -p preconfirmation-driver --lib

# Run integration tests
cargo test -p preconfirmation-driver --test node_integration

# Run E2E tests (requires test environment)
PROTOCOL_DIR=/path/to/protocol cargo test -p preconfirmation-driver
```
