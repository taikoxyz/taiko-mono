//! Ingress entrypoints for unsafe payload handling and request/response serving.
//!
//! Signature authenticity and operator-set membership are enforced at gossip
//! acceptance time in the network layer's inbound validation
//! (`network::handler::GossipsubInboundState`) before events are forwarded
//! here, so these entrypoints perform payload-level validation only.

use std::sync::Arc;

use alloy_consensus::TxEnvelope;
use alloy_eips::Encodable2718;
use alloy_primitives::{B256, Bytes, U256};
use alloy_provider::Provider;
use alloy_rpc_types::eth::Transaction as RpcTransaction;
use protocol::codec::ZlibTxListCodec;
use tracing::{debug, warn};

use crate::{
    codec::{
        DecodedUnsafePayload, MAX_COMPRESSED_TX_LIST_BYTES, MAX_DECOMPRESSED_TX_LIST_BYTES,
        WhitelistExecutionPayloadEnvelope,
    },
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
    network::NetworkCommand,
};

use super::{
    WhitelistPreconfirmationImporter,
    validation::{validate_envelope_header_difficulty, validate_execution_payload_for_preconf},
};

/// Return whether an envelope is at or below a written event-confirmed tip.
pub(super) fn is_stale_at_confirmed_tip(block_number: u64, confirmed_tip: Option<u64>) -> bool {
    confirmed_tip.is_some_and(|tip| block_number <= tip)
}

impl WhitelistPreconfirmationImporter {
    /// Cache a validated envelope and persist EOS epoch mapping when applicable.
    ///
    /// The admission-time staleness check is a best-effort filter: the authoritative
    /// WLP-INV-003 boundary checks run again at cache drain, response serving, and driver
    /// ingress. A transient confirmed-tip read failure therefore admits the envelope instead
    /// of dropping it — gossipsub dedupe suppresses redelivery of the same message and a tip
    /// or EOS envelope with no later child never triggers a parent request, so a dropped
    /// envelope would be unrecoverable until L1 confirmation catches up.
    async fn ingest_validated_envelope(
        &mut self,
        envelope: Arc<WhitelistExecutionPayloadEnvelope>,
        ingress_source: &'static str,
    ) {
        let confirmed_tip = match self.head_l1_origin_block_id().await {
            Ok(tip) => tip,
            Err(err) => {
                warn!(
                    block_number = envelope.execution_payload.block_number,
                    block_hash = %envelope.execution_payload.block_hash,
                    ingress_source,
                    error = %err,
                    "confirmed-tip lookup failed at admission; admitting envelope for deferred stale checks"
                );
                None
            }
        };
        if is_stale_at_confirmed_tip(envelope.execution_payload.block_number, confirmed_tip) {
            debug!(
                block_number = envelope.execution_payload.block_number,
                block_hash = %envelope.execution_payload.block_hash,
                ?confirmed_tip,
                ingress_source,
                "ignoring stale whitelist preconfirmation envelope"
            );
            return;
        }

        self.cache.insert(envelope.clone());
        self.update_pending_cache_gauge();
        self.state.insert_recent(envelope.clone()).await;
        self.record_eos_epoch_if_marked(&envelope, ingress_source).await;
    }

    /// Record the envelope block hash for its beacon epoch when `end_of_sequencing` is set.
    async fn record_eos_epoch_if_marked(
        &mut self,
        envelope: &WhitelistExecutionPayloadEnvelope,
        ingress_source: &'static str,
    ) {
        if !envelope.end_of_sequencing.unwrap_or(false) {
            return;
        }

        // The EOS flag is only trusted from the payload topic, where the wire
        // signature covers the whole SSZ envelope including the flag bytes. On
        // the response topic the embedded signature covers only the block
        // hash, so the flag is unauthenticated: any peer could set it on an
        // otherwise-valid response. Ignoring it matches the Go client, which
        // never ingests EOS state from responses.
        if ingress_source != "payload" {
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
            // Record the marker at admission (before import) so EOS catch-up
            // requests can be served immediately. The `/ws` notification is
            // deliberately NOT sent here: it fires once the block has
            // materialized, in `try_import_cached`. The hash is remembered in
            // the tracker rather than re-read from the pending cache at import
            // time, because that cache overwrites same-hash entries — a later
            // response envelope could otherwise rewrite the flag unauthenticated.
            self.state.record_end_of_sequencing(epoch, envelope.execution_payload.block_hash).await;
            self.payload_eos_tracker.mark(envelope.execution_payload.block_hash);
        }
    }

