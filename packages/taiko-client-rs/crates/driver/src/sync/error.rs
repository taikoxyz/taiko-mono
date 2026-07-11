//! Synchronization error types.

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
    /// Engine did not return a payload identifier after forkchoice update.
    #[error("forkchoice update returned no payload id")]
    MissingPayloadId,
    /// Execution engine failed to return the inserted block via RPC.
    #[error("inserted block {0} not found via rpc provider")]
    MissingInsertedBlock(u64),
}

impl From<TransportError> for EngineSubmissionError {
    /// Preserve typed transport failures from engine-adjacent provider calls.
    fn from(err: TransportError) -> Self {
        Self::Rpc(err.into())
    }
}
