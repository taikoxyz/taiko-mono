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
    /// Handle an incoming unsafe payload.
    pub(super) async fn handle_unsafe_payload(
        &mut self,
        payload: DecodedUnsafePayload,
    ) -> Result<()> {
        let prehash = block_signing_hash(self.chain_id, payload.payload_bytes.as_slice());
        let signer = match recover_signer(prehash, &payload.wire_signature) {
            Ok(signer) => signer,
            Err(err) => {
                metrics::counter!(
                    WhitelistPreconfirmationDriverMetrics::VALIDATION_FAILURES_TOTAL,
                    "stage" => "payload_signature_recover",
                )
                .increment(1);
                return Err(err);
            }
        };
        if let Err(err) = self.ensure_signer_allowed(signer).await {
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::VALIDATION_FAILURES_TOTAL,
                "stage" => "payload_signer_check",
            )
            .increment(1);
            return Err(err);
        }

        let envelope = normalize_unsafe_payload_envelope(payload.envelope, payload.wire_signature);
        if let Err(err) = validate_execution_payload_for_preconf(
            &envelope.execution_payload,
            self.chain_id,
            self.anchor_address,
        ) {
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::VALIDATION_FAILURES_TOTAL,
                "stage" => "payload_validate",
            )
            .increment(1);
            return Err(err);
        }
        let envelope = Arc::new(envelope);
        self.cache.insert(envelope.clone());
        self.recent_cache.insert_recent(envelope.clone());
        self.update_cache_gauges();

        if envelope.end_of_sequencing.unwrap_or(false) {
            match self.beacon_client.timestamp_to_epoch(envelope.execution_payload.timestamp) {
                Ok(epoch) => {
                    debug!(
                        epoch,
                        hash = %envelope.execution_payload.block_hash,
                        "recording end-of-sequencing envelope for epoch on payload ingress"
                    );
                    self.cache_state
                        .record_end_of_sequencing(epoch, envelope.execution_payload.block_hash)
                        .await;
                }
                Err(err) => {
                    tracing::warn!(
                        timestamp = envelope.execution_payload.timestamp,
                        error = %err,
                        "failed to derive epoch from payload timestamp for EOS recording"
                    );
                }
            }
        }

        Ok(())
    }

    /// Handle an incoming unsafe response.
    pub(super) async fn handle_unsafe_response(
        &mut self,
        envelope: WhitelistExecutionPayloadEnvelope,
    ) -> Result<()> {
        let Some(signature) = envelope.signature else {
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::VALIDATION_FAILURES_TOTAL,
                "stage" => "response_missing_signature",
            )
            .increment(1);
            return Err(WhitelistPreconfirmationDriverError::InvalidSignature(
                "response payload is missing embedded signature".to_string(),
            ));
        };

        let prehash =
            block_signing_hash(self.chain_id, envelope.execution_payload.block_hash.as_slice());
        let signer = match recover_signer(prehash, &signature) {
            Ok(signer) => signer,
            Err(err) => {
                metrics::counter!(
                    WhitelistPreconfirmationDriverMetrics::VALIDATION_FAILURES_TOTAL,
                    "stage" => "response_signature_recover",
                )
                .increment(1);
                return Err(err);
            }
        };
        if let Err(err) = self.ensure_signer_allowed(signer).await {
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::VALIDATION_FAILURES_TOTAL,
                "stage" => "response_signer_check",
            )
            .increment(1);
            return Err(err);
        }

        if let Err(err) = validate_execution_payload_for_preconf(
            &envelope.execution_payload,
            self.chain_id,
            self.anchor_address,
        ) {
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::VALIDATION_FAILURES_TOTAL,
                "stage" => "response_validate",
            )
            .increment(1);
            return Err(err);
        }

        let envelope = Arc::new(envelope);
        self.cache.insert(envelope.clone());
        self.recent_cache.insert_recent(envelope.clone());
        self.update_cache_gauges();

        if envelope.end_of_sequencing.unwrap_or(false) {
            match self.beacon_client.timestamp_to_epoch(envelope.execution_payload.timestamp) {
                Ok(epoch) => {
                    debug!(
                        epoch,
                        hash = %envelope.execution_payload.block_hash,
                        "recording end-of-sequencing envelope for epoch on response ingress"
                    );
                    self.cache_state
                        .record_end_of_sequencing(epoch, envelope.execution_payload.block_hash)
                        .await;
                }
                Err(err) => {
                    tracing::warn!(
                        timestamp = envelope.execution_payload.timestamp,
                        error = %err,
                        "failed to derive epoch from response timestamp for EOS recording"
                    );
                }
            }
        }

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
