//! Whitelist preconfirmation envelope importer.

use std::{io::Read, sync::Arc, time::Instant};

use alethia_reth_primitives::payload::{
    attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes},
    builder::payload_id_taiko,
};
use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{Address, B256, Bytes, U256};
use alloy_provider::Provider;
use alloy_rpc_types_engine::PayloadAttributes as EthPayloadAttributes;
use bindings::preconf_whitelist::PreconfWhitelist::PreconfWhitelistInstance;
use driver::{production::PreconfPayload, sync::event::EventSyncer};
use flate2::read::ZlibDecoder;
use protocol::shasta::{PAYLOAD_ID_VERSION_V2, payload_id_to_bytes};
use rpc::client::Client;
use tracing::{debug, info, warn};

use crate::{
    cache::{CachedEnvelope, EnvelopeCache, RecentEnvelopeCache, RequestThrottle},
    codec::{
        DecodedUnsafePayload, WhitelistExecutionPayloadEnvelope, block_signing_hash, recover_signer,
    },
    error::{Result, WhitelistPreconfirmationDriverError},
    network::{NetworkCommand, NetworkEvent},
};

/// Maximum compressed tx-list size accepted from a preconfirmation payload.
const MAX_COMPRESSED_TX_LIST_BYTES: usize = 131_072 * 6;

/// Imports whitelist preconfirmation payloads into the driver after event sync catches up.
pub(crate) struct WhitelistPreconfirmationImporter<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Event syncer used to submit validated preconfirmation payloads.
    event_syncer: Arc<EventSyncer<P>>,
    /// RPC client used for L1/L2 reads and head-origin updates.
    rpc: Client<P>,
    /// On-chain whitelist contract instance used to validate sequencer signers.
    whitelist: PreconfWhitelistInstance<P>,
    /// Chain id used for preconfirmation signature domain separation.
    chain_id: u64,
    /// Out-of-order payload cache waiting for parent availability.
    cache: EnvelopeCache,
    /// Recently accepted envelopes that can be served over response topic requests.
    recent_cache: RecentEnvelopeCache,
    /// Cooldown gate for repeated missing-parent requests.
    request_throttle: RequestThrottle,
    /// Command channel used to publish P2P requests/responses.
    network_command_tx: tokio::sync::mpsc::Sender<NetworkCommand>,
    /// Latched flag indicating event sync has exposed a head L1 origin.
    sync_ready: bool,
}

