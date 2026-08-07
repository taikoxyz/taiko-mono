//! Abstractions for multiple block-production paths.
//!
//! Canonical flow: `ProductionInput::L1ProposalLog` is fed by the event scanner and routed to
//! `CanonicalL1ProductionPath`, which delegates to the derivation pipeline.
//!
//! Preconfirmation flow: external components inject prebuilt payloads via
//! `EventSyncer::submit_preconfirmation_payload` when `DriverConfig.preconfirmation_enabled` is
//! true. These payloads enter the `ProductionRouter` as `ProductionInput::Preconfirmation` and are
//! applied through `PreconfirmationPath`, which uses the payload attributes path to submit the
//! payload to the engine.

use std::sync::Arc;

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy::{primitives::B256, rpc::types::Log};

use crate::error::DriverError;

pub mod path;

pub use path::{
    BlockHashReader, BlockProductionPath, CanonicalL1ProductionPath, PreconfirmationPath,
};

use self::path::EngineBlockOutcome;

/// Error emitted when a production path receives an input variant it cannot handle.
#[derive(thiserror::Error, Debug, Clone, Copy, PartialEq, Eq)]
#[error("production path received an unsupported input variant")]
pub struct UnsupportedInputError;

impl From<UnsupportedInputError> for DriverError {
    /// Convert an `UnsupportedInputError` into a generic `DriverError::Other`.
    fn from(err: UnsupportedInputError) -> Self {
        DriverError::Other(err.into())
    }
}

/// Inputs that the driver can turn into L2 blocks.
///
/// Canonical proposals arrive as L1 logs; preconfirmations are externally supplied payloads.
#[allow(clippy::large_enum_variant)]
#[derive(Clone, Debug)]
pub enum ProductionInput {
    /// Standard path: an L1 proposal log emitted by the inbox contract.
    L1ProposalLog(Log),
    /// Preconfirmation path: an externally supplied payload, we use `Arc` to avoid cloning large
    /// payloads.
    Preconfirmation(Arc<PreconfPayload>),
}

/// Concrete preconfirmation payload wrapper used for injection.
#[derive(Clone, Debug)]
pub struct PreconfPayload {
    /// Wrapped payload attributes submitted through preconfirmation ingress.
    payload: TaikoPayloadAttributes,
    /// Parent block hash authenticated by the preconfirmation sender.
    expected_parent_hash: B256,
}

impl PreconfPayload {
    /// Create a new preconfirmation payload bound to its authenticated parent hash.
    pub fn new(payload: TaikoPayloadAttributes, expected_parent_hash: B256) -> Self {
        Self { payload, expected_parent_hash }
    }

    /// Access the underlying Taiko payload attributes.
    pub fn payload(&self) -> &TaikoPayloadAttributes {
        &self.payload
    }

    /// Return the parent block hash authenticated by the sender.
    pub fn expected_parent_hash(&self) -> B256 {
        self.expected_parent_hash
    }

    /// Return the target block number for the preconfirmation payload.
    pub fn block_number(&self) -> u64 {
        self.payload.l1_origin.block_id.to::<u64>()
    }
}

/// Terminal outcome of submitting one preconfirmation payload.
///
/// `Inserted` and `AlreadyMaterialized` carry the exact block hash observed by the
/// serialized submission path so callers can resolve the block by hash instead of by
/// height — a same-height sibling can become canonical immediately after submission,
/// and a height lookup would then bind the caller to a block the payload never produced.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PreconfSubmissionOutcome {
    /// The payload was injected through the execution-engine production path.
    Inserted {
        /// Hash of the block the execution engine produced for this payload.
        block_hash: B256,
    },
    /// The exact payload was already materialized in local execution state.
    AlreadyMaterialized {
        /// Hash of the materialized block observed by the submission check.
        block_hash: B256,
    },
    /// The payload was at or below the event-confirmed L2 tip and was dropped.
    Stale,
}

/// Routes `ProductionInput` to the matching `BlockProductionPath`.
#[derive(Clone)]
pub struct ProductionRouter {
    /// Path materialising canonical L1 proposal logs.
    canonical: Arc<dyn BlockProductionPath + Send + Sync>,
    /// Path injecting preconfirmation payloads, present when preconfirmation is enabled.
    preconf: Option<Arc<dyn BlockProductionPath + Send + Sync>>,
}

impl ProductionRouter {
    /// Create a router with the canonical path and an optional preconfirmation path.
    pub fn new(
        canonical: Arc<dyn BlockProductionPath + Send + Sync>,
        preconf: Option<Arc<dyn BlockProductionPath + Send + Sync>>,
    ) -> Self {
        Self { canonical, preconf }
    }

    /// Route input to the matching path based on the variant.
    pub async fn produce(
        &self,
        input: ProductionInput,
    ) -> Result<Vec<EngineBlockOutcome>, DriverError> {
        match &input {
            ProductionInput::L1ProposalLog(_) => self.canonical.produce(input).await,
            ProductionInput::Preconfirmation(_) => match &self.preconf {
                Some(path) => path.produce(input).await,
                None => Err(DriverError::PreconfirmationDisabled),
            },
        }
    }
}
