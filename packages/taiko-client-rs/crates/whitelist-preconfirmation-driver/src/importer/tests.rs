use std::time::Duration;

use alethia_reth_consensus::validation::ANCHOR_V4_SELECTOR;
use alloy_consensus::{
    EthereumTypedTransaction, TxEip1559, TxEnvelope, transaction::SignableTransaction,
};
use alloy_eips::{Encodable2718, eip2930::AccessList};
use alloy_primitives::{Address, B256, Bytes, U256};
use protocol::{FixedKSigner, codec::ZlibTxListCodec};

use crate::{
    codec::{MAX_COMPRESSED_TX_LIST_BYTES, WhitelistExecutionPayloadEnvelope},
    error::WhitelistPreconfirmationDriverError,
    test_support::{
        compress, sample_envelope_with_transactions as sample_execution_payload_with_transactions,
    },
};

use super::{
    cache_import::{CachedImportDisposition, classify_cached_import_error},
    ingress::is_stale_at_confirmed_tip,
    should_enable_preconf_imports,
    validation::{normalize_unsafe_payload_envelope, validate_execution_payload_for_preconf},
};

const TEST_CHAIN_ID: u64 = 167;
const NON_GOLDEN_SIGNER_PRIVATE_KEY: &str =
    "0x0000000000000000000000000000000000000000000000000000000000000001";

#[test]
fn stale_envelope_requires_written_confirmed_tip() {
    assert!(!is_stale_at_confirmed_tip(1, None));
    assert!(is_stale_at_confirmed_tip(7, Some(7)));
    assert!(is_stale_at_confirmed_tip(6, Some(7)));
    assert!(!is_stale_at_confirmed_tip(8, Some(7)));
}

fn sample_unsigned_execution_payload_with_transactions(
    transactions: Vec<Bytes>,
) -> WhitelistExecutionPayloadEnvelope {
    let mut envelope = sample_execution_payload_with_transactions(transactions);
    envelope.signature = None;
    envelope
}

fn sample_anchor_address() -> Address {
    Address::from([0x77u8; 20])
}

fn encode_compressed_tx_list(transactions: Vec<Vec<u8>>) -> Bytes {
    Bytes::from(
        ZlibTxListCodec::new(MAX_COMPRESSED_TX_LIST_BYTES)
            .encode(&transactions)
            .expect("encode compressed tx list"),
    )
}

fn signed_anchor_tx_bytes(
    signer: &FixedKSigner,
    chain_id: u64,
    anchor_address: Address,
    selector: [u8; 4],
) -> Vec<u8> {
    let tx = TxEip1559 {
        chain_id,
        nonce: 0,
        max_fee_per_gas: 1_000_000_000,
        max_priority_fee_per_gas: 0,
        gas_limit: 210_000,
        to: alloy_primitives::TxKind::Call(anchor_address),
        value: U256::ZERO,
        access_list: AccessList::default(),
        input: Bytes::from(selector.to_vec()),
    };

    let sighash = tx.signature_hash();
    let mut hash_bytes = [0u8; 32];
    hash_bytes.copy_from_slice(sighash.as_slice());
    let signature =
        signer.sign_with_predefined_k(&hash_bytes).expect("sign anchor transaction bytes");

    let envelope =
        TxEnvelope::new_unhashed(EthereumTypedTransaction::Eip1559(tx), signature.signature);
    envelope.encoded_2718().to_vec()
}

fn valid_anchor_tx_list(anchor_address: Address) -> Bytes {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let tx_bytes =
        signed_anchor_tx_bytes(&signer, TEST_CHAIN_ID, anchor_address, *ANCHOR_V4_SELECTOR);
    encode_compressed_tx_list(vec![tx_bytes])
}

#[test]
fn drops_cached_import_errors_for_invalid_payload() {
    let err = WhitelistPreconfirmationDriverError::InvalidPayload("bad payload".to_string());
    assert_eq!(classify_cached_import_error(&err), CachedImportDisposition::Drop);
}

#[test]
fn drops_cached_import_errors_for_invalid_signature() {
    let err = WhitelistPreconfirmationDriverError::InvalidSignature("bad signature".to_string());
    assert_eq!(classify_cached_import_error(&err), CachedImportDisposition::Drop);
}