    /// Handle an incoming unsafe payload from the `preconfBlocks` topic.
    ///
    /// The wire signature is deliberately NOT copied into the envelope's embedded
    /// signature slot when the latter is absent: the wire signature signs the SSZ
    /// envelope bytes while the embedded slot is verified against the block hash
    /// (a different domain), so a substituted signature would be persisted to the
    /// L1 origin and served in responses every peer rejects. The Go client keeps
    /// the slot empty and declines to serve such blocks; match that.
    pub(super) async fn handle_unsafe_payload(
        &mut self,
        payload: DecodedUnsafePayload,
    ) -> Result<()> {
        self.validate_and_ingest(payload.envelope, "payload").await
    }

    /// Handle an incoming unsafe response from the `responsePreconfBlocks` topic.
    pub(super) async fn handle_unsafe_response(
        &mut self,
        envelope: WhitelistExecutionPayloadEnvelope,
    ) -> Result<()> {
        self.validate_and_ingest(envelope, "response").await
    }

    /// Run payload-level validation and ingest the envelope, tagged with its ingress source.
    ///
    /// This is the single ordering site for the validation that runs before any preconfirmation
    /// envelope is cached.
    async fn validate_and_ingest(
        &mut self,
        envelope: WhitelistExecutionPayloadEnvelope,
        ingress_source: &'static str,
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
        self.ingest_validated_envelope(Arc::new(envelope), ingress_source).await;
        Ok(())
    }

    /// Serve an envelope by block hash from the recent cache or local L2 state,
    /// publishing it on the response topic.
    ///
    /// Returns the source label of the served envelope, or `None` when the hash
    /// is not servable. `mark_end_of_sequencing` tags envelopes rebuilt from L2
    /// so EOS catch-up responses carry the marker.
    pub(super) async fn serve_envelope_by_hash(
        &mut self,
        hash: B256,
        mark_end_of_sequencing: bool,
    ) -> Result<Option<&'static str>> {
        // Envelopes without a non-zero embedded signature are never servable:
        // response receivers verify that signature against the block hash, so
        // an absent or all-zero signature (which the wire format can carry) is
        // rejected by every peer. Fall through to the L2 rebuild, which
        // declines on a zero L1-origin signature — matching the Go client,
        // which only ever serves from L2 state under the same zero check.
        let (envelope, source) = if let Some(envelope) =
            self.state.get_recent(&hash).await.filter(|envelope| {
                envelope.signature.is_some_and(|signature| signature != [0u8; 65])
            }) {
            (envelope, "cache_hit")
        } else if let Some(mut envelope) = self.build_response_envelope_from_l2(hash).await? {
            if mark_end_of_sequencing {
                envelope.end_of_sequencing = Some(true);
            }
            (Arc::new(envelope), "l2_hit")
        } else {
            return Ok(None);
        };

        let confirmed_tip = self.head_l1_origin_block_id().await?;
        if is_stale_at_confirmed_tip(envelope.execution_payload.block_number, confirmed_tip) {
            debug!(
                block_number = envelope.execution_payload.block_number,
                block_hash = %hash,
                ?confirmed_tip,
                source,
                "refusing to serve stale whitelist preconfirmation envelope"
            );
            self.state.remove_recent(&hash).await;
            return Ok(None);
        }

