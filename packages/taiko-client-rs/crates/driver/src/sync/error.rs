//! Synchronization error types.

use std::fmt;

use alloy::{primitives::B256, transports::TransportError};
use anyhow::Error as AnyhowError;
use rpc::RpcClientError;
use thiserror::Error;

use crate::{derivation::DerivationError, error::DriverError};

/// Errors emitted by sync components.
#[derive(Debug, Error)]
pub enum SyncError {
    /// Beacon sync: failed to query the checkpoint node.
    #[error("failed to query checkpoint node")]
    CheckpointQuery(#[source] RpcClientError),

    /// Beacon sync: failed to submit remote block.
    #[error("failed to submit remote block {block_number}")]
    RemoteBlockSubmit {
        /// Remote block number that failed submission.
        block_number: u64,
        #[source]
        /// Underlying submission error.
        error: AnyhowError,
    },

    /// Event sync: checkpoint mode enabled, but beacon sync did not publish a resume head.
    #[error("checkpoint mode enabled but no checkpoint resume head is available")]
    MissingCheckpointResumeHead,

    /// Event sync: no-checkpoint mode requires local head L1 origin to choose a safe resume head.
    #[error("head_l1_origin is missing; cannot derive event resume head without checkpoint")]
    MissingHeadL1OriginResume,

    /// Event sync: execution engine missing a specific block.
    #[error("execution engine returned no block {number}")]
    MissingExecutionBlock {
        /// Missing execution block number.
        number: u64,
    },

    /// Event sync: canonical L1 block is temporarily unavailable during a proposal-log recheck.
    #[error("canonical L1 block {number} unavailable while rechecking proposal log")]
    CanonicalL1BlockUnavailable {
        /// L1 block number whose canonical block is not currently visible.
        number: u64,
    },

    /// Event sync: proposal log block is temporarily unavailable by hash while resolving its
    /// missing height.
    #[error("proposal log block {block_hash} unavailable while resolving its L1 height")]
    ProposalLogBlockUnavailable {
        /// Hash of the L1 block that emitted the proposal log.
        block_hash: B256,
    },

    /// Event sync: failed to locate the expected anchor transaction for deriving resume point.
    #[error("anchor transaction missing in l2 block {block_number}: {reason}")]
    MissingAnchorTransaction {
        /// L2 block number inspected for the anchor transaction.
        block_number: u64,
        /// Reason anchor extraction failed.
        reason: &'static str,
    },

    /// Event sync: failed to decode a proposal log from the inbox contract.
    #[error("invalid proposal log in block {block_number:?}, tx {tx_hash:?}: {reason}")]
    InvalidProposalLog {
        /// Decode or validation failure reason.
        reason: String,
        /// Optional transaction hash carrying the invalid log.
        tx_hash: Option<B256>,
        /// Optional block number carrying the invalid log.
        block_number: Option<u64>,
    },

    /// Event sync: proposal log is missing the source block hash required for reorg checks.
    #[error("proposal log missing block hash in block {block_number:?}, tx {tx_hash:?}")]
    MissingProposalLogBlockHash {
        /// Optional transaction hash carrying the incomplete log.
        tx_hash: Option<B256>,
        /// Optional block number carrying the incomplete log.
        block_number: Option<u64>,
    },

    /// Event sync: derivation failed.
    #[error("derivation failed")]
    Derivation(#[from] DerivationError),

    /// Event sync: failed to instantiate the event scanner.
    #[error("failed to create event scanner: {0}")]
    EventScannerInit(String),

    /// Event sync: RPC error.
    #[error(transparent)]
    Rpc(#[from] RpcClientError),

    /// Event sync: driver-level failure surfaced through proposal processing.
    #[error(transparent)]
    Driver(Box<DriverError>),

    /// Generic sync error.
    #[error(transparent)]
    Other(#[from] AnyhowError),
}

impl From<TransportError> for SyncError {
    /// Preserve typed transport failures from raw provider calls as RPC sync errors.
    fn from(err: TransportError) -> Self {
        Self::Rpc(err.into())
    }
}

impl From<alloy::contract::Error> for SyncError {
    /// Preserve typed contract-call failures (including revert data) as RPC sync errors.
    fn from(err: alloy::contract::Error) -> Self {
        Self::Rpc(err.into())
    }
}

impl From<DriverError> for SyncError {
    /// Convert driver errors without collapsing them into stringly-typed buckets: sync errors
    /// unwrap to themselves, RPC errors keep their variant, and everything else stays typed
    /// behind [`SyncError::Driver`] so callers can still classify the failure.
    fn from(err: DriverError) -> Self {
        match err {
            DriverError::Sync(sync_err) => sync_err,
            DriverError::Rpc(rpc_err) => Self::Rpc(rpc_err),
            other => Self::Driver(Box::new(other)),
        }
    }
}

/// Engine API stage that returned a non-VALID payload status.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EnginePayloadStatusStage {
    /// Initial forkchoice update carrying payload attributes.
    PayloadAttributesForkchoice,
    /// Submission of the built payload through `engine_newPayloadV2`.
    NewPayload,
    /// Forkchoice update promoting the submitted payload to the canonical head.
    PromotionForkchoice,
}

impl fmt::Display for EnginePayloadStatusStage {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::PayloadAttributesForkchoice => f.write_str("payload-attributes forkchoice"),
            Self::NewPayload => f.write_str("newPayload"),
            Self::PromotionForkchoice => f.write_str("promotion forkchoice"),
        }
    }
}

/// Errors that can occur while submitting payload attributes to the execution engine.
#[derive(Debug, Error)]
pub enum EngineSubmissionError {
    /// Failure communicating with Taiko RPC wrappers.
    #[error(transparent)]
    Rpc(#[from] RpcClientError),
    /// Execution engine is syncing and cannot accept the provided block.
    #[error("execution engine syncing while inserting block {0}")]
    EngineSyncing(u64),
    /// Execution engine rejected the block payload.
    #[error("execution engine rejected block {0}: {1}")]
    InvalidBlock(u64, String),
    /// Execution engine returned a status other than VALID for a canonical insert.
    #[error(
        "execution engine returned unexpected payload status during {stage} for block {block_number}: {status}"
    )]
    UnexpectedPayloadStatus {
        /// Number of the block being materialized.
        block_number: u64,
        /// Engine API stage that returned the unexpected status.
        stage: EnginePayloadStatusStage,
        /// Non-VALID status returned by the engine.
        status: String,
    },
    /// Engine did not return a payload identifier after forkchoice update.
    #[error("forkchoice update returned no payload id")]
    MissingPayloadId,
    /// Execution engine failed to return the inserted block via RPC.
    #[error("inserted block {0} not found via rpc provider")]
    MissingInsertedBlock(u64),
    /// The canonical block read back after promotion does not match the submitted payload.
    #[error("inserted block {block_number} hash mismatch: expected {expected}, got {actual}")]
    InsertedBlockHashMismatch {
        /// Number of the block that was submitted to the engine.
        block_number: u64,
        /// Block hash of the payload the engine was asked to insert.
        expected: B256,
        /// Block hash the provider returned at that height after promotion.
        actual: B256,
    },
}

impl From<TransportError> for EngineSubmissionError {
    /// Preserve typed transport failures from engine-adjacent provider calls.
    fn from(err: TransportError) -> Self {
        Self::Rpc(err.into())
    }
}
