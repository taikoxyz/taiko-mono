use std::time::Duration;

use alethia_reth_consensus::validation::ANCHOR_V4_SELECTOR;
use alloy_consensus::{
    EthereumTypedTransaction, TxEip1559, TxEnvelope, transaction::SignableTransaction,
};
use alloy_eips::{Encodable2718, eip2930::AccessList};
use alloy_primitives::{Address, B256, Bloom, Bytes, U256};
use alloy_rlp::Bytes as RlpBytes;
use alloy_rpc_types_engine::ExecutionPayloadV1;
use protocol::{FixedKSigner, codec::ZlibTxListCodec};

use crate::{codec::WhitelistExecutionPayloadEnvelope, error::WhitelistPreconfirmationDriverError};

use super::{
    MAX_COMPRESSED_TX_LIST_BYTES,
    cache_import::{should_defer_cached_import_error, should_drop_cached_import_error},
    sync_ready_transition, validate_execution_payload_for_preconf_with_tx_list,
    validation::{normalize_unsafe_payload_envelope, validate_execution_payload_for_preconf},
};

const TEST_CHAIN_ID: u64 = 167;
const NON_GOLDEN_SIGNER_PRIVATE_KEY: &str =
    "0x0000000000000000000000000000000000000000000000000000000000000001";

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

fn encode_decompressed_tx_list(transactions: Vec<Vec<u8>>) -> Vec<u8> {
    let rlp_bytes = transactions.into_iter().map(RlpBytes::from).collect::<Vec<_>>();
    alloy_rlp::encode(&rlp_bytes)
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
    assert!(should_drop_cached_import_error(&err));
    assert!(!should_defer_cached_import_error(&err));
}

#[test]
fn drops_cached_import_errors_for_invalid_signature() {
    let err = WhitelistPreconfirmationDriverError::InvalidSignature("bad signature".to_string());
    assert!(should_drop_cached_import_error(&err));
    assert!(!should_defer_cached_import_error(&err));
}

#[test]
fn defers_cached_import_errors_for_engine_syncing_driver_error() {
    let err = WhitelistPreconfirmationDriverError::Driver(driver::DriverError::EngineSyncing(42));
    assert!(!should_drop_cached_import_error(&err));
    assert!(should_defer_cached_import_error(&err));
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
    assert!(should_drop_cached_import_error(&err));
    assert!(!should_defer_cached_import_error(&err));
}

#[test]
fn defers_cached_import_errors_for_missing_parent_driver_error() {
    let err =
        WhitelistPreconfirmationDriverError::Driver(driver::DriverError::PreconfInjectionFailed {
            block_number: 42,
            source: driver::sync::error::EngineSubmissionError::MissingParent,
        });
    assert!(!should_drop_cached_import_error(&err));
    assert!(should_defer_cached_import_error(&err));
}

#[test]
fn propagates_cached_import_errors_for_non_payload_failures() {
    let err = WhitelistPreconfirmationDriverError::MissingInsertedBlock(42);
    assert!(!should_drop_cached_import_error(&err));
    assert!(!should_defer_cached_import_error(&err));
}

#[test]
fn propagates_cached_import_errors_for_driver_queue_timeouts() {
    let err =
        WhitelistPreconfirmationDriverError::Driver(driver::DriverError::PreconfEnqueueTimeout {
            waited: Duration::from_secs(1),
        });
    assert!(!should_drop_cached_import_error(&err));
    assert!(!should_defer_cached_import_error(&err));
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
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("compressed transactions size exceeds")
    ));
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
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("invalid zlib bytes for transactions")
    ));
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
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("invalid RLP bytes for transactions")
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
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("oversized decompressed tx list must be rejected");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("decompressed transactions size exceeds")
    ));
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
fn validate_payload_with_tx_list_rejects_invalid_anchor_transaction() {
    let anchor_address = sample_anchor_address();
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let expected_tx =
        signed_anchor_tx_bytes(&signer, TEST_CHAIN_ID, anchor_address, *ANCHOR_V4_SELECTOR);
    let invalid_anchor_tx =
        signed_anchor_tx_bytes(&signer, TEST_CHAIN_ID, anchor_address, [1, 2, 3, 4]);
    let envelope =
        sample_execution_payload_with_transactions(vec![encode_compressed_tx_list(vec![
            expected_tx,
        ])]);
    let decompressed_tx_list = encode_decompressed_tx_list(vec![invalid_anchor_tx]);

    let err = validate_execution_payload_for_preconf_with_tx_list(
        &envelope.execution_payload,
        &decompressed_tx_list,
        TEST_CHAIN_ID,
        anchor_address,
    )
    .expect_err("invalid anchor in decompressed tx-list must be rejected");
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
fn sync_ready_transition_detects_first_ready_edge() {
    assert!(!sync_ready_transition(false, false));
    assert!(sync_ready_transition(false, true));
    assert!(!sync_ready_transition(true, true));
    assert!(!sync_ready_transition(true, false));
}
