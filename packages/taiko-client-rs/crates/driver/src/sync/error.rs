//! Synchronization error types.

use alloy::primitives::{B256, U256};
use anyhow::Error as AnyhowError;
use rpc::RpcClientError;
use thiserror::Error;

use crate::derivation::DerivationError;

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

    /// L1 RPC temporarily cannot serve the historical state for a finalized block.
    #[error("L1 finalized state is temporarily unavailable: {message}")]
    HistoricalStateUnavailable {
        /// Original RPC error message used for operator diagnostics.
        message: String,
    },

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
    /// Execution engine is syncing and cannot accept the provided block.
    #[error("execution engine syncing while inserting block {0}")]
    EngineSyncing(u64),
    /// Execution engine rejected the block payload.
    #[error("execution engine rejected block {0}: {1}")]
    InvalidBlock(u64, String),
    /// Execution engine returned a status other than VALID for a canonical insert.
    #[error("execution engine returned unexpected payload status for block {0}: {1}")]
    UnexpectedPayloadStatus(u64, String),
    /// Engine did not return a payload identifier after forkchoice update.
    #[error("forkchoice update returned no payload id")]
    MissingPayloadId,
    /// Execution engine failed to return the inserted block via RPC.
    #[error("inserted block {0} not found via rpc provider")]
    MissingInsertedBlock(u64),
    /// The target block is before Unzen (or its fork schedule cannot be resolved): the Osaka
    /// Engine API methods neither build nor import pre-Unzen blocks.
    #[error(
        "cannot build block {block_number} (timestamp {timestamp}, chain {chain_id}) through the \
         Engine API: it is before Unzen; pre-Unzen history can only come from P2P sync or a \
         snapshot"
    )]
    PreUnzenTarget {
        /// Number of the rejected target block.
        block_number: u64,
        /// Timestamp of the rejected target block.
        timestamp: u64,
        /// Chain id whose fork schedule was consulted.
        chain_id: u64,
    },
    /// `engine_getPayloadV5` returned a `blockValue` (the block's zk gas) that does not fit the
    /// u64 `headerDifficulty` of `engine_newPayloadV4`.
    #[error(
        "getPayloadV5 blockValue {block_value} of block {block_number} exceeds the u64 header \
         difficulty range"
    )]
    HeaderDifficultyOverflow {
        /// Number of the built block.
        block_number: u64,
        /// `blockValue` returned by the engine.
        block_value: U256,
    },
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
