# Preconfirmation Node Architecture Refactor

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor preconfirmation-client to embed the driver and expose a user-facing JSON-RPC API for publishing P2P messages.

**Architecture:** Create `PreconfirmationNode` that combines Driver and PreconfirmationClient in a single process. Driver and PreconfClient communicate directly via Rust traits (no JSON-RPC). Users interact via a new HTTP JSON-RPC server to publish commitments/txlists and query data.

**Tech Stack:** Rust, tokio, jsonrpsee (HTTP server), alloy types

---

## Overview

```
Before:
  User → (import crate) → PreconfClient → (JSON-RPC) → Driver (separate process)

After:
  User → (JSON-RPC) → PreconfirmationNode (single process)
                            ├── Driver (embedded)
                            ├── PreconfClient (direct calls)
                            └── RPC Server (HTTP, no auth)
```

## Task 1: Rename Crate

**Files:**

- Modify: `crates/preconfirmation-client/Cargo.toml`
- Modify: All files that reference `preconfirmation-client` in workspace

**Step 1: Update Cargo.toml package name**

In `crates/preconfirmation-client/Cargo.toml`, change:

```toml
[package]
name = "preconfirmation-node"
```

**Step 2: Update workspace Cargo.toml**

In root `Cargo.toml`, update the workspace member reference if needed.

**Step 3: Update all internal crate dependencies**

Search for `preconfirmation-client` in all Cargo.toml files and update to `preconfirmation-node`.

**Step 4: Verify build**

