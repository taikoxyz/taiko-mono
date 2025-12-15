//! P2P client wrapper for the permissionless preconfirmation networking stack.
//!
//! This crate provides a sidecar-friendly façade over the `preconfirmation-service`
//! networking layer. It will grow orchestration for bootstrap catch-up, validation,
//! storage, and metrics. Currently it exposes the basic types and stubbed structs
//! needed to compile while the full implementation is developed.
//!
//! # Quick start
//! ```no_run
//! use p2p::{P2pClient, P2pClientConfig};
//! use preconfirmation_types::{RawTxListGossip, SignedCommitment, keccak256_bytes, PreconfCommitment, Preconfirmation};
//! use tokio::task;
//!
//! #[tokio::main]
//! async fn main() -> anyhow::Result<()> {
//!     let mut client = P2pClient::start(P2pClientConfig::default()).await?;
//!
//!     // Subscribe to events from the same task for simplicity.
//!     if let Some(ev) = client.next_event().await {
//!         println!("client event: {:?}", ev);
//!     }
//!
//!     // Publish a txlist + commitment pair.
//!     let mut txlist = preconfirmation_types::TxListBytes::default();
//!     let _ = txlist.push(1u8);
//!     let hash = keccak256_bytes(txlist.as_ref());
//!     let tx = RawTxListGossip { raw_tx_list_hash: preconfirmation_types::Bytes32::try_from(hash.as_slice().to_vec()).unwrap(), txlist };
//!     let mut commitment = PreconfCommitment::default();
//!     commitment.preconf = Preconfirmation { raw_tx_list_hash: tx.raw_tx_list_hash.clone(), ..Default::default() };
//!     let signed = SignedCommitment { commitment, signature: preconfirmation_types::Bytes65::default() }; // replace with real signature
//!     client.publish_txlist_and_commitment(tx, signed).await?;
//!     Ok(())
//! }
//! ```

#![deny(missing_docs)]

pub mod catchup;
pub mod client;
pub mod config;
pub mod error;
pub mod handlers;
pub mod metrics;
pub mod resolver;
pub mod storage;
pub mod types;
pub mod validation;

pub use crate::{
    client::P2pClient,
    config::P2pClientConfig,
    error::{P2pClientError, Result},
    types::{ClientCommand, ClientEvent, HeadSyncStatus},
};

// Re-export key network types so consumers can depend on this crate alone.
pub use preconfirmation_service::{
    LookaheadResolver, NetworkCommand, NetworkConfig, NetworkError, NetworkErrorKind, NetworkEvent,
    P2pService, PreconfStorage,
};
pub use preconfirmation_types;
