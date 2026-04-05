//! Event-driven import decisions for whitelist preconfirmation envelopes.

use std::sync::Arc;

use alloy_primitives::B256;

use crate::codec::WhitelistExecutionPayloadEnvelope;

/// Import-time context required to evaluate a pending preconfirmation envelope.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) struct ImportContext {
    /// Current confirmed boundary from `head_l1_origin`.
    pub(crate) head_l1_origin_block_id: Option<u64>,
    /// Local block hash currently present at the envelope's block number, if any.
    pub(crate) current_block_hash: Option<B256>,
    /// Local block hash currently present at the envelope's parent block number, if any.
    pub(crate) parent_block_hash: Option<B256>,
    /// Whether a missing parent request may be issued now under the request cooldown.
    pub(crate) allow_parent_request: bool,
}

/// Event-driven importer decision for one pending preconfirmation envelope.
#[derive(Clone, Debug)]
pub(crate) enum ImportDecision {
    /// Drop the envelope from pending state.
    Drop,
    /// Keep the envelope pending until another event wakes it.
    Cache,
    /// Request the missing parent block hash, honoring the request cooldown.
    RequestParent(B256),
    /// Submit the envelope to the driver for import.
    Import(Arc<WhitelistExecutionPayloadEnvelope>),
    /// Serve a response envelope over the request/response gossip path.
    Respond(Arc<WhitelistExecutionPayloadEnvelope>),
}

/// Evaluate the next importer action for a pending envelope.
///
/// This preserves:
/// - `WLP-INV-003` by dropping payloads at or below `head_l1_origin`;
/// - `WLP-INV-004` by refusing parent recovery across the confirmed boundary.
pub(crate) fn evaluate_pending_import(
    envelope: Arc<WhitelistExecutionPayloadEnvelope>,
    context: ImportContext,
) -> ImportDecision {
    let payload = &envelope.execution_payload;
    let block_number = payload.block_number;
    let block_hash = payload.block_hash;
    let parent_hash = payload.parent_hash;

    let Some(head_l1_origin_block_id) = context.head_l1_origin_block_id else {
        return ImportDecision::Cache;
    };

    if block_number <= head_l1_origin_block_id {
        return ImportDecision::Drop;
    }

    if context.current_block_hash == Some(block_hash) || block_number == 0 {
        return ImportDecision::Drop;
    }

    let parent_number = block_number.saturating_sub(1);
    if context.parent_block_hash == Some(parent_hash) {
        return ImportDecision::Import(envelope);
    }

    if parent_number <= head_l1_origin_block_id {
        return ImportDecision::Drop;
    }

    if context.allow_parent_request {
        ImportDecision::RequestParent(parent_hash)
    } else {
        ImportDecision::Cache
    }
}
