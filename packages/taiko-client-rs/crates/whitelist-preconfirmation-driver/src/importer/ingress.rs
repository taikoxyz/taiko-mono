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

/// Increment validation failure metrics for the given ingest stage.
fn record_validation_failure(stage: &'static str) {
    metrics::counter!(
        WhitelistPreconfirmationDriverMetrics::VALIDATION_FAILURES_TOTAL,
        "stage" => stage,
    )
    .increment(1);
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
        self.ingest_validated_envelope(Arc::new(envelope), "payload").await;

        Ok(())
    }

    /// Handle an incoming unsafe response.
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

        self.ingest_validated_envelope(Arc::new(envelope), "response").await;

        Ok(())
    }

    /// Handle a block-hash request from the request topic.
    pub(super) async fn handle_unsafe_request(
        &mut self,
        from: libp2p::PeerId,
        hash: B256,
    ) -> Result<()> {
        if let Some(envelope) = self.recent_cache.get_recent(&hash) {
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::RESPONSE_LOOKUPS_TOTAL,
                "result" => "cache_hit",
            )
            .increment(1);
            tracing::debug!(
                peer = %from,
                hash = %hash,
                "serving whitelist preconfirmation response from recent cache"
            );
            self.recent_cache.insert_recent(envelope.clone());
            self.update_cache_gauges();
            self.publish_unsafe_response(envelope).await;
            return Ok(());
        }

        let Some(envelope) = self.build_response_envelope_from_l2(hash).await? else {
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::RESPONSE_LOOKUPS_TOTAL,
                "result" => "not_found",
            )
            .increment(1);
            tracing::debug!(
                peer = %from,
                hash = %hash,
                "requested whitelist preconfirmation hash not found in recent cache or local l2"
            );
            return Ok(());
        };

        metrics::counter!(
            WhitelistPreconfirmationDriverMetrics::RESPONSE_LOOKUPS_TOTAL,
            "result" => "l2_hit",
        )
        .increment(1);
        tracing::debug!(
            peer = %from,
            hash = %hash,
            "serving whitelist preconfirmation response from local l2 block lookup"
        );
        let envelope = Arc::new(envelope);
        self.recent_cache.insert_recent(envelope.clone());
        self.update_cache_gauges();
        self.publish_unsafe_response(envelope).await;
        Ok(())
    }
}
