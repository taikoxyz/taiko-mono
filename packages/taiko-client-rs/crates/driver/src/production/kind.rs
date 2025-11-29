//! Core production input types and markers.

use alloy::rpc::types::Log;
use alloy_rpc_types_engine::ExecutionPayloadInputV2;
use std::fmt::Debug;

/// Marker for the source of a block-production request.
///
/// Used for dispatch decisions and error reporting.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ProductionPathKind {
    /// Blocks derived from canonical L1 proposal events (`Inbox::Proposed`).
    L1Events,
    /// Blocks injected via preconfirmation interfaces (e.g. HTTP).
    Preconfirmation,
}

/// Inputs that the driver can turn into L2 blocks.
///
/// Canonical proposals arrive as L1 logs; preconfirmations are externally supplied payloads.
#[derive(Debug)]
pub enum ProductionInput<'a> {
    /// Standard path: an L1 proposal log emitted by the inbox contract.
    L1ProposalLog(&'a Log),
    /// Preconfirmation path: an externally supplied payload.
    Preconfirmation(&'a (dyn PreconfPayload + Send + Sync)),
}

/// Anything that can be transformed into an execution payload suitable for engine submission.
///
/// Implementors typically wrap already decoded envelopes or helper structs that can build the
/// execution payload expected by the engine API.
pub trait PreconfPayload: Send + Sync + Debug {
    /// Convert the preconfirmation payload into an execution payload input.
    fn to_execution_payload(&self) -> ExecutionPayloadInputV2;
}
