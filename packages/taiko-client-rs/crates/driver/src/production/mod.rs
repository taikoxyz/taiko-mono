//! Abstractions for multiple block-production paths.
//!
//! Canonical flow: `ProductionInput::L1ProposalLog` is fed by the event scanner and routed to
//! `CanonicalL1ProductionPath`, which delegates to the derivation pipeline.
//!
//! Preconfirmation flow: external components can inject prebuilt payloads via the
//! `preconfirmation_sender` exposed on `EventSyncer` when `DriverConfig.preconfirmation_enabled` is
//! true. These payloads enter the `ProductionRouter` as `ProductionInput::Preconfirmation` and are
//! applied through `PreconfirmationPath`, which uses the payload attributes path to submit the
//! payload to the engine.

use std::sync::Arc;

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy::rpc::types::Log;

use crate::error::DriverError;

pub mod path;

pub use path::{
    BlockHashReader, BlockProductionPath, CanonicalL1ProductionPath, PreconfirmationPath,
};

use self::path::EngineBlockOutcome;

/// Errors emitted by production routing and path selection.
#[derive(thiserror::Error, Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProductionError {
    /// Input was dispatched to a path that does not support it.
    #[error("{input:?} input is unsupported by {path:?} path")]
    UnsupportedInput { path: ProductionPathKind, input: ProductionPathKind },

    /// No registered path can handle the requested input kind.
    #[error("no production path registered for input {kind:?}")]
    MissingPath { kind: ProductionPathKind },
}

impl From<ProductionError> for DriverError {
    /// Convert a `ProductionError` into a generic `DriverError::Other`.
    fn from(err: ProductionError) -> Self {
        DriverError::Other(err.into())
    }
}

/// Marker for the source of a block-production request.
///
/// Used for dispatch decisions and error reporting.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ProductionPathKind {
    /// Blocks derived from canonical L1 proposal events (`Inbox::Proposed`).
    L1Events,
    /// Blocks injected via preconfirmation interfaces.
    Preconfirmation,
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
    payload: TaikoPayloadAttributes,
}

impl PreconfPayload {
    /// Create a new preconfirmation payload.
    pub fn new(payload: TaikoPayloadAttributes) -> Self {
        Self { payload }
    }

    /// Access the underlying Taiko payload attributes.
    pub fn payload(&self) -> &TaikoPayloadAttributes {
        &self.payload
    }

    /// Consume the wrapper and return the underlying payload attributes.
    pub fn into_payload(self) -> TaikoPayloadAttributes {
        self.payload
    }

    /// Return the target block number for the preconfirmation payload.
    pub fn block_number(&self) -> u64 {
        self.payload.l1_origin.block_id.to::<u64>()
    }
}

/// Routes `ProductionInput` to a compatible `BlockProductionPath`.
#[derive(Clone)]
pub struct ProductionRouter {
    paths: Vec<Arc<dyn BlockProductionPath + Send + Sync>>,
}

impl ProductionRouter {
    /// Create a router with the provided production paths.
    pub fn new(paths: Vec<Arc<dyn BlockProductionPath + Send + Sync>>) -> Self {
        Self { paths }
    }

    /// Route input to the first compatible path based on the variant.
    pub async fn produce(
        &self,
        input: ProductionInput,
    ) -> Result<Vec<EngineBlockOutcome>, DriverError> {
        let target_kind = match &input {
            ProductionInput::L1ProposalLog(_) => ProductionPathKind::L1Events,
            ProductionInput::Preconfirmation(_) => ProductionPathKind::Preconfirmation,
        };

        if let Some(path) = self.paths.iter().find(|path| path.kind() == target_kind) {
            return path.produce(input).await;
        }

        Err(ProductionError::MissingPath { kind: target_kind }.into())
    }
}
