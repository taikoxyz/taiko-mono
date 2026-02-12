use std::{
    sync::Arc,
    time::{Duration, Instant},
};

use alloy_primitives::B256;
use alloy_provider::Provider;
use sha2::{Digest, Sha256};
use tracing::{debug, warn};

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

/// Maximum deterministic response jitter window used for request replies.
const RESPONSE_JITTER_MAX: Duration = Duration::from_secs(1);
/// Ignore requests targeting blocks more than this many blocks behind local sync tip.
const REQUEST_SYNC_MARGIN_BLOCKS: u64 = 128;

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
        let eos_epoch = self.end_of_sequencing_epoch(&envelope);
        let envelope = Arc::new(envelope);
        self.cache_accepted_envelope(envelope, eos_epoch);

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

        let eos_epoch = self.end_of_sequencing_epoch(&envelope);
        let envelope = Arc::new(envelope);
        let hash = envelope.execution_payload.block_hash;
        self.cache_accepted_envelope(envelope, eos_epoch);
        self.mark_response_seen(hash, Instant::now());
        Ok(())
    }

    /// Handle a block-hash request from the request topic.
    pub(super) async fn handle_unsafe_request(
        &mut self,
        from: libp2p::PeerId,
        hash: B256,
    ) -> Result<()> {
        let envelope = if let Some(envelope) = self.recent_cache.get_recent(&hash) {
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
            envelope
        } else {
            let Some(envelope) = self.build_response_envelope_from_l2(hash).await? else {
                metrics::counter!(
                    WhitelistPreconfirmationDriverMetrics::RESPONSE_LOOKUPS_TOTAL,
                    "result" => "not_found",
                )
                .increment(1);
                debug!(
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
            debug!(
                peer = %from,
                hash = %hash,
                "serving whitelist preconfirmation response from local l2 block lookup"
            );
            Arc::new(envelope)
        };

        if request_outside_sync_margin(
            envelope.execution_payload.block_number,
            self.head_l1_origin_block_id().await?,
        ) {
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::RESPONSE_LOOKUPS_TOTAL,
                "result" => "sync_margin_ignored",
            )
            .increment(1);
            debug!(
                peer = %from,
                hash = %hash,
                block_number = envelope.execution_payload.block_number,
                "ignoring preconfirmation request for block outside sync margin"
            );
            return Ok(());
        }

        let jitter =
            deterministic_response_jitter(&self.local_peer_id, &from, hash, RESPONSE_JITTER_MAX);
        if !jitter.is_zero() {
            // Keep sequential jitter on the importer loop to mirror Go's response-storm damping:
            // a node intentionally delays all pending request handling within this short window.
            // This is an explicit throttle tradeoff; network-edge request dedup/rate-limits
            // bound request pressure before events reach the importer loop.
            tokio::time::sleep(jitter).await;
        }

        let now = Instant::now();
        if self.response_seen_recently(hash, now) {
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::RESPONSE_LOOKUPS_TOTAL,
                "result" => "recent_response_seen",
            )
            .increment(1);
            debug!(
                peer = %from,
                hash = %hash,
                "skipping response because this block hash was recently seen"
            );
            return Ok(());
        }

        if self.recent_cache.get_recent(&hash).is_none() {
            self.runtime_state.increment_total_cached();
        }
        self.recent_cache.insert_recent(envelope.clone());
        self.update_cache_gauges();
        if self.publish_unsafe_response(envelope).await {
            self.mark_response_seen(hash, Instant::now());
        }
        Ok(())
    }

    /// Derive EOS epoch from envelope timestamp when possible.
    pub(super) fn end_of_sequencing_epoch(
        &self,
        envelope: &WhitelistExecutionPayloadEnvelope,
    ) -> Option<u64> {
        if !envelope.end_of_sequencing.unwrap_or(false) {
            return None;
        }

        let beacon_client = self.beacon_client.as_ref()?;

        match beacon_client.epoch_for_timestamp(envelope.execution_payload.timestamp) {
            Ok(epoch) => Some(epoch),
            Err(err) => {
                warn!(
                    error = %err,
                    block_number = envelope.execution_payload.block_number,
                    block_hash = %envelope.execution_payload.block_hash,
                    timestamp = envelope.execution_payload.timestamp,
                    "failed to derive end-of-sequencing epoch from payload timestamp"
                );
                None
            }
        }
    }
}

/// Return true if request should be ignored because it is outside the local sync margin.
fn request_outside_sync_margin(
    requested_block_number: u64,
    sync_tip_block_number: Option<u64>,
) -> bool {
    let Some(sync_tip_block_number) = sync_tip_block_number else {
        return false;
    };

    sync_tip_block_number >= REQUEST_SYNC_MARGIN_BLOCKS &&
        requested_block_number <=
            sync_tip_block_number.saturating_sub(REQUEST_SYNC_MARGIN_BLOCKS)
}

/// Deterministic jitter used before responding to preconfirmation requests.
fn deterministic_response_jitter(
    local_peer_id: &libp2p::PeerId,
    requester_peer_id: &libp2p::PeerId,
    hash: B256,
    max: Duration,
) -> Duration {
    if max.is_zero() {
        return Duration::ZERO;
    }

    let mut hasher = Sha256::new();
    hasher.update(local_peer_id.to_bytes());
    hasher.update(requester_peer_id.to_bytes());
    hasher.update(hash.as_slice());
    let digest = hasher.finalize();

    let mut jitter_bytes = [0u8; 8];
    jitter_bytes.copy_from_slice(&digest[..8]);
    let jitter_seed = u64::from_le_bytes(jitter_bytes);
    let max_nanos = max.as_nanos();
    let jitter_nanos = (u128::from(jitter_seed) % max_nanos) as u64;
    Duration::from_nanos(jitter_nanos)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deterministic_response_jitter_is_stable_and_bounded() {
        let local_peer = libp2p::PeerId::random();
        let peer = libp2p::PeerId::random();
        let hash = B256::from([0xabu8; 32]);
        let max = Duration::from_secs(1);

        let first = deterministic_response_jitter(&local_peer, &peer, hash, max);
        let second = deterministic_response_jitter(&local_peer, &peer, hash, max);
        assert_eq!(first, second, "jitter should be deterministic for the same inputs");
        assert!(first < max, "jitter must stay below maximum window");
    }

    #[test]
    fn deterministic_response_jitter_varies_per_local_peer() {
        let local_peer_a = libp2p::PeerId::random();
        let local_peer_b = libp2p::PeerId::random();
        let requester_peer = libp2p::PeerId::random();
        let hash = B256::from([0x55u8; 32]);
        let max = Duration::from_secs(10);

        let jitter_a = deterministic_response_jitter(&local_peer_a, &requester_peer, hash, max);
        let jitter_b = deterministic_response_jitter(&local_peer_b, &requester_peer, hash, max);
        assert_ne!(
            jitter_a, jitter_b,
            "local peer id salt should decorrelate jitter across responders"
        );
    }

    #[test]
    fn request_outside_sync_margin_matches_go_style_boundaries() {
        assert!(!request_outside_sync_margin(10, None));
        assert!(!request_outside_sync_margin(10, Some(127)));
        assert!(!request_outside_sync_margin(10, Some(128)));
        assert!(!request_outside_sync_margin(1, Some(128)));

        assert!(request_outside_sync_margin(1, Some(129)));
        assert!(request_outside_sync_margin(100, Some(1_000)));
        assert!(!request_outside_sync_margin(900, Some(1_000)));
    }
}
