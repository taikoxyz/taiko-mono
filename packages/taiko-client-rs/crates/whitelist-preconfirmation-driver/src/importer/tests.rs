use std::time::Duration;

use alethia_reth_consensus::validation::ANCHOR_V4_SELECTOR;
use alloy_consensus::{
    EthereumTypedTransaction, TxEip1559, TxEnvelope, transaction::SignableTransaction,
};
use alloy_eips::{Encodable2718, eip2930::AccessList};
use alloy_primitives::{Address, B256, Bloom, Bytes, U256};
use alloy_rpc_types_engine::ExecutionPayloadV1;
use alloy_signer::SignerSync;
use alloy_signer_local::PrivateKeySigner;
use protocol::{
    FixedKSigner,
    codec::ZlibTxListCodec,
    shasta::{constants::TAIKO_DEVNET_CHAIN_ID, encode_etna_extra_data},
};

use crate::{
    codec::{
        MAX_COMPRESSED_TX_LIST_BYTES, WhitelistExecutionPayloadEnvelope,
        decode_unsafe_response_message, decompress_tx_list, encode_envelope_ssz,
        encode_unsafe_response_message,
    },
    error::WhitelistPreconfirmationDriverError,
};

use super::{
    cache_import::{
        CachedImportDisposition, classify_cached_import_error, driver_payload_from_envelope,
    },
    ingress::{is_stale_at_confirmed_tip, response_envelope_from_l2_block},
    should_enable_preconf_imports,
    validation::{
        normalize_unsafe_payload_envelope, validate_envelope_for_import,
        validate_envelope_header_difficulty, validate_execution_payload_for_preconf,
    },
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

fn sample_execution_payload_with_transactions(
    transactions: Vec<Bytes>,
) -> WhitelistExecutionPayloadEnvelope {
    WhitelistExecutionPayloadEnvelope {
        end_of_sequencing: None,
        is_forced_inclusion: None,
        parent_beacon_block_root: None,
        header_difficulty: Some(U256::from(1_000_000u64)),
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
            timestamp: SAMPLE_TIMESTAMP,
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
    let mut encoder = flate2::write::ZlibEncoder::new(Vec::new(), flate2::Compression::default());
    std::io::Write::write_all(&mut encoder, data).expect("zlib write");
    Bytes::from(encoder.finish().expect("zlib finish"))
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

fn standard_signed_anchor_tx_bytes(
    signer: &PrivateKeySigner,
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

    let signature = signer.sign_hash_sync(&tx.signature_hash()).expect("sign anchor transaction");
    let envelope = TxEnvelope::new_unhashed(EthereumTypedTransaction::Eip1559(tx), signature);
    envelope.encoded_2718().to_vec()
}

fn valid_anchor_tx_list(anchor_address: Address) -> Bytes {
    valid_anchor_tx_list_for_chain(TEST_CHAIN_ID, anchor_address)
}

/// A compressed list holding one golden-touch anchor transaction signed for `chain_id`.
fn valid_anchor_tx_list_for_chain(chain_id: u64, anchor_address: Address) -> Bytes {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let tx_bytes = signed_anchor_tx_bytes(&signer, chain_id, anchor_address, *ANCHOR_V4_SELECTOR);
    encode_compressed_tx_list(vec![tx_bytes])
}

#[test]
fn drops_cached_import_errors_for_engine_fork_guard_errors() {
    use driver::sync::error::EngineSubmissionError;

    let sources = [
        EngineSubmissionError::EtnaTargetWithoutBeaconRoot {
            block_number: 42,
            timestamp: SAMPLE_TIMESTAMP,
        },
        EngineSubmissionError::PreEtnaTargetWithBeaconRoot {
            block_number: 42,
            timestamp: SAMPLE_TIMESTAMP,
            root: SAMPLE_ETNA_ROOT,
        },
        EngineSubmissionError::PreUnzenTarget {
            block_number: 42,
            timestamp: SAMPLE_TIMESTAMP,
            chain_id: TAIKO_DEVNET_CHAIN_ID,
        },
    ];
    for source in sources {
        let label = source.to_string();
        let err = WhitelistPreconfirmationDriverError::Driver(
            driver::DriverError::PreconfInjectionFailed { block_number: 42, source },
        );
        assert_eq!(classify_cached_import_error(&err), CachedImportDisposition::Drop, "{label}");
    }
}

/// An Etna schedule the node cannot resolve is a fault of its own configuration, not of the
/// envelope, so it aborts the drain loop instead of dropping the envelope.
#[test]
fn propagates_cached_import_errors_for_an_unresolved_etna_schedule() {
    let err =
        WhitelistPreconfirmationDriverError::Driver(driver::DriverError::PreconfInjectionFailed {
            block_number: 42,
            source: driver::sync::error::EngineSubmissionError::EtnaScheduleUnresolved {
                chain_id: 0,
                source: protocol::shasta::error::ForkConfigError::UnsupportedChainId(0),
            },
        });
    assert_eq!(classify_cached_import_error(&err), CachedImportDisposition::Propagate);
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
        None,
        None,
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
        None,
        None,
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
        None,
        None,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("oversized compressed tx list must be rejected");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("compressed txlist exceeds max size")
    ));
}

#[test]
fn validate_payload_accepts_single_transactions_list_within_size_limit() {
    let anchor_address = sample_anchor_address();
    let envelope =
        sample_execution_payload_with_transactions(vec![valid_anchor_tx_list(anchor_address)]);

    validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        None,
        None,
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
        None,
        None,
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
        None,
        None,
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
        None,
        None,
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
        None,
        None,
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
        None,
        None,
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
        None,
        None,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("invalid zlib bytes must be rejected");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("zlib decode failed")
    ));
}

