//! Driver specific error types.

use std::{result::Result as StdResult, time::Duration};

use alloy::primitives::{B256, U256};
use anyhow::Error as AnyhowError;
use protocol::shasta::error::ForkConfigError;
use rpc::error::RpcClientError;
use thiserror::Error;
use tokio::sync::oneshot::error::RecvError;

use crate::sync::{SyncError, error::EngineSubmissionError};

/// Convenient result alias for driver operations.
pub type Result<T> = StdResult<T, DriverError>;

/// Error variants emitted by the driver.
#[derive(Debug, Error)]
pub enum DriverError {
    /// Errors originating from the RPC client layer.
    #[error("rpc error: {0}")]
    Rpc(#[from] RpcClientError),

    /// Sync subsystem reported a failure.
    #[error(transparent)]
    Sync(#[from] SyncError),

    /// Preconfirmation support is disabled in the driver configuration.
    #[error("preconfirmation is not enabled in driver config")]
    PreconfirmationDisabled,

    /// Preconfirmation ingress loop has not started yet.
    #[error("preconfirmation ingress loop is not ready")]
    PreconfIngressNotReady,

    /// Canonical parent changed after the preconfirmation was authenticated.
    #[error(
        "preconfirmation parent mismatch for block {block_number}: expected {expected}, got {actual}"
    )]
    PreconfParentMismatch {
        /// L2 block number targeted by the preconfirmation.
        block_number: u64,
        /// Parent hash authenticated by the preconfirmation sender.
        expected: B256,
        /// Parent hash currently canonical in the execution engine.
        actual: B256,
    },

    /// Block not found on remote node.
    #[error("remote node missing block {0}")]
    BlockNotFound(u64),

    /// Engine API returned syncing status.
    #[error("engine API returned SYNCING for block {0}")]
    EngineSyncing(u64),

    /// Engine API returned invalid payload.
    #[error("engine API returned INVALID: {0}")]
    EngineInvalidPayload(String),

    /// A checkpoint block's header difficulty (its zk gas) does not fit the u64
    /// `headerDifficulty` of `engine_newPayloadV4`.
    #[error(
        "checkpoint block {block_number} difficulty {difficulty} exceeds the u64 header \
         difficulty range"
    )]
    CheckpointDifficultyOverflow {
        /// Number of the checkpoint block.
        block_number: u64,
        /// Header difficulty of the checkpoint block.
        difficulty: U256,
    },

    /// A non-genesis checkpoint block that the client's schedule places in Etna carries no
    /// `parentBeaconBlockRoot` or a zero one.
    ///
    /// The block already hashes to the L1-recorded checkpoint, so it is canonical and the
    /// network built it before Etna: the client's Etna schedule is misconfigured, and retrying
    /// cannot help.
    #[error(
        "Etna checkpoint block {block_number} (timestamp {timestamp}) has a zero or missing \
         parentBeaconBlockRoot although it matches the L1-recorded checkpoint, so the network \
         built it before Etna; the client's Etna activation time must be the network's (on a \
         devnet, set --devnet-etna-timestamp to the network's Etna time, the same value on the \
         client and alethia-reth)"
    )]
    EtnaCheckpointWithoutBeaconRoot {
        /// Number of the checkpoint block.
        block_number: u64,
        /// Timestamp of the checkpoint block.
        timestamp: u64,
    },

    /// A non-genesis checkpoint block that the client's schedule places before Etna carries a
    /// nonzero `parentBeaconBlockRoot`.
    ///
    /// The block already hashes to the L1-recorded checkpoint, so it is canonical and the
    /// network built it as an Etna block: the client's Etna activation time is later than the
    /// network's, and retrying cannot help.
    #[error(
        "pre-Etna checkpoint block {block_number} (timestamp {timestamp}) has a nonzero \
         parentBeaconBlockRoot {root} although it matches the L1-recorded checkpoint, so the \
         network built it as an Etna block; the client's Etna activation time must be the \
         network's (on a devnet, set --devnet-etna-timestamp to the network's Etna time, the \
         same value on the client and alethia-reth)"
    )]
    PreEtnaCheckpointWithBeaconRoot {
        /// Number of the checkpoint block.
        block_number: u64,
        /// Timestamp of the checkpoint block.
        timestamp: u64,
        /// The checkpoint block's nonzero `parentBeaconBlockRoot`.
        root: B256,
    },

    /// The Etna activation time of the client's chain cannot be resolved.
    #[error("cannot resolve the Etna fork schedule of chain {chain_id}")]
    EtnaScheduleUnresolved {
        /// Chain id whose fork schedule was consulted.
        chain_id: u64,
        /// Underlying fork-configuration error.
        #[source]
        source: ForkConfigError,
    },

    /// Preconfirmation payload injection failed with context.
    #[error("preconfirmation injection failed for block {block_number}: {source}")]
    PreconfInjectionFailed {
        /// L2 block number targeted by the payload.
        block_number: u64,
        #[source]
        /// Underlying engine submission error.
        source: EngineSubmissionError,
    },

    /// Timed out while enqueuing a preconfirmation payload.
    #[error("preconfirmation enqueue timed out after {waited:?}")]
    PreconfEnqueueTimeout {
        /// Time spent waiting for queue capacity.
        waited: Duration,
    },

    /// Channel send failed when enqueueing a preconfirmation payload.
    #[error("failed to enqueue preconfirmation: {0}")]
    PreconfEnqueueFailed(String),

    /// Timed out waiting for a preconfirmation processing response.
    #[error("preconfirmation result timed out after {waited:?}")]
    PreconfResponseTimeout {
        /// Time spent waiting for the oneshot response.
        waited: Duration,
    },

    /// Response channel for a preconfirmation payload was closed before delivery.
    #[error("preconfirmation response dropped: {recv_error}")]
    PreconfResponseDropped {
        #[from]
        #[source]
        /// Channel receive error produced by oneshot cancellation.
        recv_error: RecvError,
    },

    /// Generic boxed error.
    #[error(transparent)]
    Other(#[from] AnyhowError),
}