impl<P> WhitelistPreconfirmationImporter<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build an importer.
    pub(crate) fn new(
        event_syncer: Arc<EventSyncer<P>>,
        rpc: Client<P>,
        whitelist_address: Address,
        chain_id: u64,
        network_command_tx: tokio::sync::mpsc::Sender<NetworkCommand>,
    ) -> Self {
        let whitelist = PreconfWhitelistInstance::new(whitelist_address, rpc.l1_provider.clone());

        Self {
            event_syncer,
            rpc,
            whitelist,
            chain_id,
            cache: EnvelopeCache::default(),
            recent_cache: RecentEnvelopeCache::default(),
            request_throttle: RequestThrottle::default(),
            network_command_tx,
            sync_ready: false,
        }
    }

    /// Handle one network event.
    pub(crate) async fn handle_event(&mut self, event: NetworkEvent) -> Result<()> {
        match event {
            NetworkEvent::UnsafePayload { from, payload } => {
                if let Err(err) = self.handle_unsafe_payload(payload).await {
                    warn!(peer = %from, error = %err, "dropping invalid whitelist preconfirmation payload");
                }
            }
            NetworkEvent::UnsafeResponse { from, envelope } => {
                if let Err(err) = self.handle_unsafe_response(envelope).await {
                    warn!(peer = %from, error = %err, "dropping invalid whitelist preconfirmation response");
                }
            }
            NetworkEvent::UnsafeRequest { from, hash } => {
                if let Some(envelope) = self.recent_cache.get_recent(&hash) {
                    debug!(
                        peer = %from,
                        hash = %hash,
                        "serving whitelist preconfirmation response from recent cache"
                    );
                    self.publish_unsafe_response(envelope).await;
                } else {
                    debug!(
                        peer = %from,
                        hash = %hash,
                        "requested whitelist preconfirmation hash not found in recent cache"
                    );
                }
            }
            NetworkEvent::EndOfSequencingRequest { from, epoch } => {
                debug!(peer = %from, epoch, "ignoring end-of-sequencing request topic");
            }
        }

        self.maybe_import_from_cache().await
    }

    /// Periodic maintenance tick.
    pub(crate) async fn on_tick(&mut self) -> Result<()> {
        self.maybe_import_from_cache().await
    }

    /// Handle an incoming unsafe payload.
    async fn handle_unsafe_payload(&mut self, payload: DecodedUnsafePayload) -> Result<()> {
        let prehash = block_signing_hash(self.chain_id, payload.payload_bytes.as_slice());
        let signer = recover_signer(prehash, &payload.wire_signature)?;
        self.ensure_signer_allowed(signer).await?;

        let envelope = normalize_unsafe_payload_envelope(payload.envelope, payload.wire_signature);
        validate_execution_payload_for_preconf(&envelope.execution_payload)?;
        self.cache.insert(CachedEnvelope { envelope: envelope.clone() });
        self.recent_cache.insert_recent(envelope);

        Ok(())
    }

    /// Handle an incoming unsafe response.
    async fn handle_unsafe_response(
        &mut self,
        envelope: WhitelistExecutionPayloadEnvelope,
    ) -> Result<()> {
        let Some(signature) = envelope.signature else {
            return Err(WhitelistPreconfirmationDriverError::InvalidSignature(
                "response payload is missing embedded signature".to_string(),
            ));
        };

        let prehash =
            block_signing_hash(self.chain_id, envelope.execution_payload.block_hash.as_slice());
        let signer = recover_signer(prehash, &signature)?;
        self.ensure_signer_allowed(signer).await?;

        validate_execution_payload_for_preconf(&envelope.execution_payload)?;
        self.cache.insert(CachedEnvelope { envelope: envelope.clone() });
        self.recent_cache.insert_recent(envelope);
        Ok(())
    }

    /// Attempt to import cached envelopes if sync is ready.
    async fn maybe_import_from_cache(&mut self) -> Result<()> {
        if !self.refresh_sync_ready().await? || self.cache.is_empty() {
            return Ok(());
        }

        let mut cache = std::mem::take(&mut self.cache);
        loop {
            let mut progressed = false;
            let hashes = cache.sorted_hashes_by_block_number();

            for hash in hashes {
                let Some(entry) = cache.get(&hash) else {
                    continue;
                };
                match self.try_import_cached(entry).await {
                    Ok(true) => {
                        cache.remove(&hash);
                        progressed = true;
                    }
                    Ok(false) => {}
                    Err(err) if should_drop_cached_import_error(&err) => {
                        warn!(
                            block_hash = %hash,
                            error = %err,
                            "dropping cached whitelist preconfirmation payload after invalid import"
                        );
                        cache.remove(&hash);
                        progressed = true;
                    }
                    Err(err) => {
                        self.cache = cache;
                        return Err(err);
                    }
                }
            }

            if !progressed {
                break;
            }
        }

        self.cache = cache;
        Ok(())
    }

    /// Try to import one cached envelope.
    async fn try_import_cached(&mut self, entry: &CachedEnvelope) -> Result<bool> {
        let envelope = &entry.envelope;
        let payload = &envelope.execution_payload;
        let block_number = payload.block_number;
        let block_hash = payload.block_hash;
        let end_of_sequencing = envelope.end_of_sequencing.unwrap_or(false);

        let Some(head_l1_origin_block_id) = self.head_l1_origin_block_id().await? else {
            return Ok(false);
        };

        if block_number <= head_l1_origin_block_id {
            debug!(
                block_number,
                block_hash = %block_hash,
                head_l1_origin_block_id,
                "dropping outdated cached whitelist preconfirmation payload"
            );
            return Ok(true);
        }

        if self.block_hash_by_number(block_number).await? == Some(block_hash) {
            debug!(
                block_number,
                block_hash = %block_hash,
                "dropping already-inserted whitelist preconfirmation payload"
            );
            return Ok(true);
        }

        if block_number == 0 {
            return Ok(true);
        }

        let parent_hash = payload.parent_hash;
        let parent_number = block_number.saturating_sub(1);
        if self.block_hash_by_number(parent_number).await? != Some(parent_hash) {
            if self.request_throttle.should_request(parent_hash, Instant::now()) {
                self.publish_unsafe_request(parent_hash).await;
            } else {
                debug!(
                    block_number,
                    block_hash = %block_hash,
                    parent_hash = %parent_hash,
                    "throttling duplicate whitelist preconfirmation parent request"
                );
            }
            return Ok(false);
        }

        let driver_payload = self.build_driver_payload(envelope)?;
        self.event_syncer
            .submit_preconfirmation_payload(PreconfPayload::new(driver_payload.clone()))
            .await?;

        let inserted_hash = self
            .block_hash_by_number(block_number)
            .await?
            .ok_or(WhitelistPreconfirmationDriverError::MissingInsertedBlock(block_number))?;

        if inserted_hash != block_hash {
            return Err(WhitelistPreconfirmationDriverError::InsertedBlockHashMismatch {
                block_number,
                expected: block_hash,
                actual: inserted_hash,
            });
        }

        self.update_l1_origin(inserted_hash, &driver_payload.l1_origin).await?;

        info!(
            block_number,
            block_hash = %block_hash,
            parent_hash = %parent_hash,
            end_of_sequencing,
            "inserted whitelist preconfirmation block"
        );

        Ok(true)
    }

    /// Publish a block-hash request on `requestPreconfBlocks`.
    async fn publish_unsafe_request(&self, hash: B256) {
        if let Err(err) =
            self.network_command_tx.send(NetworkCommand::PublishUnsafeRequest { hash }).await
        {
            warn!(
                hash = %hash,
                error = %err,
                "failed to queue whitelist preconfirmation request publish command"
            );
        }
    }

    /// Publish an envelope response on `responsePreconfBlocks`.
    async fn publish_unsafe_response(&self, envelope: WhitelistExecutionPayloadEnvelope) {
        let hash = envelope.execution_payload.block_hash;
        if let Err(err) = self
            .network_command_tx
            .send(NetworkCommand::PublishUnsafeResponse { envelope: Box::new(envelope) })
            .await
        {
            warn!(
                hash = %hash,
                error = %err,
                "failed to queue whitelist preconfirmation response publish command"
            );
        }
    }

    /// Refresh whether sync is ready.
    async fn refresh_sync_ready(&mut self) -> Result<bool> {
        let ready = self.head_l1_origin_block_id().await?.is_some();
        if ready && !self.sync_ready {
            info!(
                "event sync established head l1 origin; enabling whitelist preconfirmation imports"
            );
        }
        self.sync_ready = ready;
        Ok(ready)
    }

    /// Get the block ID of the head L1 origin.
    async fn head_l1_origin_block_id(&self) -> Result<Option<u64>> {
        Ok(self.rpc.head_l1_origin().await?.map(|head| head.block_id.to::<u64>()))
    }

    /// Get the block hash by block number.
    async fn block_hash_by_number(&self, block_number: u64) -> Result<Option<B256>> {
        self.rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(block_number))
            .await
            .map(|opt| opt.map(|block| block.hash()))
            .map_err(provider_err)
    }

    /// Update the L1 origin with the inserted L2 block hash.
    async fn update_l1_origin(&self, block_hash: B256, origin: &RpcL1Origin) -> Result<()> {
        let mut updated = origin.clone();
        updated.l2_block_hash = block_hash;

        self.rpc.update_l1_origin(&updated).await?;
        self.rpc.set_head_l1_origin(updated.block_id).await?;

        Ok(())
    }

    /// Build the driver payload from the whitelist envelope.
    fn build_driver_payload(
        &self,
        envelope: &WhitelistExecutionPayloadEnvelope,
    ) -> Result<TaikoPayloadAttributes> {
        let execution_payload = &envelope.execution_payload;
        let compressed_tx_list = execution_payload.transactions.first().ok_or_else(|| {
            WhitelistPreconfirmationDriverError::InvalidPayload(
                "missing transactions list".to_string(),
            )
        })?;
        let tx_list = decompress_tx_list(compressed_tx_list)?;

        let signature = envelope.signature.unwrap_or([0u8; 65]);

        let block_metadata = TaikoBlockMetadata {
            beneficiary: execution_payload.fee_recipient,
            gas_limit: execution_payload.gas_limit,
            timestamp: U256::from(execution_payload.timestamp),
            mix_hash: execution_payload.prev_randao,
            tx_list: Some(Bytes::from(tx_list)),
            extra_data: execution_payload.extra_data.clone(),
        };

        let payload_attributes = EthPayloadAttributes {
            timestamp: execution_payload.timestamp,
            prev_randao: execution_payload.prev_randao,
            suggested_fee_recipient: execution_payload.fee_recipient,
            withdrawals: Some(Vec::new()),
            parent_beacon_block_root: envelope.parent_beacon_block_root,
        };

        let l1_origin = RpcL1Origin {
            block_id: U256::from(execution_payload.block_number),
            l2_block_hash: B256::ZERO,
            l1_block_height: None,
            l1_block_hash: None,
            build_payload_args_id: [0u8; 8],
            is_forced_inclusion: envelope.is_forced_inclusion.unwrap_or(false),
            signature,
        };

        let mut payload = TaikoPayloadAttributes {
            payload_attributes,
            base_fee_per_gas: execution_payload.base_fee_per_gas,
            block_metadata,
            l1_origin,
            anchor_transaction: None,
        };

        let payload_id =
            payload_id_taiko(&execution_payload.parent_hash, &payload, PAYLOAD_ID_VERSION_V2);
        payload.l1_origin.build_payload_args_id = payload_id_to_bytes(payload_id);

        Ok(payload)
    }

    /// Ensure the signer is allowed in the whitelist.
    async fn ensure_signer_allowed(&self, signer: Address) -> Result<()> {
        let current = self.current_whitelist_sequencer().await?;
        let next = self.next_whitelist_sequencer().await?;

        if signer == current || signer == next {
            return Ok(());
        }

        Err(WhitelistPreconfirmationDriverError::InvalidSignature(format!(
            "signer {signer} is not current ({current}) or next ({next}) whitelist sequencer"
        )))
    }

    /// Get the current whitelist sequencer address.
    async fn current_whitelist_sequencer(&self) -> Result<Address> {
        let proposer = self.whitelist.getOperatorForCurrentEpoch().call().await.map_err(|err| {
            WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "failed to read current whitelist proposer: {err}"
            ))
        })?;

        self.whitelist.operators(proposer).call().await.map(|info| info.sequencerAddress).map_err(
            |err| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                    "failed to read current whitelist sequencer: {err}"
                ))
            },
        )
    }

    /// Get the next whitelist sequencer address.
    async fn next_whitelist_sequencer(&self) -> Result<Address> {
        let proposer = self.whitelist.getOperatorForNextEpoch().call().await.map_err(|err| {
            WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "failed to read next whitelist proposer: {err}"
            ))
        })?;

        self.whitelist.operators(proposer).call().await.map(|info| info.sequencerAddress).map_err(
            |err| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                    "failed to read next whitelist sequencer: {err}"
                ))
            },
        )
    }
}

