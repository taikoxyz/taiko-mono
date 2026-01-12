//! Core production input types and markers.

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy::rpc::types::Log;
use std::sync::Arc;

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
