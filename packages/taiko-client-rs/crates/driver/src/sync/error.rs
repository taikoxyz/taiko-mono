//! Synchronization error types.

use anyhow::Error as AnyhowError;
use event_indexer::error::IndexerError;
use rpc::RpcClientError;
use std::result::Result as StdResult;
use thiserror::Error;

use crate::derivation::DerivationError;

/// Result type alias for sync operations.
pub type Result<T> = StdResult<T, SyncError>;

/// Errors emitted by sync components.
#[derive(Debug, Error)]
pub enum SyncError {
    /// Beacon sync: checkpoint node has no L1 origin.
    #[error("checkpoint node has no L1 origin")]
    CheckpointNoOrigin,

    /// Beacon sync: failed to query checkpoint head.
    #[error("failed to query checkpoint head")]
    CheckpointQuery(#[source] RpcClientError),

    /// Beacon sync: failed to submit remote block.
    #[error("failed to submit remote block {block_number}")]
    RemoteBlockSubmit {
        block_number: u64,
        #[source]
        error: AnyhowError,
    },

    /// Beacon sync: checkpoint head behind local head.
    #[error("checkpoint head {checkpoint} is behind local head {local}")]
    CheckpointBehind { checkpoint: u64, local: u64 },

    /// Event sync: indexer initialization failed.
    #[error("failed to initialize event indexer")]
    IndexerInit(#[from] IndexerError),

    /// Event sync: execution engine returned no latest block.
    #[error("execution engine returned no latest block")]
    MissingLatestExecutionBlock,

    /// Event sync: indexer task terminated unexpectedly.
    #[error("event indexer task terminated unexpectedly")]
    IndexerTerminated,

    /// Event sync: derivation failed.
    #[error("derivation failed")]
    Derivation(#[from] DerivationError),

    /// Event sync: failed to instantiate the event scanner.
    #[error("failed to create event scanner: {0}")]
    EventScannerInit(String),

    /// Event sync: RPC error.
    #[error(transparent)]
    Rpc(#[from] RpcClientError),

    /// Generic sync error.
    #[error(transparent)]
    Other(#[from] AnyhowError),
}

/// Errors that can occur while submitting payload attributes to the execution engine.
#[derive(Debug, Error)]
pub enum EngineSubmissionError {
    /// Failure communicating with Taiko RPC wrappers.
    #[error(transparent)]
    Rpc(#[from] RpcClientError),
    /// Failure communicating with the execution engine's public RPC.
    #[error("execution engine provider error: {0}")]
    Provider(String),
    /// Unable to determine the latest canonical L2 block.
    #[error("latest L2 block not found")]
    MissingParent,
    /// Execution engine is syncing and cannot accept the provided block.
    #[error("execution engine syncing while inserting block {0}")]
    EngineSyncing(u64),
    /// Execution engine rejected the block payload.
    #[error("execution engine rejected block {0}: {1}")]
    InvalidBlock(u64, String),
    /// Engine did not return a payload identifier after forkchoice update.
    #[error("forkchoice update returned no payload id")]
    MissingPayloadId,
}