/// Decompress a zlib-compressed transaction list.
fn decompress_tx_list(bytes: &[u8]) -> Result<Vec<u8>> {
    let mut decoder = ZlibDecoder::new(bytes);
    let mut out = Vec::new();
    decoder.read_to_end(&mut out).map_err(|err| {
        WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "failed to decompress tx list from payload: {err}"
        ))
    })?;

    if out.is_empty() {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(
            "decompressed tx list is empty".to_string(),
        ));
    }

    Ok(out)
}

/// Validate execution payload shape for preconfirmation import compatibility.
fn validate_execution_payload_for_preconf(
    payload: &alloy_rpc_types_engine::ExecutionPayloadV1,
) -> Result<()> {
    if payload.transactions.len() != 1 {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(
            "only one transaction list is allowed".to_string(),
        ));
    }

    if payload.transactions[0].len() > MAX_COMPRESSED_TX_LIST_BYTES {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(
            "compressed transactions size exceeds max blob data size".to_string(),
        ));
    }

    Ok(())
}

/// Convert a provider error into a driver error.
fn provider_err(err: impl std::fmt::Display) -> WhitelistPreconfirmationDriverError {
    WhitelistPreconfirmationDriverError::Rpc(rpc::RpcClientError::Provider(err.to_string()))
}