        self.state.insert_recent(envelope.clone()).await;
        self.publish_unsafe_response(envelope).await;
        Ok(Some(source))
    }

    /// Handle a block-hash request from the request topic.
    pub(super) async fn handle_unsafe_request(&mut self, hash: B256) -> Result<()> {
        let label = self.serve_envelope_by_hash(hash, false).await?.unwrap_or("not_found");
        WhitelistPreconfirmationDriverMetrics::inc_response_lookup(label);
        Ok(())
    }

    /// Build a response envelope from local L2 state for an unsafe request hash.
    async fn build_response_envelope_from_l2(
        &self,
        hash: B256,
    ) -> Result<Option<WhitelistExecutionPayloadEnvelope>> {
        let Some(block) = self
            .rpc
            .l2_provider
            .get_block_by_hash(hash)
            .full()
            .await
            .map_err(WhitelistPreconfirmationDriverError::provider)?
            .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
        else {
            return Ok(None);
        };

        if self
            .head_l1_origin_block_id()
            .await?
            .is_some_and(|head_l1_origin_block_id| block.header.number <= head_l1_origin_block_id)
        {
            return Ok(None);
        }

        let Some(l1_origin) = self.rpc.l1_origin_by_id(U256::from(block.header.number)).await?
        else {
            return Ok(None);
        };

        if l1_origin.signature == [0u8; 65] {
            return Ok(None);
        }

        let Some(transactions) = block.transactions.as_transactions() else {
            return Err(WhitelistPreconfirmationDriverError::invalid_payload(
                "request-response block missing full transaction bodies",
            ));
        };

        let raw_transactions = transactions
            .iter()
            .map(|tx: &TxEnvelope| tx.encoded_2718().to_vec())
            .collect::<Vec<_>>();
        let compressed_tx_list = ZlibTxListCodec::new_with_limits(
            MAX_COMPRESSED_TX_LIST_BYTES,
            MAX_DECOMPRESSED_TX_LIST_BYTES,
        )
        .encode(&raw_transactions)
        .map_err(|err| {
            WhitelistPreconfirmationDriverError::invalid_payload_with_context(
                "failed to encode request-response tx list",
                err,
            )
        })?;

        let end_of_sequencing = self
            .cache
            .get(&hash)
            .and_then(|envelope| envelope.end_of_sequencing)
            .filter(|&enabled| enabled);
        let base_fee = block.header.base_fee_per_gas.ok_or_else(|| {
            WhitelistPreconfirmationDriverError::invalid_payload(format!(
                "request-response block {} missing base fee",
                block.header.number
            ))
        })?;

        Ok(Some(WhitelistExecutionPayloadEnvelope {
            end_of_sequencing,
            is_forced_inclusion: l1_origin.is_forced_inclusion.then_some(true),
            // Intentionally None — the sequencer never populates this field
            // in the envelope (see rest_handler.rs), and the SSZ wire format
            // encodes None as 32 zero bytes which is the expected default.
            parent_beacon_block_root: None,
            // Carry Unzen header.difficulty (= block_zk_gas_used) so receivers
            // can reconstruct the sender's block hash. Left `None` for Shasta
            // blocks whose difficulty is zero.
            header_difficulty: (!block.header.difficulty.is_zero())
                .then_some(block.header.difficulty),
            execution_payload: crate::payload::execution_payload_from_header(
                &block.header,
                base_fee,
                vec![Bytes::from(compressed_tx_list)],
            ),
            // Use L1-origin signature as-is. This endpoint serves responses
            // only from the local node; caller-side validation and allowlist
            // checks are performed when importing the envelope.
            signature: Some(l1_origin.signature),
        }))
    }

    /// Queue an outbound network command and record the publish-queue outcome.
    ///
    /// `topic_label` identifies the metric series, `hash` is included in the failure
    /// log to identify the affected block, and `failure_message` is the static log
    /// message emitted when queuing fails.
    async fn queue_network_command(
        &self,
        command: NetworkCommand,
        topic_label: &'static str,
        hash: B256,
        failure_message: &'static str,
    ) {
        if let Err(err) = self.network_command_tx.send(command).await {
            WhitelistPreconfirmationDriverMetrics::inc_network_outbound_publish(
                topic_label,
                "queue_failed",
            );
            warn!(hash = %hash, error = %err, "{failure_message}");
        } else {
            WhitelistPreconfirmationDriverMetrics::inc_network_outbound_publish(
                topic_label,
                "queued",
            );
        }
    }

    /// Publish a block-hash request on `requestPreconfBlocks`.
    pub(super) async fn publish_unsafe_request(&self, hash: B256) {
        self.queue_network_command(
            NetworkCommand::PublishUnsafeRequest { hash },
            "request_preconf_blocks",
            hash,
            "failed to queue whitelist preconfirmation request publish command",
        )
        .await;
    }

    /// Publish an envelope response on `responsePreconfBlocks`.
    async fn publish_unsafe_response(&self, envelope: Arc<WhitelistExecutionPayloadEnvelope>) {
        let hash = envelope.execution_payload.block_hash;
        self.queue_network_command(
            NetworkCommand::PublishUnsafeResponse { envelope },
            "response_preconf_blocks",
            hash,
            "failed to queue whitelist preconfirmation response publish command",
        )
        .await;
    }
}
