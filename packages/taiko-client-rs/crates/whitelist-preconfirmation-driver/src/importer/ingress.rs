use std::sync::Arc;

use alloy_primitives::B256;
use alloy_provider::Provider;
use tracing::debug;

use crate::{
    codec::{
        DecodedUnsafePayload, WhitelistExecutionPayloadEnvelope, block_signing_hash, recover_signer,
    },
    core::import::{ImportContext, ImportDecision, evaluate_pending_import},
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
};

use super::{
    WhitelistPreconfirmationImporter,
    validation::{normalize_unsafe_payload_envelope, validate_execution_payload_for_preconf},
};

/// Increment validation failure metrics for the given ingest stage.
fn record_validation_failure(stage: &'static str) {
    metrics::counter!(
        WhitelistPreconfirmationDriverMetrics::VALIDATION_FAILURES_TOTAL,
        "stage" => stage,
    )
    .increment(1);
}

/// Pre-resolved metric labels for a block-by-hash lookup path.
struct LookupLabels {
    /// Label used in log messages.
    log_prefix: &'static str,
    /// Metric result label for cache hits.
    cache_hit: &'static str,
    /// Metric result label for L2 hits.
    l2_hit: &'static str,
    /// Metric result label for misses.
    not_found: &'static str,
}

/// Metric and log labels for gossip-derived block hash lookup traffic.
const GOSSIP_LOOKUP_LABELS: LookupLabels = LookupLabels {
    log_prefix: "gossip",
    cache_hit: "cache_hit",
    l2_hit: "l2_hit",
    not_found: "not_found",
};

/// Transport-agnostic outcome of serving a block-by-hash lookup.
pub(super) enum LookupResult {
    /// Envelope found in the recent cache.
    CacheHit(Arc<WhitelistExecutionPayloadEnvelope>),
    /// Envelope rebuilt from local L2 state.
    L2Hit(Arc<WhitelistExecutionPayloadEnvelope>),
    /// Block not found.
    NotFound,
}

/// Cache/side-effect plan for one validated ingress envelope.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(super) struct ValidatedEnvelopePlan {
    /// Whether the envelope should stay in the pending graph.
    pub(super) cache_pending: bool,
    /// Whether the envelope should still update the EOS epoch mapping.
    pub(super) record_eos: bool,
}

/// Plan how validated ingress should treat the envelope after import classification.
pub(super) fn plan_validated_ingress(
    decision: &ImportDecision,
    current_block_hash: Option<B256>,
    envelope: &WhitelistExecutionPayloadEnvelope,
) -> ValidatedEnvelopePlan {
    let block_hash = envelope.execution_payload.block_hash;
    let duplicate_drop =
        matches!(decision, ImportDecision::Drop) && current_block_hash == Some(block_hash);

    ValidatedEnvelopePlan {
        cache_pending: !matches!(decision, ImportDecision::Drop),
        record_eos: envelope.end_of_sequencing.unwrap_or(false) &&
            (!matches!(decision, ImportDecision::Drop) || duplicate_drop),
    }
}