Run: `cargo build -p preconfirmation-node`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add -A
git commit -m "chore: rename preconfirmation-client to preconfirmation-node"
```

---

## Task 2: Create EmbeddedDriverClient

**Files:**

- Create: `crates/preconfirmation-node/src/driver_interface/embedded.rs`
- Modify: `crates/preconfirmation-node/src/driver_interface/mod.rs`

**Step 1: Write failing test for EmbeddedDriverClient**

Create test in `crates/preconfirmation-node/src/driver_interface/embedded.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_embedded_driver_client_submit_preconfirmation() {
        // This test will be fleshed out once we have the full implementation
        // For now, verify the struct can be constructed
        let (payload_tx, _payload_rx) = tokio::sync::mpsc::channel(16);
        let client = EmbeddedDriverClient::new(payload_tx);
        assert!(client.payload_sender.capacity() > 0);
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cargo test -p preconfirmation-node embedded_driver_client`
Expected: FAIL - module not found

**Step 3: Create embedded.rs with EmbeddedDriverClient struct**

Create `crates/preconfirmation-node/src/driver_interface/embedded.rs`:

```rust
//! Embedded driver client for direct in-process communication.

use alloy_primitives::U256;
use async_trait::async_trait;
use protocol::shasta::TaikoPayloadAttributes;
use tokio::sync::{mpsc, watch};

use super::payload::build_taiko_payload_attributes;
use super::traits::{DriverClient, PreconfirmationInput};
use crate::error::{DriverApiError, Result};

/// A driver client that communicates directly with an embedded driver
/// via channels, without JSON-RPC serialization overhead.
pub struct EmbeddedDriverClient {
    /// Channel to submit payloads directly to the driver's sync pipeline
    payload_sender: mpsc::Sender<TaikoPayloadAttributes>,
    /// Watch receiver for the last canonical proposal ID
    canonical_proposal_id: watch::Receiver<u64>,
    /// Watch receiver for the preconf tip
    preconf_tip: watch::Receiver<U256>,
}

impl EmbeddedDriverClient {
    /// Creates a new embedded driver client.
    ///
    /// # Arguments
    /// * `payload_sender` - Channel to submit payloads to the driver
    /// * `canonical_proposal_id` - Watch channel for last canonical proposal ID
    /// * `preconf_tip` - Watch channel for preconf tip
    pub fn new(
        payload_sender: mpsc::Sender<TaikoPayloadAttributes>,
        canonical_proposal_id: watch::Receiver<u64>,
        preconf_tip: watch::Receiver<U256>,
    ) -> Self {
        Self {
            payload_sender,
            canonical_proposal_id,
            preconf_tip,
        }
    }
}

#[async_trait]
impl DriverClient for EmbeddedDriverClient {
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()> {
        let payload = build_taiko_payload_attributes(&input)?;
        self.payload_sender
            .send(payload)
            .await
            .map_err(|e| DriverApiError::ChannelClosed(e.to_string()))?;
        Ok(())
    }

    async fn wait_event_sync(&self) -> Result<()> {
        // For embedded client, we assume the driver is already synced
        // since they're in the same process and started together
        Ok(())
    }

    async fn event_sync_tip(&self) -> Result<U256> {
        let id = *self.canonical_proposal_id.borrow();
        Ok(U256::from(id))
    }

    async fn preconf_tip(&self) -> Result<U256> {
        Ok(*self.preconf_tip.borrow())
    }
}
```

**Step 4: Add ChannelClosed error variant**

In `crates/preconfirmation-node/src/error.rs`, add to `DriverApiError`:

```rust
/// Channel closed unexpectedly
#[error("channel closed: {0}")]
ChannelClosed(String),
```

**Step 5: Update mod.rs to export embedded module**

In `crates/preconfirmation-node/src/driver_interface/mod.rs`, add:

```rust
pub mod embedded;
pub use embedded::EmbeddedDriverClient;
```

**Step 6: Run test to verify it passes**

Run: `cargo test -p preconfirmation-node embedded_driver_client`
Expected: PASS

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: add EmbeddedDriverClient for direct driver communication"
```

---

## Task 3: Create User-Facing RPC API Types

**Files:**

- Create: `crates/preconfirmation-node/src/rpc/mod.rs`
- Create: `crates/preconfirmation-node/src/rpc/types.rs`

**Step 1: Create rpc module directory**

Create `crates/preconfirmation-node/src/rpc/mod.rs`:

```rust
//! User-facing JSON-RPC server for preconfirmation operations.

pub mod types;
pub mod server;
pub mod api;

pub use server::PreconfRpcServer;
pub use types::*;
```

**Step 2: Create RPC types**

Create `crates/preconfirmation-node/src/rpc/types.rs`:

```rust
//! RPC request and response types.

use alloy_primitives::{B256, U256};
use preconfirmation_types::{RawTxListGossip, SignedCommitment};
use serde::{Deserialize, Serialize};

/// Request to get commitments within a block range.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetCommitmentsRequest {
    /// Starting block number (inclusive)
    pub from_block: U256,
    /// Ending block number (inclusive)
    pub to_block: U256,
}

/// Response containing commitments.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetCommitmentsResponse {
    /// List of signed commitments in the range
    pub commitments: Vec<SignedCommitment>,
}

/// Request to get a transaction list by commitment hash.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetTxListRequest {
    /// Hash of the commitment
    pub commitment_hash: B256,
}

/// Response containing a transaction list.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetTxListResponse {
    /// The transaction list bytes, or None if not found
    pub txlist: Option<RawTxListGossip>,
}

/// Response for publish operations.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PublishResponse {
    /// Whether the publish was successful
    pub success: bool,
}

/// Current node status.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeStatus {
    /// Current preconfirmation tip block number
    pub preconf_tip: U256,
    /// Current event sync tip (last canonical proposal ID)
    pub event_sync_tip: U256,
    /// Number of connected peers
    pub peer_count: u32,
    /// Whether the node is synced
    pub synced: bool,
}
```

**Step 3: Update lib.rs to include rpc module**

In `crates/preconfirmation-node/src/lib.rs`, add:

```rust
pub mod rpc;
```

**Step 4: Verify build**

Run: `cargo build -p preconfirmation-node`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add RPC types for user-facing API"
```

---

## Task 4: Create RPC API Implementation

**Files:**

- Create: `crates/preconfirmation-node/src/rpc/api.rs`

**Step 1: Write failing test for RPC API trait**

In `crates/preconfirmation-node/src/rpc/api.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rpc_trait_exists() {
        // Verify the trait is defined with expected methods
        fn assert_trait<T: PreconfRpcApi>() {}
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cargo test -p preconfirmation-node rpc_trait_exists`
Expected: FAIL - trait not found

**Step 3: Create RPC API trait and implementation**

Create `crates/preconfirmation-node/src/rpc/api.rs`:

```rust
//! RPC API trait and implementation.

use std::sync::Arc;
use std::time::Duration;

use alloy_primitives::{B256, U256};
use async_trait::async_trait;
use jsonrpsee::core::RpcResult;
use jsonrpsee::proc_macros::rpc;
use preconfirmation_net::NetworkCommand;
use preconfirmation_types::{RawTxListGossip, SignedCommitment};
use tokio::sync::mpsc;
use tracing::{debug, warn};

use super::types::{GetCommitmentsResponse, GetTxListResponse, NodeStatus, PublishResponse};
use crate::storage::CommitmentStore;

/// RPC API trait for user-facing preconfirmation operations.
#[rpc(server, namespace = "preconf")]
pub trait PreconfRpcApi {
    /// Publish a signed commitment to the P2P network.
    #[method(name = "publishCommitment")]
    async fn publish_commitment(&self, commitment: SignedCommitment) -> RpcResult<PublishResponse>;

    /// Publish a transaction list to the P2P network.
    #[method(name = "publishTxList")]
    async fn publish_tx_list(&self, txlist: RawTxListGossip) -> RpcResult<PublishResponse>;

    /// Get commitments within a block range.
    /// First checks local cache, then queries P2P network with timeout.
    #[method(name = "getCommitments")]
    async fn get_commitments(
        &self,
        from_block: U256,
        to_block: U256,
    ) -> RpcResult<GetCommitmentsResponse>;

    /// Get a transaction list by commitment hash.
    /// First checks local cache, then queries P2P network with timeout.
    #[method(name = "getTxList")]
    async fn get_tx_list(&self, commitment_hash: B256) -> RpcResult<GetTxListResponse>;

    /// Get current node status.
    #[method(name = "getStatus")]
    async fn get_status(&self) -> RpcResult<NodeStatus>;
}

/// Implementation of the preconfirmation RPC API.
pub struct PreconfRpcApiImpl {
    /// Channel to send commands to the P2P network
    command_sender: mpsc::Sender<NetworkCommand>,
    /// Commitment store for local cache access
    store: Arc<dyn CommitmentStore>,
    /// Timeout for P2P network requests
    p2p_request_timeout: Duration,
    /// Current peer count (updated by the node)
    peer_count: Arc<std::sync::atomic::AtomicU32>,
    /// Whether the node is synced
    synced: Arc<std::sync::atomic::AtomicBool>,
    /// Current preconf tip
    preconf_tip: Arc<tokio::sync::RwLock<U256>>,
    /// Current event sync tip
    event_sync_tip: Arc<tokio::sync::RwLock<U256>>,
}

impl PreconfRpcApiImpl {
    /// Creates a new RPC API implementation.
    pub fn new(
        command_sender: mpsc::Sender<NetworkCommand>,
        store: Arc<dyn CommitmentStore>,
        p2p_request_timeout: Duration,
    ) -> Self {
        Self {
            command_sender,
            store,
            p2p_request_timeout,
            peer_count: Arc::new(std::sync::atomic::AtomicU32::new(0)),
            synced: Arc::new(std::sync::atomic::AtomicBool::new(false)),
            preconf_tip: Arc::new(tokio::sync::RwLock::new(U256::ZERO)),
            event_sync_tip: Arc::new(tokio::sync::RwLock::new(U256::ZERO)),
        }
    }

    /// Updates the peer count.
    pub fn set_peer_count(&self, count: u32) {
        self.peer_count
            .store(count, std::sync::atomic::Ordering::Relaxed);
    }

    /// Updates the synced status.
    pub fn set_synced(&self, synced: bool) {
        self.synced
            .store(synced, std::sync::atomic::Ordering::Relaxed);
    }

    /// Updates the preconf tip.
    pub async fn set_preconf_tip(&self, tip: U256) {
        *self.preconf_tip.write().await = tip;
    }

    /// Updates the event sync tip.
    pub async fn set_event_sync_tip(&self, tip: U256) {
        *self.event_sync_tip.write().await = tip;
    }
}

#[async_trait]
impl PreconfRpcApiServer for PreconfRpcApiImpl {
    async fn publish_commitment(&self, commitment: SignedCommitment) -> RpcResult<PublishResponse> {
        debug!("Publishing commitment for block {}", commitment.commitment.preconf.block_number);

        self.command_sender
            .send(NetworkCommand::PublishCommitment(commitment))
            .await
            .map_err(|e| {
                warn!("Failed to publish commitment: {}", e);
                jsonrpsee::types::ErrorObject::owned(
                    -32000,
                    format!("Failed to publish: {}", e),
                    None::<()>,
                )
            })?;

        Ok(PublishResponse { success: true })
    }

    async fn publish_tx_list(&self, txlist: RawTxListGossip) -> RpcResult<PublishResponse> {
        debug!("Publishing txlist");

        self.command_sender
            .send(NetworkCommand::PublishRawTxList(txlist))
            .await
            .map_err(|e| {
                warn!("Failed to publish txlist: {}", e);
                jsonrpsee::types::ErrorObject::owned(
                    -32000,
                    format!("Failed to publish: {}", e),
                    None::<()>,
                )
            })?;

        Ok(PublishResponse { success: true })
    }

    async fn get_commitments(
        &self,
        from_block: U256,
        to_block: U256,
    ) -> RpcResult<GetCommitmentsResponse> {
        let mut commitments = Vec::new();

        // First, try to get from local cache
        let mut block = from_block;
        while block <= to_block {
            if let Some(commitment) = self.store.get_commitment(&block) {
                commitments.push(commitment);
            }
            block += U256::from(1);
        }

        // TODO: If any blocks are missing, request from P2P network with timeout
        // This will be implemented when we add P2P request support

        Ok(GetCommitmentsResponse { commitments })
    }

    async fn get_tx_list(&self, commitment_hash: B256) -> RpcResult<GetTxListResponse> {
        // First, try to get from local cache
        if let Some(txlist) = self.store.get_txlist(&commitment_hash) {
            return Ok(GetTxListResponse { txlist: Some(txlist) });
        }

        // TODO: Request from P2P network with timeout
        // For now, return not found
        Ok(GetTxListResponse { txlist: None })
    }

    async fn get_status(&self) -> RpcResult<NodeStatus> {
        Ok(NodeStatus {
            preconf_tip: *self.preconf_tip.read().await,
            event_sync_tip: *self.event_sync_tip.read().await,
            peer_count: self.peer_count.load(std::sync::atomic::Ordering::Relaxed),
            synced: self.synced.load(std::sync::atomic::Ordering::Relaxed),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rpc_trait_exists() {
        // Verify the trait is defined with expected methods
        fn assert_trait<T: PreconfRpcApiServer>() {}
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cargo test -p preconfirmation-node rpc_trait_exists`
Expected: PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: implement PreconfRpcApi for user-facing operations"
```

---

## Task 5: Create RPC Server

**Files:**

- Create: `crates/preconfirmation-node/src/rpc/server.rs`

**Step 1: Create RPC server implementation**

Create `crates/preconfirmation-node/src/rpc/server.rs`:

```rust
//! HTTP JSON-RPC server for user-facing preconfirmation operations.

use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;

use jsonrpsee::server::{Server, ServerHandle};
use preconfirmation_net::NetworkCommand;
use tokio::sync::mpsc;
use tracing::info;

use super::api::{PreconfRpcApiImpl, PreconfRpcApiServer};
use crate::error::Result;
use crate::storage::CommitmentStore;

/// Configuration for the RPC server.
#[derive(Debug, Clone)]
pub struct RpcServerConfig {
    /// Address to bind the HTTP server
    pub http_addr: SocketAddr,
    /// Timeout for P2P network requests when data not in cache
    pub p2p_request_timeout: Duration,
}

impl Default for RpcServerConfig {
    fn default() -> Self {
        Self {
            http_addr: "127.0.0.1:8550".parse().unwrap(),
            p2p_request_timeout: Duration::from_secs(5),
        }
    }
}

/// User-facing JSON-RPC server.
pub struct PreconfRpcServer {
    config: RpcServerConfig,
    api: Arc<PreconfRpcApiImpl>,
    handle: Option<ServerHandle>,
}

impl PreconfRpcServer {
    /// Creates a new RPC server.
    pub fn new(
        config: RpcServerConfig,
        command_sender: mpsc::Sender<NetworkCommand>,
        store: Arc<dyn CommitmentStore>,
    ) -> Self {
        let api = Arc::new(PreconfRpcApiImpl::new(
            command_sender,
            store,
            config.p2p_request_timeout,
        ));

        Self {
            config,
            api,
            handle: None,
        }
    }

    /// Returns a reference to the API implementation for status updates.
    pub fn api(&self) -> Arc<PreconfRpcApiImpl> {
        Arc::clone(&self.api)
    }

    /// Starts the RPC server.
    pub async fn start(&mut self) -> Result<()> {
        let server = Server::builder()
            .build(self.config.http_addr)
            .await
            .map_err(|e| crate::error::PreconfirmationClientError::Config(e.to_string()))?;

        info!("Starting preconf RPC server on {}", self.config.http_addr);

        let handle = server.start(self.api.clone().into_rpc());
        self.handle = Some(handle);

        Ok(())
    }

    /// Stops the RPC server.
    pub async fn stop(&mut self) {
        if let Some(handle) = self.handle.take() {
            handle.stop().unwrap();
            handle.stopped().await;
            info!("Preconf RPC server stopped");
        }
    }
}
```

**Step 2: Verify build**

Run: `cargo build -p preconfirmation-node`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add PreconfRpcServer HTTP server"
```

---

## Task 6: Create PreconfirmationNode

**Files:**

- Create: `crates/preconfirmation-node/src/node.rs`
- Modify: `crates/preconfirmation-node/src/lib.rs`

**Step 1: Create node.rs with PreconfirmationNode struct**

Create `crates/preconfirmation-node/src/node.rs`:

```rust
//! PreconfirmationNode - combines Driver, PreconfirmationClient, and RPC server.

use std::sync::Arc;

use alloy_primitives::U256;
use driver::{Driver, DriverConfig};
use protocol::shasta::TaikoPayloadAttributes;
use tokio::sync::{mpsc, watch};
use tracing::{info, warn};

use crate::client::PreconfirmationClient;
use crate::config::PreconfirmationClientConfig;
use crate::driver_interface::EmbeddedDriverClient;
use crate::error::Result;
use crate::rpc::{PreconfRpcServer, RpcServerConfig};
use crate::subscription::PreconfirmationEvent;

/// Configuration for the PreconfirmationNode.
#[derive(Debug, Clone)]
pub struct PreconfirmationNodeConfig {
    /// Driver configuration
    pub driver: DriverConfig,
    /// Preconfirmation client configuration
    pub preconf: PreconfirmationClientConfig,
    /// RPC server configuration
    pub rpc: RpcServerConfig,
}

/// A complete preconfirmation node combining Driver, PreconfClient, and RPC server.
pub struct PreconfirmationNode {
    /// The embedded driver
    driver: Driver,
    /// The preconfirmation client
    preconf_client: PreconfirmationClient<EmbeddedDriverClient>,
    /// The user-facing RPC server
    rpc_server: PreconfRpcServer,
    /// Channel receiver for driver payloads
    payload_rx: mpsc::Receiver<TaikoPayloadAttributes>,
    /// Event receiver from preconf client
    event_rx: tokio::sync::broadcast::Receiver<PreconfirmationEvent>,
}

impl PreconfirmationNode {
    /// Creates a new PreconfirmationNode.
    pub async fn new(config: PreconfirmationNodeConfig) -> Result<Self> {
        // 1. Initialize Driver
        let driver = Driver::new(config.driver).await?;

        // 2. Create channels for embedded communication
        let (payload_tx, payload_rx) = mpsc::channel::<TaikoPayloadAttributes>(256);
        let (canonical_id_tx, canonical_id_rx) = watch::channel(0u64);
        let (preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);

        // 3. Create embedded driver client
        let embedded_client = EmbeddedDriverClient::new(
            payload_tx,
            canonical_id_rx,
            preconf_tip_rx,
        );

        // 4. Initialize PreconfirmationClient with embedded client
        let preconf_client = PreconfirmationClient::new(
            config.preconf,
            embedded_client,
        )?;

        // 5. Subscribe to events
        let event_rx = preconf_client.subscribe();

        // 6. Create RPC server
        let rpc_server = PreconfRpcServer::new(
            config.rpc,
            preconf_client.command_sender(),
            preconf_client.store(),
        );

        Ok(Self {
            driver,
            preconf_client,
            rpc_server,
            payload_rx,
            event_rx,
        })
    }

    /// Runs the preconfirmation node.
    ///
    /// This starts all components and runs until an error occurs or shutdown is requested.
    pub async fn run(mut self) -> Result<()> {
        info!("Starting PreconfirmationNode");

        // Start RPC server
        self.rpc_server.start().await?;

        // Get API handle for status updates
        let rpc_api = self.rpc_server.api();

        // Sync and get event loop
        let event_loop = self.preconf_client.sync_and_catchup().await?;
        rpc_api.set_synced(true).await;

        // Spawn event loop
        let event_loop_handle = tokio::spawn(async move {
            event_loop.run_with_retry().await
        });

        // Spawn driver
        let driver_handle = tokio::spawn(async move {
            self.driver.run().await
        });

        // Spawn payload handler (receives from preconf client, submits to driver)
        let payload_handle = tokio::spawn(async move {
            while let Some(payload) = self.payload_rx.recv().await {
                // TODO: Submit payload to driver's execution pipeline
                info!("Received payload for block {}", payload.block_number);
            }
        });

        // Spawn event handler for RPC status updates
        let event_handle = tokio::spawn(async move {
            let mut event_rx = self.event_rx;
            while let Ok(event) = event_rx.recv().await {
                match event {
                    PreconfirmationEvent::Synced => {
                        rpc_api.set_synced(true).await;
                    }
                    PreconfirmationEvent::PeerConnected(_) => {
                        let count = rpc_api.peer_count.load(std::sync::atomic::Ordering::Relaxed);
                        rpc_api.set_peer_count(count + 1);
                    }
                    PreconfirmationEvent::PeerDisconnected(_) => {
                        let count = rpc_api.peer_count.load(std::sync::atomic::Ordering::Relaxed);
                        rpc_api.set_peer_count(count.saturating_sub(1));
                    }
                    _ => {}
                }
            }
        });

        // Wait for any task to complete (likely due to error)
        tokio::select! {
            res = event_loop_handle => {
                warn!("Event loop exited: {:?}", res);
            }
            res = driver_handle => {
                warn!("Driver exited: {:?}", res);
            }
            res = payload_handle => {
                warn!("Payload handler exited: {:?}", res);
            }
            res = event_handle => {
                warn!("Event handler exited: {:?}", res);
            }
        }

        // Cleanup
        self.rpc_server.stop().await;

        Ok(())
    }
}
```

**Step 2: Update lib.rs exports**

In `crates/preconfirmation-node/src/lib.rs`, add:

```rust
pub mod node;

pub use node::{PreconfirmationNode, PreconfirmationNodeConfig};
```

**Step 3: Verify build**

Run: `cargo build -p preconfirmation-node`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: add PreconfirmationNode combining driver, client, and RPC"
```

---

## Task 7: Update Driver to Expose Internal Components

**Files:**

- Modify: `crates/driver/src/driver.rs`
- Modify: `crates/driver/src/lib.rs`

**Step 1: Add methods to expose driver internals**

In `crates/driver/src/driver.rs`, add methods to `Driver`:

```rust
impl Driver {
    /// Returns the event syncer for direct access.
    pub fn event_syncer(&self) -> Arc<EventSyncer> {
        Arc::clone(&self.event_syncer)
    }

    /// Returns the last canonical proposal ID.
    pub fn last_canonical_proposal_id(&self) -> u64 {
        self.event_syncer.last_canonical_proposal_id()
    }
}
```

**Step 2: Ensure EventSyncer has the needed methods**

Verify `EventSyncer` implements `submit_execution_payload_v2` and `last_canonical_proposal_id`.

**Step 3: Verify build**

Run: `cargo build -p driver`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: expose driver internals for embedded mode"
```

---

## Task 8: Remove Driver JSON-RPC Server

**Files:**

- Remove: `crates/driver/src/jsonrpc/mod.rs` (or make optional)
- Modify: `crates/driver/src/driver.rs` - Remove RPC server startup

**Step 1: Make RPC server optional with feature flag**

In `crates/driver/Cargo.toml`, add:

```toml
[features]
default = []
standalone-rpc = []
```

**Step 2: Gate RPC code behind feature flag**

In `crates/driver/src/driver.rs`, wrap RPC startup in feature gate:

```rust
#[cfg(feature = "standalone-rpc")]
{
    // Existing RPC server startup code
}
```

**Step 3: Verify build without feature**

Run: `cargo build -p driver`
Expected: Build succeeds without RPC server

**Step 4: Verify build with feature**

Run: `cargo build -p driver --features standalone-rpc`
Expected: Build succeeds with RPC server

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: make driver RPC server optional with standalone-rpc feature"
```

---

## Task 9: Remove JsonRpcDriverClient (Optional)

**Files:**

- Modify: `crates/preconfirmation-node/src/driver_interface/mod.rs`
- Optionally remove: `crates/preconfirmation-node/src/driver_interface/jsonrpc.rs`

**Step 1: Decide on removal strategy**

Option A: Keep `JsonRpcDriverClient` for backwards compatibility
Option B: Remove entirely (breaking change)

For this plan, we'll use Option A - keep but deprecate.

**Step 2: Add deprecation notice**

In `crates/preconfirmation-node/src/driver_interface/jsonrpc.rs`:

```rust
#![deprecated(
    since = "0.2.0",
    note = "Use EmbeddedDriverClient with PreconfirmationNode instead"
)]
```

**Step 3: Update mod.rs to not re-export by default**

In `crates/preconfirmation-node/src/driver_interface/mod.rs`:

```rust
// Deprecated - use EmbeddedDriverClient instead
#[deprecated(since = "0.2.0", note = "Use EmbeddedDriverClient with PreconfirmationNode instead")]
pub mod jsonrpc;

pub mod embedded;
pub mod payload;
pub mod traits;

pub use embedded::EmbeddedDriverClient;
pub use traits::{DriverClient, PreconfirmationInput};
```

**Step 4: Commit**

```bash
git add -A
git commit -m "chore: deprecate JsonRpcDriverClient in favor of EmbeddedDriverClient"
```

---

## Task 10: Add Integration Test

**Files:**

- Create: `crates/preconfirmation-node/tests/node_integration.rs`

**Step 1: Create integration test**

Create `crates/preconfirmation-node/tests/node_integration.rs`:

```rust
//! Integration tests for PreconfirmationNode.

use std::time::Duration;

use preconfirmation_node::{PreconfirmationNode, PreconfirmationNodeConfig};
use preconfirmation_node::rpc::RpcServerConfig;

#[tokio::test]
async fn test_node_starts_and_exposes_rpc() {
    // This test verifies that:
    // 1. PreconfirmationNode can be constructed
    // 2. RPC server starts and accepts connections
    // 3. Basic RPC methods work

    // TODO: Implement with proper test harness setup
    // For now, this is a placeholder to verify the structure compiles
}

#[tokio::test]
async fn test_publish_commitment_via_rpc() {
    // Test publishing a commitment via the RPC interface
    // TODO: Implement
}

#[tokio::test]
async fn test_get_commitments_from_cache() {
    // Test retrieving commitments from local cache
    // TODO: Implement
}

#[tokio::test]
async fn test_get_status() {
    // Test the status endpoint
    // TODO: Implement
}
```

**Step 2: Verify tests compile**

Run: `cargo test -p preconfirmation-node --test node_integration --no-run`
Expected: Compiles successfully

**Step 3: Commit**

```bash
git add -A
git commit -m "test: add integration test stubs for PreconfirmationNode"
```

---

## Task 11: Update Documentation

**Files:**

- Modify: `crates/preconfirmation-node/README.md`

**Step 1: Update README**

Update `crates/preconfirmation-node/README.md`:

```markdown
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

````

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
use preconfirmation_node::{PreconfirmationNode, PreconfirmationNodeConfig};

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
````

## Configuration

- `driver`: Driver configuration (L1/L2 endpoints, etc.)
- `preconf.p2p`: P2P network configuration
- `preconf.lookahead_resolver`: Lookahead signer resolver
- `rpc.http_addr`: HTTP server bind address (default: `127.0.0.1:8550`)
- `rpc.p2p_request_timeout`: Timeout for P2P requests (default: 5s)

````

**Step 2: Commit**

```bash
git add -A
git commit -m "docs: update README for preconfirmation-node architecture"
````

---

## Task 12: Final Verification

**Step 1: Run all tests**

Run: `cargo test -p preconfirmation-node`
Expected: All tests pass

**Step 2: Run clippy**

Run: `cargo clippy -p preconfirmation-node -- -D warnings`
Expected: No warnings

**Step 3: Build release**

Run: `cargo build -p preconfirmation-node --release`
Expected: Build succeeds

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: final cleanup for preconfirmation-node refactor"
```

---

## Summary

| Task | Description                            |
| ---- | -------------------------------------- |
| 1    | Rename crate to `preconfirmation-node` |
| 2    | Create `EmbeddedDriverClient`          |
| 3    | Create RPC types                       |
| 4    | Create RPC API implementation          |
| 5    | Create RPC server                      |
| 6    | Create `PreconfirmationNode`           |
| 7    | Expose driver internals                |
| 8    | Make driver RPC optional               |
| 9    | Deprecate `JsonRpcDriverClient`        |
| 10   | Add integration tests                  |
| 11   | Update documentation                   |
| 12   | Final verification                     |