#[test]
fn validate_payload_rejects_invalid_rlp_transactions_bytes() {
    let anchor_address = sample_anchor_address();
    let envelope = sample_execution_payload_with_transactions(vec![compress(b"not-rlp")]);

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        None,
        None,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("invalid RLP bytes must be rejected");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("rlp decode failed")
    ));
}

#[test]
fn validate_payload_rejects_oversized_decompressed_transactions_bytes() {
    let anchor_address = sample_anchor_address();
    let oversized_decompressed = vec![0u8; 8 * 1024 * 1024 + 1];
    let envelope =
        sample_execution_payload_with_transactions(vec![compress(&oversized_decompressed)]);

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        None,
        None,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("oversized decompressed tx list must be rejected");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("decompressed txlist exceeds max size")
    ));
}

#[test]
fn validate_payload_rejects_empty_decoded_transactions_list() {
    let anchor_address = sample_anchor_address();
    let envelope =
        sample_execution_payload_with_transactions(vec![encode_compressed_tx_list(vec![])]);

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        None,
        None,
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
        None,
        None,
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
    let signer =
        NON_GOLDEN_SIGNER_PRIVATE_KEY.parse::<PrivateKeySigner>().expect("non-golden signer key");
    let tx_bytes = standard_signed_anchor_tx_bytes(
        &signer,
        TEST_CHAIN_ID,
        anchor_address,
        *ANCHOR_V4_SELECTOR,
    );
    let envelope =
        sample_execution_payload_with_transactions(vec![encode_compressed_tx_list(vec![tx_bytes])]);

    let err = validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        None,
        None,
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
        None,
        None,
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

/// Timestamp of the sample payloads.
const SAMPLE_TIMESTAMP: u64 = 1_735_000_000;
/// Etna activation at the sample timestamp: the sample payloads are Etna blocks.
const ETNA_AT_SAMPLE: Option<u64> = Some(SAMPLE_TIMESTAMP);
/// Etna activation one second after the sample timestamp: the sample payloads are pre-Etna.
const ETNA_AFTER_SAMPLE: Option<u64> = Some(SAMPLE_TIMESTAMP + 1);
/// Nonzero Etna root (the L1 state root of the anchor block).
const SAMPLE_ETNA_ROOT: B256 = B256::repeat_byte(0x5a);

/// Build a well-formed Etna envelope: nonzero root, 13-byte `extraData`, the given tx lists.
fn sample_etna_envelope(transactions: Vec<Bytes>) -> WhitelistExecutionPayloadEnvelope {
    let mut envelope = sample_execution_payload_with_transactions(transactions);
    envelope.parent_beacon_block_root = Some(SAMPLE_ETNA_ROOT);
    envelope.execution_payload.extra_data =
        encode_etna_extra_data(0x32, 7, 1_234).expect("13-byte Etna extra data");
    envelope
}

/// Run the shared payload validation with the envelope's own root and the given Etna time.
fn validate_envelope_payload(
    envelope: &WhitelistExecutionPayloadEnvelope,
    etna_fork_timestamp: Option<u64>,
) -> crate::Result<()> {
    validate_execution_payload_for_preconf(
        &envelope.execution_payload,
        envelope.parent_beacon_block_root,
        etna_fork_timestamp,
        TEST_CHAIN_ID,
        sample_anchor_address(),
    )
}

/// Assert that `result` is an `InvalidPayload` error whose message contains `needle`.
fn assert_invalid_payload(result: crate::Result<()>, needle: &str) {
    let err = result.expect_err("payload must be rejected");
    assert!(
        matches!(&err, WhitelistPreconfirmationDriverError::InvalidPayload(msg) if msg.contains(needle)),
        "expected InvalidPayload containing {needle:?}, got {err:?}"
    );
}

/// A compressed list holding one ordinary signed transaction (not an anchor transaction).
fn ordinary_tx_list() -> Bytes {
    let signer =
        NON_GOLDEN_SIGNER_PRIVATE_KEY.parse::<PrivateKeySigner>().expect("non-golden signer key");
    let tx_bytes = standard_signed_anchor_tx_bytes(
        &signer,
        TEST_CHAIN_ID,
        Address::from([0x99u8; 20]),
        [0; 4],
    );
    encode_compressed_tx_list(vec![tx_bytes])
}

/// A P2P import hands the envelope's root to the driver: an Etna envelope's nonzero root as
/// is, an absent one (a zero root slot decodes to `None`) as the zero root.
#[test]
fn driver_payload_from_envelope_sends_the_envelope_root() {
    let etna = driver_payload_from_envelope(&sample_etna_envelope(vec![ordinary_tx_list()]))
        .expect("Etna envelope builds");
    assert_eq!(etna.payload_attributes.parent_beacon_block_root, Some(SAMPLE_ETNA_ROOT));

    let pre_etna = driver_payload_from_envelope(&sample_execution_payload_with_transactions(vec![
        valid_anchor_tx_list(sample_anchor_address()),
    ]))
    .expect("pre-Etna envelope builds");
    assert_eq!(pre_etna.payload_attributes.parent_beacon_block_root, Some(B256::ZERO));
}

#[test]
fn validate_payload_accepts_pre_etna_absent_or_zero_root() {
    let mut envelope = sample_execution_payload_with_transactions(vec![valid_anchor_tx_list(
        sample_anchor_address(),
    )]);
    for etna_fork_timestamp in [None, ETNA_AFTER_SAMPLE] {
        for root in [None, Some(B256::ZERO)] {
            envelope.parent_beacon_block_root = root;
            validate_envelope_payload(&envelope, etna_fork_timestamp)
                .expect("pre-Etna payload with an absent or zero root must be accepted");
        }
    }
}

#[test]
fn validate_payload_rejects_pre_etna_nonzero_root() {
    let mut envelope = sample_execution_payload_with_transactions(vec![valid_anchor_tx_list(
        sample_anchor_address(),
    )]);
    envelope.parent_beacon_block_root = Some(SAMPLE_ETNA_ROOT);
    for etna_fork_timestamp in [None, ETNA_AFTER_SAMPLE] {
        assert_invalid_payload(
            validate_envelope_payload(&envelope, etna_fork_timestamp),
            "pre-Etna payload at timestamp 1735000000 carries nonzero parent beacon block root",
        );
    }
}

#[test]
fn validate_payload_accepts_etna_nonzero_root_and_13_byte_extra_data() {
    let envelope = sample_etna_envelope(vec![ordinary_tx_list()]);
    validate_envelope_payload(&envelope, ETNA_AT_SAMPLE)
        .expect("Etna payload with a nonzero root and 13-byte extra data must be accepted");
}

#[test]
fn validate_payload_rejects_etna_missing_or_zero_root() {
    let mut envelope = sample_etna_envelope(vec![ordinary_tx_list()]);
    for root in [None, Some(B256::ZERO)] {
        envelope.parent_beacon_block_root = root;
        assert_invalid_payload(
            validate_envelope_payload(&envelope, ETNA_AT_SAMPLE),
            "Etna payload at timestamp 1735000000 requires a nonzero parent beacon block root",
        );
    }
}

#[test]
fn validate_payload_rejects_etna_extra_data_that_is_not_13_bytes() {
    let mut envelope = sample_etna_envelope(vec![ordinary_tx_list()]);
    for (len, expected) in [
        (7, "Etna extra data must be exactly 13 bytes, got 7"),
        (0, "Etna extra data must be exactly 13 bytes, got 0"),
        (14, "Etna extra data must be exactly 13 bytes, got 14"),
    ] {
        envelope.execution_payload.extra_data = Bytes::from(vec![0x32u8; len]);
        assert_invalid_payload(validate_envelope_payload(&envelope, ETNA_AT_SAMPLE), expected);
    }
}

#[test]
fn validate_payload_accepts_an_empty_etna_tx_list() {
    let empty_list = encode_compressed_tx_list(vec![]);
    // The build path decompresses the same bytes: the empty RLP list must survive it too.
    assert_eq!(decompress_tx_list(&empty_list).expect("decompress empty list"), vec![0xc0]);

    let envelope = sample_etna_envelope(vec![empty_list]);
    validate_envelope_payload(&envelope, ETNA_AT_SAMPLE)
        .expect("an empty Etna transaction list must be accepted");
}

#[test]
fn validate_payload_accepts_an_anchor_shaped_first_etna_tx_as_ordinary() {
    let envelope = sample_etna_envelope(vec![valid_anchor_tx_list(sample_anchor_address())]);
    validate_envelope_payload(&envelope, ETNA_AT_SAMPLE)
        .expect("an anchor-shaped first Etna transaction is an ordinary transaction");
}

#[test]
fn validate_payload_does_not_check_the_first_etna_tx() {
    let envelope = sample_etna_envelope(vec![ordinary_tx_list()]);
    validate_envelope_payload(&envelope, ETNA_AT_SAMPLE)
        .expect("an ordinary first Etna transaction must be accepted");

    // The same list is rejected before Etna, where tx[0] must be the anchor transaction.
    let mut pre_etna = sample_execution_payload_with_transactions(vec![ordinary_tx_list()]);
    pre_etna.parent_beacon_block_root = None;
    assert_invalid_payload(
        validate_envelope_payload(&pre_etna, ETNA_AFTER_SAMPLE),
        "invalid anchor transaction",
    );
}

#[test]
fn validate_payload_still_decodes_the_etna_tx_list() {
    let envelope = sample_etna_envelope(vec![compress(b"not-rlp")]);
    assert_invalid_payload(
        validate_envelope_payload(&envelope, ETNA_AT_SAMPLE),
        "rlp decode failed",
    );

    let envelope = sample_etna_envelope(vec![compress(b"a"), compress(b"b")]);
    assert_invalid_payload(
        validate_envelope_payload(&envelope, ETNA_AT_SAMPLE),
        "only one transaction list is allowed",
    );
}

/// Build a valid Unzen envelope for the devnet (Unzen from genesis): anchor tx at tx[0], a zero
/// root and a nonzero header difficulty.
fn devnet_unzen_envelope() -> WhitelistExecutionPayloadEnvelope {
    let mut envelope =
        sample_execution_payload_with_transactions(vec![valid_anchor_tx_list_for_chain(
            TAIKO_DEVNET_CHAIN_ID,
            sample_anchor_address(),
        )]);
    envelope.parent_beacon_block_root = None;
    envelope.header_difficulty = Some(U256::from(1_000_000u64));
    envelope
}

/// Run the whole P2P import validation for a devnet envelope with the given Etna time.
fn validate_devnet_import(
    envelope: &WhitelistExecutionPayloadEnvelope,
    etna_fork_timestamp: Option<u64>,
) -> crate::Result<()> {
    validate_envelope_for_import(
        envelope,
        TAIKO_DEVNET_CHAIN_ID,
        sample_anchor_address(),
        etna_fork_timestamp,
    )
}

#[test]
fn import_validation_accepts_a_valid_unzen_envelope() {
    for etna_fork_timestamp in [None, ETNA_AFTER_SAMPLE] {
        validate_devnet_import(&devnet_unzen_envelope(), etna_fork_timestamp)
            .expect("a valid Unzen envelope must be imported");
    }
}

#[test]
fn import_validation_drops_an_unzen_envelope_with_a_nonzero_root() {
    let mut envelope = devnet_unzen_envelope();
    envelope.parent_beacon_block_root = Some(SAMPLE_ETNA_ROOT);
    assert_invalid_payload(
        validate_devnet_import(&envelope, ETNA_AFTER_SAMPLE),
        "carries nonzero parent beacon block root",
    );
}

#[test]
fn import_validation_accepts_a_valid_etna_envelope_with_or_without_difficulty() {
    let mut envelope = sample_etna_envelope(vec![encode_compressed_tx_list(vec![])]);
    for header_difficulty in [None, Some(U256::from(21_000u64))] {
        envelope.header_difficulty = header_difficulty;
        validate_devnet_import(&envelope, ETNA_AT_SAMPLE)
            .expect("a valid Etna envelope must be imported");
    }
}

#[test]
fn import_validation_drops_an_etna_envelope_whose_root_slot_is_zero() {
    // A zero root slot decodes to `None` on the wire, which the import treats as zero.
    let mut envelope = sample_etna_envelope(vec![ordinary_tx_list()]);
    envelope.parent_beacon_block_root = Some(B256::ZERO);
    let decoded = crate::codec::decode_envelope_ssz(&encode_envelope_ssz(&envelope))
        .expect("decode envelope");
    assert_eq!(decoded.parent_beacon_block_root, None);

    assert_invalid_payload(
        validate_devnet_import(&decoded, ETNA_AT_SAMPLE),
        "requires a nonzero parent beacon block root",
    );
}

#[test]
fn header_difficulty_rule_requires_a_nonzero_difficulty_before_etna() {
    for etna_fork_timestamp in [None, ETNA_AFTER_SAMPLE] {
        for header_difficulty in [None, Some(U256::ZERO)] {
            assert_invalid_payload(
                validate_envelope_header_difficulty(
                    TAIKO_DEVNET_CHAIN_ID,
                    etna_fork_timestamp,
                    SAMPLE_TIMESTAMP,
                    header_difficulty,
                ),
                "envelope is missing header difficulty",
            );
        }
        validate_envelope_header_difficulty(
            TAIKO_DEVNET_CHAIN_ID,
            etna_fork_timestamp,
            SAMPLE_TIMESTAMP,
            Some(U256::from(21_000u64)),
        )
        .expect("an Unzen envelope with a nonzero difficulty must pass");
    }
}

#[test]
fn header_difficulty_rule_accepts_an_absent_or_present_difficulty_after_etna() {
    for header_difficulty in [None, Some(U256::ZERO), Some(U256::from(21_000u64))] {
        validate_envelope_header_difficulty(
            TAIKO_DEVNET_CHAIN_ID,
            ETNA_AT_SAMPLE,
            SAMPLE_TIMESTAMP,
            header_difficulty,
        )
        .expect("an Etna envelope may omit its difficulty (an empty block has none)");
    }
}

/// Build the header of an executed Etna block carrying `root`.
fn sample_l2_header(
    root: Option<B256>,
    difficulty: U256,
    extra_data: Bytes,
) -> alloy_rpc_types::Header {
    alloy_rpc_types::Header {
        hash: B256::repeat_byte(0x15),
        inner: alloy_consensus::Header {
            parent_hash: B256::repeat_byte(0x10),
            beneficiary: Address::repeat_byte(0x11),
            number: 42,
            gas_limit: 30_000_000,
            timestamp: SAMPLE_TIMESTAMP,
            extra_data,
            mix_hash: B256::repeat_byte(0x14),
            base_fee_per_gas: Some(1_000_000_000),
            difficulty,
            parent_beacon_block_root: root,
            ..Default::default()
        },
        ..Default::default()
    }
}

#[test]
fn response_envelope_carries_the_etna_header_root() {
    let extra_data = encode_etna_extra_data(0x32, 7, 1_234).expect("13-byte Etna extra data");
    let header = sample_l2_header(Some(SAMPLE_ETNA_ROOT), U256::ZERO, extra_data);

    let envelope = response_envelope_from_l2_block(
        &header,
        1_000_000_000,
        encode_compressed_tx_list(vec![]),
        None,
        false,
        [0x22u8; 65],
    );
    assert_eq!(envelope.parent_beacon_block_root, Some(SAMPLE_ETNA_ROOT));
    assert_eq!(envelope.header_difficulty, None, "an empty Etna block has difficulty 0");
    assert_eq!(envelope.execution_payload.block_hash, header.hash);

    // A peer decodes the same root from the response topic and imports the block.
    let decoded = decode_unsafe_response_message(
        &encode_unsafe_response_message(&envelope).expect("encode response"),
    )
    .expect("decode response");
    assert_eq!(decoded.parent_beacon_block_root, Some(SAMPLE_ETNA_ROOT));
    validate_devnet_import(&decoded, ETNA_AT_SAMPLE)
        .expect("the rebuilt Etna envelope must pass import validation");
}

#[test]
fn response_envelope_carries_a_zero_or_absent_pre_etna_root_as_none() {
    for root in [None, Some(B256::ZERO)] {
        let header = sample_l2_header(root, U256::from(21_000u64), Bytes::from(vec![0x32u8; 7]));
        let envelope = response_envelope_from_l2_block(
            &header,
            1_000_000_000,
            encode_compressed_tx_list(vec![]),
            Some(true),
            true,
            [0x22u8; 65],
        );
        assert_eq!(envelope.parent_beacon_block_root, None, "header root {root:?}");
        assert_eq!(envelope.header_difficulty, Some(U256::from(21_000u64)));
        assert_eq!(envelope.end_of_sequencing, Some(true));
        assert_eq!(envelope.is_forced_inclusion, Some(true));
    }
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
