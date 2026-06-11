//! Ingress entrypoints for unsafe payload and response handling.
//!
//! Signature authenticity and operator-set membership are enforced at gossip
//! acceptance time in the network layer's inbound validation
//! (`network::handler::GossipsubInboundState`) before events are forwarded
//! here, so these entrypoints perform payload-level validation only.

use std::sync::Arc;

use alloy_primitives::B256;
use alloy_provider::Provider;
use tracing::debug;

use crate::{
    codec::{DecodedUnsafePayload, WhitelistExecutionPayloadEnvelope},
    error::Result,
    metrics::WhitelistPreconfirmationDriverMetrics,
};

use super::{
    WhitelistPreconfirmationImporter,
    validation::{
        normalize_unsafe_payload_envelope, validate_envelope_header_difficulty,
        validate_execution_payload_for_preconf,
    },
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
        self.update_pending_cache_gauge();
        self.state.insert_recent(envelope.clone()).await;
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
            self.state.record_end_of_sequencing(epoch, envelope.execution_payload.block_hash).await;
        }
    }

    /// Handle an incoming unsafe payload from the `preconfBlocks` topic.
    pub(super) async fn handle_unsafe_payload(
        &mut self,
        payload: DecodedUnsafePayload,
    ) -> Result<()> {
        let envelope = normalize_unsafe_payload_envelope(payload.envelope, payload.wire_signature);
        validate_execution_payload_for_preconf(
            &envelope.execution_payload,
            self.chain_id,
            self.anchor_address,
        )?;
        validate_envelope_header_difficulty(
            self.chain_id,
            envelope.execution_payload.timestamp,
            envelope.header_difficulty,
        )?;
        self.ingest_validated_envelope(Arc::new(envelope), "payload").await;

        Ok(())
    }

    /// Handle an incoming unsafe response from the `responsePreconfBlocks` topic.
    pub(super) async fn handle_unsafe_response(
        &mut self,
        envelope: WhitelistExecutionPayloadEnvelope,
    ) -> Result<()> {
        validate_execution_payload_for_preconf(
            &envelope.execution_payload,
            self.chain_id,
            self.anchor_address,
        )?;
        validate_envelope_header_difficulty(
            self.chain_id,
            envelope.execution_payload.timestamp,
            envelope.header_difficulty,
        )?;

        self.ingest_validated_envelope(Arc::new(envelope), "response").await;

        Ok(())
    }

    /// Handle a block-hash request from the request topic.
    pub(super) async fn handle_unsafe_request(&mut self, hash: B256) -> Result<()> {
        let (envelope, result_label) = if let Some(envelope) = self.state.get_recent(&hash).await {
            (envelope, "cache_hit")
        } else if let Some(envelope) = self.build_response_envelope_from_l2(hash).await? {
            (Arc::new(envelope), "l2_hit")
        } else {
            WhitelistPreconfirmationDriverMetrics::inc_response_lookup("not_found");
            return Ok(());
        };

        WhitelistPreconfirmationDriverMetrics::inc_response_lookup(result_label);
        self.state.insert_recent(envelope.clone()).await;
        self.publish_unsafe_response(envelope).await;
        Ok(())
    }
}
