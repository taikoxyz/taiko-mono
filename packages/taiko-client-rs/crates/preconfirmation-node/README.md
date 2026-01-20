# Preconfirmation Node

A complete preconfirmation node for Taiko that combines:

- **Driver**: L2 block execution and sync
- **Preconfirmation Client**: P2P network participation
- **RPC Server**: User-facing JSON-RPC API

## Architecture

```
User → (JSON-RPC) → PreconfirmationNode
                        ├── Driver (embedded)
                        ├── PreconfClient (direct calls)
                        └── RPC Server (HTTP)
```

## RPC API

The node exposes these JSON-RPC methods on the configured HTTP port:

### Publishing

- `preconf_publishCommitment(commitment)` - Publish a signed commitment to P2P
- `preconf_publishTxList(txlist)` - Publish a transaction list to P2P

### Querying

- `preconf_getCommitments(from_block, to_block)` - Get commitments in range
- `preconf_getTxList(commitment_hash)` - Get transaction list by hash
- `preconf_getStatus()` - Get current node status

## Usage

```rust
use preconfirmation_node::{PreconfirmationNode, PreconfirmationNodeConfig, RpcServerConfig};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = PreconfirmationNodeConfig {
        driver: driver_config,
        preconf: preconf_config,
        rpc: RpcServerConfig::default(),
    };

    let node = PreconfirmationNode::new(config).await?;
    node.run().await?;

    Ok(())
}
```

## Configuration

- `driver`: Driver configuration (L1/L2 endpoints, etc.)
- `preconf.p2p`: P2P network configuration
- `preconf.lookahead_resolver`: Lookahead signer resolver
- `rpc.http_addr`: HTTP server bind address (default: `127.0.0.1:8550`)
- `rpc.p2p_request_timeout`: Timeout for P2P requests (default: 5s)