#[test]
fn defers_cached_import_errors_for_engine_syncing_driver_error() {
    let err = WhitelistPreconfirmationDriverError::Driver(driver::DriverError::EngineSyncing(42));
    assert_eq!(classify_cached_import_error(&err), CachedImportDisposition::Defer);
}

#[test]
fn defers_cached_import_errors_for_parent_mismatch() {
    let err =
        WhitelistPreconfirmationDriverError::Driver(driver::DriverError::PreconfParentMismatch {
            block_number: 42,
            expected: B256::from([0x11; 32]),
            actual: B256::from([0x22; 32]),
        });
    assert_eq!(classify_cached_import_error(&err), CachedImportDisposition::Defer);
}

#[test]
fn drops_cached_import_errors_for_invalid_block_driver_error() {
    let err =
        WhitelistPreconfirmationDriverError::Driver(driver::DriverError::PreconfInjectionFailed {
            block_number: 42,
            source: driver::sync::error::EngineSubmissionError::InvalidBlock(
                42,
                "invalid payload".to_string(),
            ),
        });
    assert_eq!(classify_cached_import_error(&err), CachedImportDisposition::Drop);
}

#[test]
fn defers_cached_import_errors_for_missing_payload_id_driver_error() {
    let err =
        WhitelistPreconfirmationDriverError::Driver(driver::DriverError::PreconfInjectionFailed {
            block_number: 42,
            source: driver::sync::error::EngineSubmissionError::MissingPayloadId,
        });
    assert_eq!(classify_cached_import_error(&err), CachedImportDisposition::Defer);
}

#[test]
fn propagates_cached_import_errors_for_non_payload_failures() {
    let err = WhitelistPreconfirmationDriverError::MissingInsertedBlock(42);
    assert_eq!(classify_cached_import_error(&err), CachedImportDisposition::Propagate);
}

#[test]
fn defers_cached_import_errors_for_preconf_enqueue_timeout() {
    let err =
        WhitelistPreconfirmationDriverError::Driver(driver::DriverError::PreconfEnqueueTimeout {
            waited: Duration::from_secs(1),
        });
    assert_eq!(classify_cached_import_error(&err), CachedImportDisposition::Defer);
}

#[test]
fn defers_cached_import_errors_for_preconf_response_timeout() {
    let err =
        WhitelistPreconfirmationDriverError::Driver(driver::DriverError::PreconfResponseTimeout {
            waited: Duration::from_secs(12),
        });
    assert_eq!(classify_cached_import_error(&err), CachedImportDisposition::Defer);
}

#[test]
fn validate_payload_rejects_missing_transactions_list() {
    let envelope = sample_execution_payload_with_transactions(Vec::new());
    let anchor_address = sample_anchor_address();

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("payload without tx list must be rejected");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("only one transaction list is allowed")
    ));
}

#[test]
fn validate_payload_rejects_multiple_transactions_lists() {
    let envelope = sample_execution_payload_with_transactions(vec![compress(b"a"), compress(b"b")]);
    let anchor_address = sample_anchor_address();

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        TEST_CHAIN_ID,
        anchor_address,
    )
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
    let anchor_address = sample_anchor_address();

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("oversized compressed tx list must be rejected");
    // Assert on this crate's own wrapper context (validation.rs), not the
    // protocol codec's inner message, so protocol rewording can't break us.
    assert!(
        matches!(
            &err,
            WhitelistPreconfirmationDriverError::InvalidPayload(msg)
                if msg.contains("invalid transactions list bytes")
        ),
        "unexpected error shape: {err}"
    );
}

#[test]
fn validate_payload_accepts_single_transactions_list_within_size_limit() {
    let anchor_address = sample_anchor_address();
    let envelope =
        sample_execution_payload_with_transactions(vec![valid_anchor_tx_list(anchor_address)]);

    validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect("single tx list in range should be accepted");
}

#[test]
fn validate_payload_rejects_zero_timestamp() {
    let anchor_address = sample_anchor_address();
    let mut envelope =
        sample_execution_payload_with_transactions(vec![valid_anchor_tx_list(anchor_address)]);
    envelope.execution_payload.timestamp = 0;

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("zero timestamp payload must be rejected");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("non-zero timestamp is required")
    ));
}

