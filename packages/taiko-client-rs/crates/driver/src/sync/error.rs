//! Synchronization error types.

use alloy::primitives::B256;
use anyhow::Error as AnyhowError;
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

    /// Event sync: execution engine returned no latest block.
    #[error("execution engine returned no latest block")]
    MissingLatestExecutionBlock,

    /// Event sync: checkpoint mode enabled, but beacon sync did not publish a resume head.
    #[error("checkpoint mode enabled but no checkpoint resume head is available")]
    MissingCheckpointResumeHead,

    /// Event sync: no-checkpoint mode requires local head L1 origin to choose a safe resume head.
    #[error("head_l1_origin is missing; cannot derive event resume head without checkpoint")]
    MissingHeadL1OriginResume,

    /// Event sync: execution engine missing a specific block.
    #[error("execution engine returned no block {number}")]
    MissingExecutionBlock { number: u64 },

    /// Event sync: finalized L1 block is unavailable; resume must fail closed.
    #[error("finalized l1 block is unavailable")]
    MissingFinalizedL1Block,

    /// Event sync: execution engine missing batch-to-block mapping.
    #[error("no execution block found for batch {proposal_id}")]
    MissingExecutionBlockForBatch { proposal_id: u64 },

    /// Event sync: failed to locate the expected anchor transaction for deriving resume point.
    #[error("anchor transaction missing in l2 block {block_number}: {reason}")]
    MissingAnchorTransaction { block_number: u64, reason: &'static str },

    /// Event sync: failed to decode a proposal log from the inbox contract.
    #[error("invalid proposal log in block {block_number:?}, tx {tx_hash:?}: {reason}")]
    InvalidProposalLog { reason: String, tx_hash: Option<B256>, block_number: Option<u64> },

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
    /// Execution engine failed to return the inserted block via RPC.
    #[error("inserted block {0} not found via rpc provider")]
    MissingInsertedBlock(u64),
}
