//! Ingress entrypoints for unsafe payload and response handling.

use std::sync::Arc;

use alloy_primitives::B256;
use alloy_provider::Provider;
use tracing::debug;

use crate::{
    codec::{
        DecodedUnsafePayload, WhitelistExecutionPayloadEnvelope, block_signing_hash, recover_signer,
    },
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
};

use super::{
    WhitelistPreconfirmationImporter,
    validation::{normalize_unsafe_payload_envelope, validate_execution_payload_for_preconf},
};

impl<P> WhitelistPreconfirmationImporter<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Cache a validated envelope and persist EOS epoch mapping when applicable.
    async fn ingest_validated_envelope(
        &mut self,
        envelope: Arc<WhitelistExecutionPayloadEnvelope>,
        ingress_source: &'static str,
    ) {
        self.cache.insert(envelope.clone());
        self.recent_cache.insert_recent(envelope.clone());
        self.update_cache_gauges();
        self.record_eos_epoch_if_marked(&envelope, ingress_source).await;
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
            self.cache_state
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
        let signer = recover_signer(prehash, &payload.wire_signature)?;
        self.ensure_signer_allowed(signer)?;

        let envelope = normalize_unsafe_payload_envelope(payload.envelope, payload.wire_signature);
        validate_execution_payload_for_preconf(
            &envelope.execution_payload,
            self.chain_id,
            self.anchor_address,
        )?;
        self.ingest_validated_envelope(Arc::new(envelope), "payload").await;

        Ok(())
    }

    /// Handle an incoming unsafe response (gossip or direct).
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
            return Err(WhitelistPreconfirmationDriverError::invalid_signature(
                "response payload is missing embedded signature",
            ));
        };

        // Signing domain: block_signing_hash(chain_id, block_hash).
        let prehash =
            block_signing_hash(self.chain_id, envelope.execution_payload.block_hash.as_slice());
        let signer = recover_signer(prehash, &signature)?;
        self.ensure_signer_allowed(signer)?;

        validate_execution_payload_for_preconf(
            &envelope.execution_payload,
            self.chain_id,
            self.anchor_address,
        )?;

        self.ingest_validated_envelope(Arc::new(envelope), "response").await;

        Ok(())
    }

    /// Handle a block-hash request from the request topic.
    pub(super) async fn handle_unsafe_request(&mut self, hash: B256) -> Result<()> {
        let (envelope, result_label) = if let Some(envelope) = self.recent_cache.get_recent(&hash) {
            (envelope, "cache_hit")
        } else if let Some(envelope) = self.build_response_envelope_from_l2(hash).await? {
            (Arc::new(envelope), "l2_hit")
        } else {
            record_response_lookup("not_found");
            return Ok(());
        };

        record_response_lookup(result_label);
        self.recent_cache.insert_recent(envelope.clone());
        self.update_cache_gauges();
        self.publish_unsafe_response(envelope).await;
        Ok(())
    }
}

/// Increment the response-lookup counter with the given result label.
fn record_response_lookup(result: &'static str) {
    metrics::counter!(
        WhitelistPreconfirmationDriverMetrics::RESPONSE_LOOKUPS_TOTAL,
        "result" => result,
    )
    .increment(1);
}