#[test]
fn validate_payload_rejects_zero_fee_recipient() {
    let anchor_address = sample_anchor_address();
    let mut envelope =
        sample_execution_payload_with_transactions(vec![valid_anchor_tx_list(anchor_address)]);
    envelope.execution_payload.fee_recipient = Address::ZERO;

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("zero fee recipient payload must be rejected");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("empty L2 fee recipient")
    ));
}

#[test]
fn validate_payload_rejects_zero_gas_limit() {
    let anchor_address = sample_anchor_address();
    let mut envelope =
        sample_execution_payload_with_transactions(vec![valid_anchor_tx_list(anchor_address)]);
    envelope.execution_payload.gas_limit = 0;

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("zero gas limit payload must be rejected");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("non-zero gas limit is required")
    ));
}

#[test]
fn validate_payload_rejects_zero_base_fee() {
    let anchor_address = sample_anchor_address();
    let mut envelope =
        sample_execution_payload_with_transactions(vec![valid_anchor_tx_list(anchor_address)]);
    envelope.execution_payload.base_fee_per_gas = U256::ZERO;

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("zero base fee payload must be rejected");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("non-zero base fee per gas is required")
    ));
}

#[test]
fn validate_payload_rejects_empty_extra_data() {
    let anchor_address = sample_anchor_address();
    let mut envelope =
        sample_execution_payload_with_transactions(vec![valid_anchor_tx_list(anchor_address)]);
    envelope.execution_payload.extra_data = Bytes::new();

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("empty extra data payload must be rejected");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("empty extra data")
    ));
}

#[test]
fn validate_payload_rejects_invalid_zlib_transactions_bytes() {
    let anchor_address = sample_anchor_address();
    let envelope =
        sample_execution_payload_with_transactions(vec![Bytes::from_static(b"not-zlib-data")]);

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("invalid zlib bytes must be rejected");
    // Owned by this crate (validation.rs) — survives protocol codec rewording.
    assert!(
        matches!(
            &err,
            WhitelistPreconfirmationDriverError::InvalidPayload(msg)
                if msg.contains("invalid transactions list bytes")
        ),
        "unexpected error shape: {err}"
    );
}

#[test]
fn validate_payload_rejects_invalid_rlp_transactions_bytes() {
    let anchor_address = sample_anchor_address();
    let envelope = sample_execution_payload_with_transactions(vec![compress(b"not-rlp")]);

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("invalid RLP bytes must be rejected");
    // `compress(b"not-rlp")` fails RLP-list decode INSIDE the protocol codec, so
    // the crate wrapper here is the tx-list one (validation.rs), not the
    // per-transaction `decode_2718` wrapper. Assert on our own prefix regardless.
    assert!(
        matches!(
            &err,
            WhitelistPreconfirmationDriverError::InvalidPayload(msg)
                if msg.contains("invalid transactions list bytes")
        ),
        "unexpected error shape: {err}"
    );
}

#[test]
fn validate_payload_rejects_oversized_decompressed_transactions_bytes() {
    let anchor_address = sample_anchor_address();
    let oversized_decompressed = vec![0u8; 8 * 1024 * 1024 + 1];
    let envelope =
        sample_execution_payload_with_transactions(vec![compress(&oversized_decompressed)]);

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("oversized decompressed tx list must be rejected");
    // Owned by this crate (validation.rs) — survives protocol codec rewording.
    assert!(
        matches!(
            &err,
            WhitelistPreconfirmationDriverError::InvalidPayload(msg)
                if msg.contains("invalid transactions list bytes")
        ),
        "unexpected error shape: {err}"
    );
}

#[test]
fn validate_payload_rejects_empty_decoded_transactions_list() {
    let anchor_address = sample_anchor_address();
    let envelope =
        sample_execution_payload_with_transactions(vec![encode_compressed_tx_list(vec![])]);

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("empty decoded tx list must be rejected");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("empty transactions list, missing anchor transaction")
    ));
}

#[test]
fn validate_payload_rejects_anchor_with_wrong_recipient() {
    let anchor_address = sample_anchor_address();
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let wrong_recipient = Address::from([0x99u8; 20]);
    let tx_bytes =
        signed_anchor_tx_bytes(&signer, TEST_CHAIN_ID, wrong_recipient, *ANCHOR_V4_SELECTOR);
    let envelope =
        sample_execution_payload_with_transactions(vec![encode_compressed_tx_list(vec![tx_bytes])]);

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("wrong anchor recipient must be rejected");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("invalid anchor transaction recipient")
    ));
}