/// Returns true when a cached-envelope import error should be logged and dropped.
fn should_drop_cached_import_error(err: &WhitelistPreconfirmationDriverError) -> bool {
    match err {
        WhitelistPreconfirmationDriverError::InvalidPayload(_) |
        WhitelistPreconfirmationDriverError::InvalidSignature(_) => true,
        WhitelistPreconfirmationDriverError::Driver(driver_err) => {
            should_drop_cached_driver_error(driver_err)
        }
        _ => false,
    }
}

/// Returns true when a driver error is envelope-scoped and safe to drop during cached import.
fn should_drop_cached_driver_error(err: &driver::DriverError) -> bool {
    match err {
        driver::DriverError::EngineSyncing(_) |
        driver::DriverError::EngineInvalidPayload(_) |
        driver::DriverError::BlockNotFound(_) => true,
        driver::DriverError::PreconfInjectionFailed { source, .. } => matches!(
            source,
            driver::sync::error::EngineSubmissionError::EngineSyncing(_) |
                driver::sync::error::EngineSubmissionError::InvalidBlock(_, _) |
                driver::sync::error::EngineSubmissionError::MissingPayloadId |
                driver::sync::error::EngineSubmissionError::MissingParent |
                driver::sync::error::EngineSubmissionError::MissingInsertedBlock(_)
        ),
        _ => false,
    }
}

