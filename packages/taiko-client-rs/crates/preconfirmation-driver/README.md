# preconfirmation-driver

A preconfirmation integration library for Taiko, combining P2P network participation with embedded driver communication via channels.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     PreconfirmationNode                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐    ┌──────────────────┐    ┌───────────────┐  │
│  │  User RPC    │───>│  P2P Client      │───>│  Embedded     │  │
│  │  Server      │    │  (gossip, sync)  │    │  Driver       │  │
│  └──────────────┘    └──────────────────┘    └───────────────┘  │
│        ▲                     │                      │           │
│        │                     ▼                      ▼           │
│  External          Commitment/TxList        Execution Engine    │
│  Clients           Validation              (block production)   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### PreconfirmationNode

The main orchestrator that combines:

- **EmbeddedDriverClient**: Channel-based communication with the driver (no serialization overhead)
- **PreconfirmationClient**: P2P network operations (gossip, commitment validation, tip catch-up)
- **PreconfRpcServer**: User-friendly JSON-RPC API for external clients

### RPC API

User-facing JSON-RPC methods:

| Method                        | Description                                 |
| ----------------------------- | ------------------------------------------- |
| `preconf_publishCommitment`   | Publish a signed preconfirmation commitment |
| `preconf_publishTxList`       | Publish a raw transaction list              |
| `preconf_getStatus`           | Get current node status                     |
| `preconf_getHead`             | Get current preconfirmation head            |
| `preconf_getLookahead`        | Get current lookahead information           |
| `preconf_tip`                 | Get preconfirmation tip block number        |
| `preconf_canonicalProposalId` | Get last canonical proposal ID              |

## Usage

### Basic Setup

```rust
use preconfirmation_driver::{
    PreconfirmationNode, PreconfirmationNodeConfig,
    PreconfirmationClientConfig, PreconfRpcServerConfig,
};

// Create node configuration
let config = PreconfirmationNodeConfig::new(p2p_config)
    .with_rpc(PreconfRpcServerConfig::default())
    .with_driver_channel_capacity(256);

// Create the node and get driver channels
let (node, channels) = PreconfirmationNode::new(config)?;

// Wire channels to your driver
// driver.set_input_receiver(channels.input_receiver);
// driver.set_canonical_id_sender(channels.canonical_proposal_id_sender);
// driver.set_preconf_tip_sender(channels.preconf_tip_sender);

// Start the node
node.run().await?;
```

### Using EmbeddedDriverClient Directly

```rust
use preconfirmation_driver::EmbeddedDriverClient;
use tokio::sync::{mpsc, watch};

let (input_tx, input_rx) = mpsc::channel(256);
let (canonical_id_tx, canonical_id_rx) = watch::channel(0u64);
let (preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);

let client = EmbeddedDriverClient::new(input_tx, canonical_id_rx, preconf_tip_rx);

// Submit preconfirmation input
client.submit_preconfirmation(input).await?;

// Query state
let tip = client.preconf_tip().await?;
```

## Module Structure

```
src/
├── client.rs           # PreconfirmationClient and EventLoop
├── codec.rs            # Txlist compression utilities
├── config.rs           # Configuration types
├── driver_interface/   # Driver communication
│   ├── embedded.rs     # EmbeddedDriverClient
│   ├── payload.rs      # Payload building utilities
│   └── traits.rs       # DriverClient trait
├── error.rs            # Error types
├── metrics.rs          # Prometheus metrics
├── node.rs             # PreconfirmationNode orchestrator
├── rpc/                # User-facing RPC
│   ├── api.rs          # PreconfRpcApi trait
│   ├── server.rs       # HTTP JSON-RPC server
│   └── types.rs        # Request/response types
├── storage/            # Commitment storage
├── subscription.rs     # P2P event handling
├── sync.rs             # Tip catch-up logic
└── validation.rs       # Commitment validation
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