impl<P> WhitelistPreconfirmationImporter<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Cache a validated envelope and persist EOS epoch mapping when applicable.
    async fn ingest_validated_envelope(
        &mut self,
        envelope: Arc<WhitelistExecutionPayloadEnvelope>,
        ingress_source: &'static str,
    ) -> Result<()> {
        let block_number = envelope.execution_payload.block_number;
        let block_hash = envelope.execution_payload.block_hash;
        let head_l1_origin_block_id = self.head_l1_origin_block_id().await?;
        let current_block_hash = self.block_hash_by_number(block_number).await?;
        let parent_block_hash = if block_number == 0 {
            None
        } else {
            self.block_hash_by_number(block_number.saturating_sub(1)).await?
        };

        let decision = evaluate_pending_import(
            envelope.clone(),
            ImportContext {
                head_l1_origin_block_id,
                current_block_hash,
                parent_block_hash,
                allow_parent_request: false,
            },
        );
        let plan = plan_validated_ingress(&decision, current_block_hash, &envelope);
        if plan.record_eos {
            self.record_eos_epoch_if_marked(&envelope, ingress_source).await;
        }

        if !plan.cache_pending {
            debug!(
                block_number,
                block_hash = %block_hash,
                head_l1_origin_block_id,
                "dropping stale or already-inserted whitelist preconfirmation envelope before caching"
            );
            return Ok(());
        }

        self.pending.insert(envelope.clone());
        self.update_cache_gauges();
        Ok(())
    }

    /// Record the envelope block hash for its beacon epoch when `end_of_sequencing` is set.
    async fn record_eos_epoch_if_marked(
        &self,
        envelope: &WhitelistExecutionPayloadEnvelope,
        ingress_source: &'static str,
    ) {
        if !envelope.end_of_sequencing.unwrap_or(false) {
            return;
        }

        let timestamp = envelope.execution_payload.timestamp;
        if let Ok(epoch) = self.beacon_client.timestamp_to_epoch(timestamp).inspect_err(|err| {
            tracing::warn!(
                timestamp,
                ingress_source,
                error = %err,
                "failed to derive epoch from envelope timestamp for EOS recording"
            );
        }) {
            debug!(
                epoch,
                hash = %envelope.execution_payload.block_hash,
                ingress_source,
                "recording end-of-sequencing envelope for epoch"
            );
            self.shared_state
                .record_end_of_sequencing(epoch, envelope.execution_payload.block_hash)
                .await;
        }
    }

    /// Handle an incoming unsafe payload.
    pub(super) async fn handle_unsafe_payload(
        &mut self,
        payload: DecodedUnsafePayload,
    ) -> Result<()> {
        let prehash = block_signing_hash(self.chain_id, payload.payload_bytes.as_slice());
        let signer = recover_signer(prehash, &payload.wire_signature).inspect_err(|_err| {
            record_validation_failure("payload_signature_recover");
        })?;
        self.ensure_signer_allowed(signer).await.inspect_err(|_err| {
            record_validation_failure("payload_signer_check");
        })?;

        let envelope = normalize_unsafe_payload_envelope(payload.envelope, payload.wire_signature);
        validate_execution_payload_for_preconf(
            &envelope.execution_payload,
            self.chain_id,
            self.anchor_address,
        )
        .inspect_err(|_err| {
            record_validation_failure("payload_validate");
        })?;
        self.ingest_validated_envelope(Arc::new(envelope), "payload").await?;

        Ok(())
    }

    /// Handle an incoming unsafe response.
    ///
    /// The embedded `envelope.signature` is verified over
    /// `block_signing_hash(chain_id, block_hash)`. This matches the signing
    /// domain used by the sequencer when it stores the signature in L1 origin
    /// (see `rest_handler.rs` — `set_l1_origin_signature`).  It is distinct
    /// from the gossip *wire* signature on the `preconfBlocks` topic, which
    /// signs SSZ envelope bytes instead.
    pub(super) async fn handle_unsafe_response(
        &mut self,
        envelope: WhitelistExecutionPayloadEnvelope,
    ) -> Result<()> {
        let Some(signature) = envelope.signature else {
            record_validation_failure("response_missing_signature");
            return Err(WhitelistPreconfirmationDriverError::invalid_signature(
                "response payload is missing embedded signature",
            ));
        };

        // Signing domain: block_signing_hash(chain_id, block_hash).
        let prehash =
            block_signing_hash(self.chain_id, envelope.execution_payload.block_hash.as_slice());
        let signer = recover_signer(prehash, &signature).inspect_err(|_err| {
            record_validation_failure("response_signature_recover");
        })?;
        self.ensure_signer_allowed(signer).await.inspect_err(|_err| {
            record_validation_failure("response_signer_check");
        })?;

        validate_execution_payload_for_preconf(
            &envelope.execution_payload,
            self.chain_id,
            self.anchor_address,
        )
        .inspect_err(|_err| {
            record_validation_failure("response_validate");
        })?;

        self.ingest_validated_envelope(Arc::new(envelope), "response").await?;

        Ok(())
    }

    /// Shared cache/L2 lookup used by gossip block-hash request handling.
    async fn lookup_block_for_serving(
        &mut self,
        from: libp2p::PeerId,
        hash: B256,
        labels: &LookupLabels,
    ) -> Result<LookupResult> {
        if let Some(envelope) = self.pending.get_recent(&hash) {
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::RESPONSE_LOOKUPS_TOTAL,
                "result" => labels.cache_hit,
            )
            .increment(1);
            debug!(
                peer = %from,
                hash = %hash,
                "{}: serving response from recent cache", labels.log_prefix,
            );
            // Re-insert to refresh LRU position so recently-served blocks stay cached.
            self.pending.insert_recent_only(envelope.clone());
            self.update_cache_gauges();
            return Ok(LookupResult::CacheHit(envelope));
        }

        let Some(envelope) = self.build_response_envelope_from_l2(hash).await? else {
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::RESPONSE_LOOKUPS_TOTAL,
                "result" => labels.not_found,
            )
            .increment(1);
            debug!(
                peer = %from,
                hash = %hash,
                "{}: hash not found in recent cache or local l2", labels.log_prefix,
            );
            return Ok(LookupResult::NotFound);
        };

        metrics::counter!(
            WhitelistPreconfirmationDriverMetrics::RESPONSE_LOOKUPS_TOTAL,
            "result" => labels.l2_hit,
        )
        .increment(1);
        debug!(
            peer = %from,
            hash = %hash,
            "{}: serving response from local l2 block lookup", labels.log_prefix,
        );
        let envelope = Arc::new(envelope);
        self.pending.insert_recent_only(envelope.clone());
        self.update_cache_gauges();
        Ok(LookupResult::L2Hit(envelope))
    }

    /// Handle a block-hash request from the request topic.
    pub(super) async fn handle_unsafe_request(
        &mut self,
        from: libp2p::PeerId,
        hash: B256,
    ) -> Result<()> {
        match self.lookup_block_for_serving(from, hash, &GOSSIP_LOOKUP_LABELS).await? {
            LookupResult::CacheHit(envelope) | LookupResult::L2Hit(envelope) => {
                let decision = ImportDecision::Respond(envelope);
                let ImportDecision::Respond(envelope) = decision else { unreachable!() };
                self.publish_unsafe_response(envelope).await;
            }
            LookupResult::NotFound => {}
        }
        Ok(())
    }
}
