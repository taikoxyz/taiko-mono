//! # P2P SDK for Taiko Preconfirmation Networking
//!
//! This crate provides a high-level SDK façade over [`preconfirmation-net`], layering
//! SDK storage, deduplication, validation, a catch-up pipeline, and a typed event API
//! for building preconfirmation-aware applications on Taiko.
//!
//! ## Overview
//!
//! The SDK manages:
//! - **Gossip messaging**: Receiving and publishing signed commitments and raw txlists
//! - **Request/Response protocols**: Querying peers for commitments, txlists, and head state
//! - **Validation**: EOP rules, parent linkage, block progression, signature verification
//! - **Deduplication**: Message-level, commitment-level, and txlist-level dedupe caches
//! - **Pending buffer**: Buffering out-of-order commitments awaiting parent arrival
//! - **Catch-up sync**: Syncing from local head to network head on startup or reconnect
//! - **Metrics**: Prometheus-compatible metrics for all operations
//!
//! Network-level validation is provided by `preconfirmation-net` adapters; this SDK
//! adds spec-required invariants (parent linkage, pending buffering, EOP rules,
//! block parameter progression) before surfacing events or storing locally.
//!
//! ## Architecture
//!
//! ```text
//! ┌─────────────────────────────────────────────────────────────────┐
//! │                      Application Layer                          │
//! │                  (Your Proposer/Sequencer)                      │
//! └───────────────────────────┬─────────────────────────────────────┘
//!                             │ SdkEvent / SdkCommand
//!                             ▼
//! ┌─────────────────────────────────────────────────────────────────┐
//! │                        P2P SDK (this crate)                     │
//! │  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
//! │  │  Validation  │  │   Storage    │  │   Catch-up Pipeline    │ │
//! │  │  (EOP, sig,  │  │ (dedupe,     │  │  (req head, page       │ │
//! │  │   linkage)   │  │  pending)    │  │   commits, fetch tx)   │ │
//! │  └──────────────┘  └──────────────┘  └────────────────────────┘ │
//! └───────────────────────────┬─────────────────────────────────────┘
//!                             │ NetworkEvent / NetworkCommand
//!                             ▼
//! ┌─────────────────────────────────────────────────────────────────┐
//! │                    preconfirmation-net                          │
//! │         (libp2p gossipsub, req/resp, peer management)           │
//! └─────────────────────────────────────────────────────────────────┘
//! ```
//!
//! ## Quick Start
//!
//! ```no_run
//! use p2p::{P2pClient, P2pClientConfig, SdkEvent};
//!
//! #[tokio::main]
//! async fn main() -> Result<(), Box<dyn std::error::Error>> {
//!     // Create SDK configuration
//!     let config = P2pClientConfig::with_chain_id(167000);
//!
//!     // Create client and event receiver
//!     let (client, mut events) = P2pClient::new(config)?;
//!
//!     // Get a handle for sending commands (can be cloned for multiple tasks)
//!     let handle = client.handle();
//!
//!     // Spawn the client event loop
//!     tokio::spawn(async move {
//!         if let Err(e) = client.run().await {
//!             eprintln!("Client error: {e}");
//!         }
//!     });
//!
//!     // Process SDK events
//!     while let Ok(event) = events.recv().await {
//!         match event {
//!             SdkEvent::CommitmentGossip { from, commitment } => {
//!                 println!("Received commitment from {from}");
//!                 // Process the commitment...
//!             }
//!             SdkEvent::RawTxListGossip { from, msg } => {
//!                 println!("Received txlist from {from}");
//!                 // Store or validate the transaction list...
//!             }
//!             SdkEvent::HeadSyncStatus { synced } => {
//!                 if synced {
//!                     println!("Synced with network head!");
//!                 }
//!             }
//!             SdkEvent::Reorg { anchor_block_number, reason } => {
//!                 println!("Reorg at anchor {anchor_block_number}: {reason}");
//!                 // Re-execute commitments from affected anchor...
//!             }
//!             _ => {}
//!         }
//!     }
//!
//!     Ok(())
//! }
//! ```
//!
//! ## Publishing Commitments
//!
//! ```no_run
//! use p2p::{P2pClient, P2pClientConfig};
//! use preconfirmation_types::SignedCommitment;
//!
//! async fn publish_example(handle: p2p::P2pClientHandle) -> p2p::P2pResult<()> {
//!     // Create and sign a commitment (using your signing key)
//!     let commitment: SignedCommitment = todo!("create your commitment");
//!
//!     // Publish to the network
//!     handle.publish_commitment(commitment).await?;
//!
//!     Ok(())
//! }
//! ```
//!
//! ## Catch-up Sync
//!
//! When your node starts or reconnects, use the catch-up pipeline to sync:
//!
//! ```no_run
//! use p2p::{P2pClient, P2pClientConfig, SdkEvent};
//!
//! async fn sync_example(handle: p2p::P2pClientHandle) -> p2p::P2pResult<()> {
//!     // Your current local head block number
//!     let local_head = 12345u64;
//!
//!     // Start catch-up (SDK will request network head and page through)
//!     handle.start_catchup(local_head, 0).await?;
//!
//!     // The SDK will emit HeadSyncStatus { synced: true } when complete
//!     Ok(())
//! }
//! ```
//!
//! ## Custom Validation Hooks
//!
//! Inject chain-specific validation logic:
//!
//! ```no_run
//! use p2p::validation::{BlockParamsValidator, ValidationOutcome};
//! use preconfirmation_types::Preconfirmation;
//!
//! struct MyChainValidator {
//!     max_gas_limit: u64,
//! }
//!
//! impl BlockParamsValidator for MyChainValidator {
//!     fn validate_params(
//!         &self,
//!         child: &Preconfirmation,
//!         parent: &Preconfirmation,
//!     ) -> ValidationOutcome {
//!         // Custom gas limit check
//!         let child_gas = child.gas_limit.to::<u64>();
//!         if child_gas > self.max_gas_limit {
//!             return ValidationOutcome::invalid("gas limit too high", true);
//!         }
//!
//!         // Delegate to default timestamp/anchor checks
//!         p2p::validation::validate_block_params_progression(child, parent)
//!     }
//! }
//! ```
//!
//! ## Metrics
//!
//! Initialize Prometheus metrics at startup:
//!
//! ```no_run
//! use p2p::P2pMetrics;
//!
//! fn setup_metrics() {
//!     // Register all metric descriptors
//!     P2pMetrics::init();
//!
//!     // Metrics are now exported:
//!     // - p2p_gossip_received_total{type="commitment|txlist"}
//!     // - p2p_validation_results_total{result="valid|pending|invalid"}
//!     // - p2p_pending_buffer_size
//!     // - p2p_head_sync_status
//!     // ... and more
//! }
//! ```
//!
//! ## Event Handling Patterns
//!
//! ### Handling Reorgs
//!
//! Per spec §6.3, L1 reorgs affecting anchor blocks require re-execution:
//!
//! ```no_run
//! use p2p::SdkEvent;
//!
//! fn handle_reorg(event: SdkEvent) {
//!     if let SdkEvent::Reorg { anchor_block_number, reason } = event {
//!         // 1. Identify commitments referencing this anchor
//!         // 2. Re-validate against new L1 state
//!         // 3. Re-execute affected preconfirmations
//!         println!("Handling reorg at anchor {anchor_block_number}: {reason}");
//!     }
//! }
//! ```
//!
//! ### Processing Pending Commitments
//!
//! Commitments arriving before their parents are automatically buffered:
//!
//! ```text
//! 1. Child commitment arrives → parent not in storage
//! 2. SDK buffers child in pending buffer (keyed by parent hash)
//! 3. Parent commitment arrives → validated and stored
//! 4. SDK releases buffered children → validates and emits CommitmentGossip
//! ```
//!
//! ## Module Overview
//!
//! | Module | Description |
//! |--------|-------------|
//! | [`catchup`] | Catch-up pipeline state machine for syncing with network head |
//! | [`handlers`] | Event handlers mapping NetworkEvent to SdkEvent with validation |
//! | [`metrics`] | Prometheus metric definitions and recording helpers |
//! | [`storage`] | SDK storage traits and in-memory implementation |
//! | [`validation`] | Commitment validation rules (EOP, linkage, progression) |
//!
//! ## Re-exports
//!
//! Key types from [`preconfirmation_net`] are re-exported for convenience:
//! - [`P2pConfig`], [`P2pHandle`], [`P2pNode`] - Network layer primitives
//! - [`NetworkEvent`], [`NetworkCommand`] - Low-level network messages
//! - [`LookaheadResolver`] - Schedule-based validation adapter interface
//!
//! ## Spec Compliance
//!
//! This SDK implements validation rules from the Taiko preconfirmation spec:
//! - **§3.1**: EOP (End-of-Proposal) rules for `raw_tx_list_hash`
//! - **§4–§7**: Parent linkage, block progression, signature verification
//! - **§6.2**: Catch-up sync pipeline for head synchronization
//! - **§6.3**: L1 reorg handling and anchor block re-execution
//! - **§7.1**: Gossipsub scoring alignment (penalization decisions)
//! - **§11–§12**: Request/response protocols for commitments and txlists

#![deny(missing_docs)]

pub mod catchup;
mod client;
mod config;
mod error;
pub mod handlers;
pub mod metrics;
pub mod storage;
mod types;
pub mod validation;

pub use catchup::{CatchupAction, CatchupConfig, CatchupPipeline, CatchupState};
pub use client::{P2pClient, P2pClientHandle};
pub use config::P2pClientConfig;
pub use error::{P2pClientError, P2pResult};
pub use handlers::EventHandler;
pub use metrics::P2pMetrics;
pub use validation::{
    BlockParamsValidator, CommitmentValidator, DefaultBlockParamsValidator, ValidationOutcome,
    ValidationResult, ValidationStatus, validate_block_params_progression,
};
// Re-export key network types so consumers can depend on this crate alone.
pub use preconfirmation_net::{
    LookaheadResolver, NetworkCommand, NetworkError, NetworkErrorKind, NetworkEvent, P2pConfig,
    P2pHandle, P2pNode, PreconfStorage,
};
pub use preconfirmation_types;
pub use types::{SdkCommand, SdkEvent};