#[test]
fn validate_payload_rejects_anchor_with_wrong_sender() {
    let anchor_address = sample_anchor_address();
    let signer = FixedKSigner::new(NON_GOLDEN_SIGNER_PRIVATE_KEY).expect("non-golden signer key");
    let tx_bytes =
        signed_anchor_tx_bytes(&signer, TEST_CHAIN_ID, anchor_address, *ANCHOR_V4_SELECTOR);
    let envelope =
        sample_execution_payload_with_transactions(vec![encode_compressed_tx_list(vec![tx_bytes])]);

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("wrong anchor sender must be rejected");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("invalid anchor transaction sender")
    ));
}

#[test]
fn validate_payload_rejects_anchor_with_wrong_method() {
    let anchor_address = sample_anchor_address();
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let tx_bytes = signed_anchor_tx_bytes(&signer, TEST_CHAIN_ID, anchor_address, [1, 2, 3, 4]);
    let envelope =
        sample_execution_payload_with_transactions(vec![encode_compressed_tx_list(vec![tx_bytes])]);

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("wrong anchor method must be rejected");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("invalid anchor transaction method")
    ));
}

#[test]
fn normalizes_unsafe_payload_envelope_adds_missing_signature() {
    let wire_signature = [0xabu8; 65];
    let envelope = sample_unsigned_execution_payload_with_transactions(vec![compress(b"valid")]);
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

#[test]
fn should_enable_preconf_imports_when_head_origin_written() {
    assert!(should_enable_preconf_imports(true, None));
}

#[test]
fn should_enable_preconf_imports_at_genesis_before_first_proposal() {
    assert!(should_enable_preconf_imports(false, Some(1)));
}

#[test]
fn should_not_enable_preconf_imports_when_proposals_exist_without_origin() {
    assert!(!should_enable_preconf_imports(false, Some(2)));
}

#[test]
fn should_not_enable_preconf_imports_when_next_proposal_id_unknown() {
    assert!(!should_enable_preconf_imports(false, None));
}

/// Docker-backed drain tests exercising [`WhitelistPreconfirmationImporter`] against a
/// live L1/L2 harness. Skipped (returning green) when the harness env is absent, so the
/// module still compiles and runs on developer machines without Docker; CI runs it for
/// real via `just test`. Serialized into the `l1-shared` nextest group by the
/// `test(docker_)` override in `nextest.toml`.
mod drain_tests {
    use std::{sync::Arc, time::Duration};

    use alloy_eips::BlockNumberOrTag;
    use alloy_primitives::{Address, B256, Bytes, U256};
    use alloy_provider::Provider;
    use alloy_rpc_types_engine::ExecutionPayloadV1;
    use protocol::shasta::calculate_shasta_mix_hash;
    use rpc::{beacon::BeaconClient, client::Client};
    use tokio::sync::mpsc;

    // `SyncStage` provides `EventSyncer::run`, spawned in the background as in the e2e setup.
    use driver::{
        DriverConfig,
        sync::{SyncStage, event::EventSyncer},
    };
    use test_harness::{
        BeaconStubServer,
        blocks::wait_for_block,
        shasta::ShastaEnv,
        transactions::{build_anchor_tx_bytes, compute_next_block_base_fee},
    };

    use super::{ANCHOR_V4_SELECTOR, encode_compressed_tx_list, signed_anchor_tx_bytes};
    use crate::{
        cache::SharedPreconfState,
        codec::WhitelistExecutionPayloadEnvelope,
        importer::{WhitelistPreconfirmationImporter, WhitelistPreconfirmationImporterParams},
        network::NetworkCommand,
    };

    /// The concrete client type produced by [`Client::new`] (main dropped the `Client<P>`
    /// provider generic), i.e. the harness `RpcClient`.
    type DriverClient = Client;

    /// Fields, other than the tx list and block number/parent chain, needed to make a
    /// preconf envelope the drain will submit to the engine as a valid block. Sourced from
    /// the parent block exactly as `preconf_ingress_e2e.rs::build_preconf_attrs` does, so an
    /// envelope built this way maps (through `payload::build_driver_payload`) to attributes
    /// byte-identical to that passing e2e smoke path.
    struct BlockTemplate {
        /// L2 suggested fee recipient (block beneficiary).
        fee_recipient: Address,
        /// Block gas limit, carried over from the parent.
        gas_limit: u64,
        /// EIP-4396 base fee for the next block.
        base_fee: u64,
        /// Header extra data, carried over from the parent.
        extra_data: Bytes,
    }

    /// Build a cache-ready preconf envelope for `block_number` chained onto `parent_hash`.
    ///
    /// `raw_txs` are the RAW (uncompressed) transaction bytes; the envelope carries them
    /// zlib-compressed in `transactions[0]`, the shape the drain's `build_driver_payload`
    /// decompresses. `block_hash` is only ever used as the cache key (the engine recomputes
    /// the real hash from the attributes), so it doubles as the child's `parent_hash` when
    /// chaining. `prev_randao` must be the correct Shasta mix hash for the one envelope that
    /// actually imports (A); the deferred envelopes never reach the engine, so any value is
    /// fine. `header_difficulty`/`signature`/`is_forced_inclusion` mirror the local-build
    /// defaults; the drain path never reads `header_difficulty`.
    #[allow(clippy::too_many_arguments)]
    fn build_cache_envelope(
        block_number: u64,
        parent_hash: B256,
        block_hash: B256,
        timestamp: u64,
        prev_randao: B256,
        template: &BlockTemplate,
        raw_txs: &[Bytes],
    ) -> WhitelistExecutionPayloadEnvelope {
        let compressed = encode_compressed_tx_list(raw_txs.iter().map(|tx| tx.to_vec()).collect());
        WhitelistExecutionPayloadEnvelope {
            end_of_sequencing: None,
            is_forced_inclusion: None,
            parent_beacon_block_root: None,
            header_difficulty: None,
            execution_payload: ExecutionPayloadV1 {
                parent_hash,
                fee_recipient: template.fee_recipient,
                state_root: B256::ZERO,
                receipts_root: B256::ZERO,
                logs_bloom: Default::default(),
                prev_randao,
                block_number,
                gas_limit: template.gas_limit,
                gas_used: 0,
                timestamp,
                extra_data: template.extra_data.clone(),
                base_fee_per_gas: U256::from(template.base_fee),
                block_hash,
                transactions: vec![compressed],
            },
            signature: Some([0u8; 65]),
        }
    }

    /// Shasta mix hash for a block, derived from the parent header difficulty exactly as the
    /// local-build path does (`payload_build.rs::derive_prev_randao`).
    fn shasta_prev_randao(parent_difficulty: U256, block_number: u64) -> B256 {
        calculate_shasta_mix_hash(B256::from(parent_difficulty.to_be_bytes::<32>()), block_number)
    }

    /// Spin up an `EventSyncer` (preconf ingress enabled) against L2 node 0, mirroring the
    /// setup block in `crates/driver/tests/preconf_ingress_e2e.rs`.
    async fn start_event_syncer(
        env: &ShastaEnv,
        beacon_stub: &BeaconStubServer,
    ) -> (Arc<EventSyncer>, DriverClient, tokio::task::JoinHandle<()>) {
        let driver_config = DriverConfig::new(
            env.client_config.clone(),
            Duration::from_millis(50),
            beacon_stub.endpoint().clone(),
            None,
            None,
            true,
        );
        let driver_client = Client::new(driver_config.client.clone()).await.expect("driver client");
        let event_syncer = Arc::new(
            EventSyncer::new(&driver_config, driver_client.clone()).await.expect("syncer"),
        );
        let handle = {
            let syncer = event_syncer.clone();
            tokio::spawn(async move {
                if let Err(err) = syncer.run().await {
                    tracing::warn!(?err, "event syncer exited");
                }
            })
        };
        event_syncer.wait_preconf_ingress_ready().await.expect("ingress ready");
        (event_syncer, driver_client, handle)
    }

    /// Construct an importer wired to the given syncer/client and a fresh command channel,
    /// mirroring `runner.rs`'s production wiring. `state` is seeded with the current L2 head
    /// (`seed_highest_unsafe`) as the runner does.
    async fn build_importer(
        event_syncer: Arc<EventSyncer>,
        driver_client: DriverClient,
        beacon_stub: &BeaconStubServer,
        chain_id: u64,
        seed_highest_unsafe: u64,
    ) -> (WhitelistPreconfirmationImporter, mpsc::Receiver<NetworkCommand>) {
        let beacon_client =
            Arc::new(BeaconClient::new(beacon_stub.endpoint().clone()).await.expect("beacon"));
        let (command_tx, command_rx) = mpsc::channel(16);
        let importer =
            WhitelistPreconfirmationImporter::new(WhitelistPreconfirmationImporterParams {
                event_syncer,
                rpc: driver_client,
                chain_id,
                network_command_tx: command_tx,
                state: SharedPreconfState::new(seed_highest_unsafe),
                beacon_client,
            });
        (importer, command_rx)
    }

    /// One invalid envelope in a cached sequence must be dropped without freezing the drain:
    /// the valid parent imports, the invalid one is removed, and the now-orphaned child stays
    /// deferred (and triggers a parent request). This is the "one bad payload must not freeze
    /// the head" invariant from the 2026-06/07 mainnet incident.
    ///
    /// # Real branch mapping (see `importer/cache_import.rs`)
    /// The drain (`try_import_cached`) does NOT re-run anchor validation — that happens only
    /// at gossip ingress. During drain an envelope with a corrupt anchor is submitted to the
    /// engine, which returns `INVALID` → `EngineSubmissionError::InvalidBlock` →
    /// `DriverError::PreconfInjectionFailed{InvalidBlock}` → `should_drop_cached_import_error`
    /// is true → the DROP branch (`cache.remove`, `progressed = true`). The orphaned child hits
    /// the missing-parent branch (`Ok(false)`), publishing one `PublishUnsafeRequest`.
    ///
    /// Because the engine — not the envelope — decides the resulting block hash, the child's
    /// `parent_hash` can only be A's REAL post-import hash, which is unknowable before A lands.
    /// So the drain is driven in two phases (A alone, then B+C) rather than the single call in
    /// the brief sketch; the A/B/C three-envelope structure and the `head == parent + 1`
    /// assertion are preserved.
    #[tokio::test]
    async fn docker_drain_drops_invalid_and_continues() {
        if std::env::var("HARNESS_L1_HTTP").is_err() {
            eprintln!("skipping: docker harness env not present (run via `just test`)");
            return;
        }

        let env = ShastaEnv::load_from_env().await.expect("env");
        let beacon_stub = BeaconStubServer::start().await.expect("beacon stub");
        let chain_id = env.client.l2_provider.get_chain_id().await.expect("chain id");

        let parent_number = env.client.l2_provider.get_block_number().await.expect("head number");
        let parent = env
            .client
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(parent_number))
            .await
            .expect("head block")
            .expect("head present");
        let parent_hash = parent.header.hash;

        let (event_syncer, driver_client, syncer_handle) =
            start_event_syncer(&env, &beacon_stub).await;
        let (mut importer, mut command_rx) =
            build_importer(event_syncer, driver_client, &beacon_stub, chain_id, parent_number)
                .await;

        // Per-block header fields, taken from the parent (as build_preconf_attrs does).
        let base_fee = compute_next_block_base_fee(&env.client.l2_provider, parent.header.number)
            .await
            .expect("base fee");
        let template = BlockTemplate {
            fee_recipient: env.l2_suggested_fee_recipient,
            gas_limit: parent.header.gas_limit,
            base_fee,
            extra_data: parent.header.extra_data.clone(),
        };
        // --- Envelope A: valid block at parent+1, anchored to the real head. ---
        let anchor_a = build_anchor_tx_bytes(&env.client, parent_hash, parent_number + 1, base_fee)
            .await
            .expect("anchor A");
        let envelope_a = build_cache_envelope(
            parent_number + 1,
            parent_hash,
            // Cache key for A; distinct sentinel so removal/retention is unambiguous.
            B256::repeat_byte(0xa1),
            parent.header.timestamp + 1,
            // A must actually import, so its mix hash has to be the real one.
            shasta_prev_randao(parent.header.difficulty, parent_number + 1),
            &template,
            &[anchor_a],
        );

        // Phase 1: import A alone. Its parent is the real head, so it submits and the engine
        // accepts it, advancing the head to parent+1.
        importer.cache.insert(Arc::new(envelope_a));
        importer.maybe_import_from_cache().await.expect("phase-1 drain must not return fatal");

        // Wait for A to materialize (as the e2e smoke test does) to avoid any WS-head lag,
        // then confirm it imported and was removed from the cache.
        let block_a =
            wait_for_block(&env.client.l2_provider, parent_number + 1, Duration::from_secs(30))
                .await
                .expect("A must materialize");
        assert_eq!(
            block_a.header.number,
            parent_number + 1,
            "valid head-of-line envelope must import"
        );
        assert!(importer.cache.is_empty(), "A must be removed from the cache after import");

        // A's REAL, engine-computed hash: the parent B must chain onto so the drain SUBMITS B
        // (and the engine can then reject it). This is the parent-matching rule from Step 1
        // (`block_hash_by_number(parent_number) == parent_hash`).
        let a_real_hash = block_a.header.hash;

        // --- Envelope B: block at parent+2 with a CORRUPT anchor (wrong selector), chained
        // onto A's real hash so it is submitted to the engine (which rejects it). ---
        let corrupt_anchor = signed_anchor_tx_bytes(
            &protocol::FixedKSigner::golden_touch().expect("golden touch"),
            chain_id,
            env.taiko_anchor_address,
            [0xde, 0xad, 0xbe, 0xef], // not ANCHOR_V4_SELECTOR
        );
        debug_assert_ne!([0xde, 0xad, 0xbe, 0xef], *ANCHOR_V4_SELECTOR);
        let b_cache_key = B256::repeat_byte(0xb2);
        let envelope_b = build_cache_envelope(
            parent_number + 2,
            a_real_hash,
            b_cache_key,
            parent.header.timestamp + 2,
            // B never lands as a valid block (its anchor is corrupt), so the mix hash is
            // irrelevant; the engine rejects it before hashing matters.
            shasta_prev_randao(parent.header.difficulty, parent_number + 2),
            &template,
            &[Bytes::from(corrupt_anchor)],
        );

        // --- Envelope C: valid-looking block at parent+3 whose parent is B's (never-created)
        // block. Its parent is missing, so the drain defers it and requests the parent. ---
        let anchor_c = build_anchor_tx_bytes(&env.client, b_cache_key, parent_number + 3, base_fee)
            .await
            .expect("anchor C");
        let c_cache_key = B256::repeat_byte(0xc3);
        let envelope_c = build_cache_envelope(
            parent_number + 3,
            b_cache_key, // C.parent == B's cache-key hash (the block that never lands)
            c_cache_key,
            parent.header.timestamp + 3,
            // C never reaches the engine (its parent is missing), so the mix hash is irrelevant.
            shasta_prev_randao(parent.header.difficulty, parent_number + 3),
            &template,
            &[anchor_c],
        );

        // Phase 2: drain B+C. B submits -> engine INVALID -> dropped; C's parent is missing ->
        // deferred + one parent request published.
        importer.cache.insert(Arc::new(envelope_b));
        importer.cache.insert(Arc::new(envelope_c));
        importer.maybe_import_from_cache().await.expect("phase-2 drain must not return fatal");

        // Head did NOT advance past A: B was rejected, C never imported.
        let head_after_bc =
            env.client.l2_provider.get_block_number().await.expect("head after B/C");
        assert_eq!(
            head_after_bc,
            parent_number + 1,
            "invalid B and orphaned C must not advance the head beyond A"
        );

        // B dropped from cache; C retained (deferred).
        assert!(
            importer.cache.get(&b_cache_key).is_none(),
            "invalid envelope B must be dropped from the cache"
        );
        assert!(
            importer.cache.get(&c_cache_key).is_some(),
            "orphaned child C must stay cached (deferred)"
        );

        // The deferred child published EXACTLY ONE parent request, for B's (missing)
        // block. Collect every request hash (not last-wins) so a duplicate or spurious
        // extra request would fail the assert rather than being masked by overwrite;
        // non-request commands are ignored as before.
        let mut requests: Vec<B256> = Vec::new();
        while let Ok(command) = command_rx.try_recv() {
            if let NetworkCommand::PublishUnsafeRequest { hash } = command {
                requests.push(hash);
            }
        }
        assert_eq!(requests, vec![b_cache_key], "exactly one parent request, for B's hash");

        syncer_handle.abort();
        beacon_stub.shutdown().await.expect("beacon shutdown");
        env.shutdown().await.expect("env shutdown");
    }
}
