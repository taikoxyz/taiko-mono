//! Core production input types and markers.

use alloy::rpc::types::Log;
use alloy_rpc_types_engine::ExecutionPayloadInputV2;
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
    execution_payload: ExecutionPayloadInputV2,
}

impl PreconfPayload {
    /// Create a new preconfirmation payload.
    pub fn new(execution_payload: ExecutionPayloadInputV2) -> Self {
        Self { execution_payload }
    }

    /// Access the underlying execution payload.
    pub fn execution_payload(&self) -> &ExecutionPayloadInputV2 {
        &self.execution_payload
    }

    /// Consume the wrapper and return the underlying execution payload.
    pub fn into_execution_payload(self) -> ExecutionPayloadInputV2 {
        self.execution_payload
    }
}