/// Ensure unsafe payload envelopes carry an embedded signature for response-topic compatibility.
fn normalize_unsafe_payload_envelope(
    mut envelope: WhitelistExecutionPayloadEnvelope,
    wire_signature: [u8; 65],
) -> WhitelistExecutionPayloadEnvelope {
    if envelope.signature.is_none() {
        envelope.signature = Some(wire_signature);
    }
    envelope
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use alloy_primitives::{Address, Bloom, Bytes, U256};
    use alloy_rpc_types_engine::ExecutionPayloadV1;

    use super::*;

    fn sample_execution_payload_with_transactions(
        transactions: Vec<Bytes>,
    ) -> WhitelistExecutionPayloadEnvelope {
        WhitelistExecutionPayloadEnvelope {
            end_of_sequencing: None,
            is_forced_inclusion: None,
            parent_beacon_block_root: None,
            execution_payload: ExecutionPayloadV1 {
                parent_hash: B256::from([0x10u8; 32]),
                fee_recipient: Address::from([0x11u8; 20]),
                state_root: B256::from([0x12u8; 32]),
                receipts_root: B256::from([0x13u8; 32]),
                logs_bloom: Bloom::default(),
                prev_randao: B256::from([0x14u8; 32]),
                block_number: 42,
                gas_limit: 30_000_000,
                gas_used: 21_000,
                timestamp: 1_735_000_000,
                extra_data: Bytes::from(vec![0x55u8; 8]),
                base_fee_per_gas: U256::from(1_000_000_000u64),
                block_hash: B256::from([0x15u8; 32]),
                transactions,
            },
            signature: Some([0x22u8; 65]),
        }
    }

    fn sample_unsigned_execution_payload_with_transactions(
        transactions: Vec<Bytes>,
    ) -> WhitelistExecutionPayloadEnvelope {
        let mut envelope = sample_execution_payload_with_transactions(transactions);
        envelope.signature = None;
        envelope
    }

    fn compress(data: &[u8]) -> Bytes {
        let mut encoder =
            flate2::write::ZlibEncoder::new(Vec::new(), flate2::Compression::default());
        std::io::Write::write_all(&mut encoder, data).expect("zlib write");
        Bytes::from(encoder.finish().expect("zlib finish"))
    }

    #[test]
    fn drops_cached_import_errors_for_invalid_payload() {
        let err = WhitelistPreconfirmationDriverError::InvalidPayload("bad payload".to_string());
        assert!(should_drop_cached_import_error(&err));
    }

    #[test]
    fn drops_cached_import_errors_for_invalid_signature() {
        let err =
            WhitelistPreconfirmationDriverError::InvalidSignature("bad signature".to_string());
        assert!(should_drop_cached_import_error(&err));
    }

    #[test]
    fn drops_cached_import_errors_for_engine_syncing_driver_error() {
        let err =
            WhitelistPreconfirmationDriverError::Driver(driver::DriverError::EngineSyncing(42));
        assert!(should_drop_cached_import_error(&err));
    }

    #[test]
    fn drops_cached_import_errors_for_invalid_block_driver_error() {
        let err = WhitelistPreconfirmationDriverError::Driver(
            driver::DriverError::PreconfInjectionFailed {
                block_number: 42,
                source: driver::sync::error::EngineSubmissionError::InvalidBlock(
                    42,
                    "invalid payload".to_string(),
                ),
            },
        );
        assert!(should_drop_cached_import_error(&err));
    }

    #[test]
    fn propagates_cached_import_errors_for_non_payload_failures() {
        let err = WhitelistPreconfirmationDriverError::MissingInsertedBlock(42);
        assert!(!should_drop_cached_import_error(&err));
    }

    #[test]
    fn propagates_cached_import_errors_for_driver_queue_timeouts() {
        let err = WhitelistPreconfirmationDriverError::Driver(
            driver::DriverError::PreconfEnqueueTimeout { waited: Duration::from_secs(1) },
        );
        assert!(!should_drop_cached_import_error(&err));
    }

    #[test]
    fn validate_payload_rejects_missing_transactions_list() {
        let envelope = sample_execution_payload_with_transactions(Vec::new());

        let err = validate_execution_payload_for_preconf(&envelope.execution_payload)
            .expect_err("payload without tx list must be rejected");
        assert!(matches!(
            err,
            WhitelistPreconfirmationDriverError::InvalidPayload(msg)
                if msg.contains("only one transaction list is allowed")
        ));
    }

    #[test]
    fn validate_payload_rejects_multiple_transactions_lists() {
        let envelope =
            sample_execution_payload_with_transactions(vec![compress(b"a"), compress(b"b")]);

        let err = validate_execution_payload_for_preconf(&envelope.execution_payload)
            .expect_err("payload with more than one tx list must be rejected");
        assert!(matches!(
            err,
            WhitelistPreconfirmationDriverError::InvalidPayload(msg)
                if msg.contains("only one transaction list is allowed")
        ));
    }

    #[test]
    fn validate_payload_rejects_oversized_compressed_transactions_list() {
        let oversized = Bytes::from(vec![0u8; MAX_COMPRESSED_TX_LIST_BYTES + 1]);
        let envelope = sample_execution_payload_with_transactions(vec![oversized]);

        let err = validate_execution_payload_for_preconf(&envelope.execution_payload)
            .expect_err("oversized compressed tx list must be rejected");
        assert!(matches!(
            err,
            WhitelistPreconfirmationDriverError::InvalidPayload(msg)
                if msg.contains("compressed transactions size exceeds")
        ));
    }

    #[test]
    fn validate_payload_accepts_single_transactions_list_within_size_limit() {
        let envelope = sample_execution_payload_with_transactions(vec![compress(b"valid")]);
        validate_execution_payload_for_preconf(&envelope.execution_payload)
            .expect("single tx list in range should be accepted");
    }

    #[test]
    fn normalizes_unsafe_payload_envelope_adds_missing_signature() {
        let wire_signature = [0xabu8; 65];
        let envelope =
            sample_unsigned_execution_payload_with_transactions(vec![compress(b"valid")]);
        let normalized = normalize_unsafe_payload_envelope(envelope, wire_signature);

        assert_eq!(normalized.signature, Some(wire_signature));
    }

    #[test]
    fn normalizes_unsafe_payload_envelope_keeps_existing_signature() {
        let embedded = [0x11u8; 65];
        let wire_signature = [0xabu8; 65];
        let mut envelope = sample_execution_payload_with_transactions(vec![compress(b"valid")]);
        envelope.signature = Some(embedded);
        let normalized = normalize_unsafe_payload_envelope(envelope, wire_signature);

        assert_eq!(normalized.signature, Some(embedded));
    }
}
