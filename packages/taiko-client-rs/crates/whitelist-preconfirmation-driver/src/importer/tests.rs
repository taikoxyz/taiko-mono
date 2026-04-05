use std::{sync::Arc, time::Duration};

use alethia_reth_consensus::validation::ANCHOR_V4_SELECTOR;
use alloy_consensus::{
    EthereumTypedTransaction, TxEip1559, TxEnvelope, transaction::SignableTransaction,
};
use alloy_eips::{Encodable2718, eip2930::AccessList};
use alloy_primitives::{Address, B256, Bloom, Bytes, U256};
use alloy_provider::{ProviderBuilder, RootProvider};
use alloy_rpc_types_engine::ExecutionPayloadV1;
use alloy_sol_types::SolCall;
use alloy_transport::mock::Asserter;
use bindings::preconf_whitelist::PreconfWhitelist::{
    epochStartTimestampCall, getOperatorForCurrentEpochCall, getOperatorForNextEpochCall,
    operatorsCall, operatorsReturn,
};
use protocol::{FixedKSigner, codec::ZlibTxListCodec};
use tokio::sync::mpsc;

use crate::{
    codec::WhitelistExecutionPayloadEnvelope,
    core::{
        authority::{SignerAuthority, WhitelistSignerAuthority},
        import::{ImportContext, ImportDecision, evaluate_pending_import},
        pending::PendingEnvelopeGraph,
    },
    error::WhitelistPreconfirmationDriverError,
    tx_list_codec::MAX_COMPRESSED_TX_LIST_BYTES,
};

use super::{
    cache_import::{
        PendingDrainAction, PendingImportOutcome, classify_pending_attempt_for_drain,
        finalize_pending_drain, should_defer_cached_import_error, should_drop_cached_import_error,
    },
    ingress::{ValidatedEnvelopePlan, plan_validated_ingress},
    sync_ready_transition,
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

fn sample_execution_payload_with_parent(
    block_number: u64,
    block_hash: B256,
    parent_hash: B256,
) -> Arc<WhitelistExecutionPayloadEnvelope> {
    let mut envelope = sample_execution_payload_with_transactions(vec![valid_anchor_tx_list(
        sample_anchor_address(),
    )]);
    envelope.execution_payload.block_number = block_number;
    envelope.execution_payload.block_hash = block_hash;
    envelope.execution_payload.parent_hash = parent_hash;
    Arc::new(envelope)
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

fn valid_anchor_tx_list(anchor_address: Address) -> Bytes {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let tx_bytes =
        signed_anchor_tx_bytes(&signer, TEST_CHAIN_ID, anchor_address, *ANCHOR_V4_SELECTOR);
    encode_compressed_tx_list(vec![tx_bytes])
}

fn sample_l1_block(
    block_number: u64,
    block_timestamp: u64,
    block_hash: B256,
) -> alloy_rpc_types::eth::Block<TxEnvelope> {
    let mut block = alloy_rpc_types::eth::Block::<TxEnvelope>::default();
    block.header.number = block_number;
    block.header.timestamp = block_timestamp;
    block.header.hash = block_hash;
    block
}

fn push_whitelist_snapshot(
    asserter: &Asserter,
    block_number: u64,
    block_timestamp: u64,
    block_hash: B256,
    current_proposer: Address,
    next_proposer: Address,
    current_sequencer: Address,
    next_sequencer: Address,
    epoch_start_timestamp: u64,
) {
    asserter.push_success(&Some(sample_l1_block(block_number, block_timestamp, block_hash)));
    asserter.push_success(&Bytes::from(getOperatorForCurrentEpochCall::abi_encode_returns(
        &current_proposer,
    )));
    asserter.push_success(&Bytes::from(getOperatorForNextEpochCall::abi_encode_returns(
        &next_proposer,
    )));
    asserter.push_success(&Bytes::from(epochStartTimestampCall::abi_encode_returns(
        &(epoch_start_timestamp as u32),
    )));
    asserter.push_success(&Bytes::from(operatorsCall::abi_encode_returns(&operatorsReturn {
        activeSince: 0,
        deprecatedInactiveSince: 0,
        index: 0,
        sequencerAddress: current_sequencer,
    })));
    asserter.push_success(&Bytes::from(operatorsCall::abi_encode_returns(&operatorsReturn {
        activeSince: 0,
        deprecatedInactiveSince: 0,
        index: 1,
        sequencerAddress: next_sequencer,
    })));
    asserter.push_success(&Some(sample_l1_block(block_number, block_timestamp, block_hash)));
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
fn pending_parent_import_wakes_waiting_child_without_full_cache_scan() {
    let mut pending = PendingEnvelopeGraph::default();
    let ancestor_hash = B256::from([0x01u8; 32]);
    let parent_hash = B256::from([0x02u8; 32]);
    let child_hash = B256::from([0x03u8; 32]);
    let unrelated_parent_hash = B256::from([0x04u8; 32]);
    let unrelated_hash = B256::from([0x05u8; 32]);

    let parent = sample_execution_payload_with_parent(101, parent_hash, ancestor_hash);
    let child = sample_execution_payload_with_parent(102, child_hash, parent_hash);
    let unrelated =
        sample_execution_payload_with_parent(202, unrelated_hash, unrelated_parent_hash);

    pending.insert(parent.clone());
    pending.insert(child.clone());
    pending.insert(unrelated.clone());

    while pending.pop_ready().is_some() {}

    pending.enqueue(child_hash);

    let initial = evaluate_pending_import(
        child.clone(),
        ImportContext {
            head_l1_origin_block_id: Some(100),
            current_block_hash: None,
            parent_block_hash: None,
            allow_parent_request: true,
        },
    );
    assert!(matches!(initial, ImportDecision::RequestParent(hash) if hash == parent_hash));

    pending.remove(&parent_hash);
    pending.enqueue_children(parent_hash);

    assert_eq!(pending.pop_ready(), Some(child_hash));
    assert_eq!(pending.pop_ready(), None);
}

#[test]
fn deferred_pending_attempt_is_retried_on_next_pass() {
    let action = classify_pending_attempt_for_drain(&Ok(PendingImportOutcome::Deferred))
        .expect("deferred pending attempt should stay retryable");
    assert_eq!(action, PendingDrainAction::RetryNextPass);
}

#[test]
fn blocked_pending_attempt_does_not_stall_unrelated_ready_work() {
    let mut pending = PendingEnvelopeGraph::default();
    let parent_hash = B256::from([0x21u8; 32]);
    let blocked_hash = B256::from([0x22u8; 32]);
    let unrelated_hash = B256::from([0x23u8; 32]);

    pending.insert(sample_execution_payload_with_parent(101, blocked_hash, parent_hash));
    pending.insert(sample_execution_payload_with_parent(
        200,
        unrelated_hash,
        B256::from([0x24u8; 32]),
    ));

    let mut retry_next_pass = Vec::new();
    let first = pending.pop_ready().expect("blocked hash should be ready first");
    if classify_pending_attempt_for_drain(&Ok(PendingImportOutcome::Requeue))
        .expect("requeued pending attempt should stay retryable") ==
        PendingDrainAction::RetryNextPass
    {
        retry_next_pass.push(first);
    }

    assert_eq!(
        pending.pop_ready(),
        Some(unrelated_hash),
        "blocked hash must not stall unrelated ready work in the same drain pass"
    );

    pending.enqueue_many(retry_next_pass);
    assert_eq!(
        pending.pop_ready(),
        Some(blocked_hash),
        "blocked hash should be retried on a later pass"
    );
}

#[test]
fn retryable_pending_error_is_retried_on_next_pass() {
    let err =
        WhitelistPreconfirmationDriverError::Driver(driver::DriverError::PreconfInjectionFailed {
            block_number: 42,
            source: driver::sync::error::EngineSubmissionError::MissingParent,
        });

    let action = classify_pending_attempt_for_drain(&Err(err))
        .expect("retryable import error should stay retryable");
    assert_eq!(action, PendingDrainAction::RetryNextPass);
}

#[test]
fn deferred_hash_is_requeued_even_when_later_hash_hits_fatal_error() {
    let mut pending = PendingEnvelopeGraph::default();
    let deferred_hash = B256::from([0x31u8; 32]);
    let fatal_hash = B256::from([0x32u8; 32]);

    pending.insert(sample_execution_payload_with_parent(
        101,
        deferred_hash,
        B256::from([0x41u8; 32]),
    ));
    pending.insert(sample_execution_payload_with_parent(102, fatal_hash, B256::from([0x42u8; 32])));

    let first = pending.pop_ready().expect("first ready hash");
    let second = pending.pop_ready().expect("second ready hash");
    assert_eq!(first, deferred_hash);
    assert_eq!(second, fatal_hash);

    let mut retry_next_pass = vec![deferred_hash];
    let fatal = Err(WhitelistPreconfirmationDriverError::MissingInsertedBlock(102));
    let returned = finalize_pending_drain(&mut pending, &mut retry_next_pass, fatal)
        .expect_err("fatal error should still be returned after preserving retry queue");
    assert!(matches!(returned, WhitelistPreconfirmationDriverError::MissingInsertedBlock(102)));

    assert_eq!(
        pending.pop_ready(),
        Some(deferred_hash),
        "deferred hash must remain queued for the next pass even after a later fatal error"
    );
}

#[test]
fn eos_marked_duplicate_drop_still_records_epoch_mapping() {
    let mut envelope = sample_execution_payload_with_transactions(vec![valid_anchor_tx_list(
        sample_anchor_address(),
    )]);
    envelope.end_of_sequencing = Some(true);
    let block_hash = envelope.execution_payload.block_hash;

    let plan = plan_validated_ingress(&ImportDecision::Drop, Some(block_hash), &envelope);

    assert_eq!(plan, ValidatedEnvelopePlan { cache_pending: false, record_eos: true });
}

#[test]
fn stale_eos_marked_drop_does_not_record_epoch_mapping() {
    let mut envelope = sample_execution_payload_with_transactions(vec![valid_anchor_tx_list(
        sample_anchor_address(),
    )]);
    envelope.end_of_sequencing = Some(true);

    let plan = plan_validated_ingress(&ImportDecision::Drop, None, &envelope);

    assert_eq!(plan, ValidatedEnvelopePlan { cache_pending: false, record_eos: false });
}

#[test]
fn stale_pending_payload_is_dropped_at_or_below_head_l1_origin() {
    let block_hash = B256::from([0x11u8; 32]);
    let parent_hash = B256::from([0x12u8; 32]);
    let envelope = sample_execution_payload_with_parent(42, block_hash, parent_hash);

    let decision = evaluate_pending_import(
        envelope,
        ImportContext {
            head_l1_origin_block_id: Some(42),
            current_block_hash: None,
            parent_block_hash: Some(parent_hash),
            allow_parent_request: true,
        },
    );

    assert!(matches!(decision, ImportDecision::Drop));
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

#[tokio::test]
async fn signer_authority_refreshes_once_on_cached_miss_then_rejects() {
    let asserter = Asserter::new();
    let provider = ProviderBuilder::new()
        .disable_recommended_fillers()
        .connect_mocked_client(asserter.clone());
    let authority = WhitelistSignerAuthority::<RootProvider>::new_for_test(
        Address::from([0xabu8; 20]),
        provider,
        12_345,
        32,
    );

    let first_current = Address::from([0x11u8; 20]);
    let first_next = Address::from([0x22u8; 20]);
    let second_current = Address::from([0x33u8; 20]);
    let second_next = Address::from([0x44u8; 20]);
    let rejected_signer = Address::from([0x55u8; 20]);

    push_whitelist_snapshot(
        &asserter,
        7,
        12_345,
        B256::from([0x77u8; 32]),
        Address::from([0xa1u8; 20]),
        Address::from([0xa2u8; 20]),
        first_current,
        first_next,
        12_288,
    );
    push_whitelist_snapshot(
        &asserter,
        8,
        12_357,
        B256::from([0x88u8; 32]),
        Address::from([0xb1u8; 20]),
        Address::from([0xb2u8; 20]),
        second_current,
        second_next,
        12_288,
    );

    authority
        .ensure_payload_signer_allowed(first_current)
        .await
        .expect("initial lookup should seed the cache");

    let err = authority
        .ensure_payload_signer_allowed(rejected_signer)
        .await
        .expect_err("cached miss should refresh once and still reject if signer remains invalid");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidSignature(message)
            if message.contains(&rejected_signer.to_string())
                && message.contains(&second_current.to_string())
                && message.contains(&second_next.to_string())
    ));

    let err = authority
        .ensure_payload_signer_allowed(rejected_signer)
        .await
        .expect_err("refresh cooldown should reject immediately after the first miss refresh");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidSignature(message)
            if message.contains(&rejected_signer.to_string())
                && message.contains(&second_current.to_string())
                && message.contains(&second_next.to_string())
    ));
}

#[tokio::test]
async fn signer_authority_fee_recipient_mismatch_uses_cached_snapshot_without_refresh() {
    let asserter = Asserter::new();
    let provider = ProviderBuilder::new()
        .disable_recommended_fillers()
        .connect_mocked_client(asserter.clone());
    let authority = WhitelistSignerAuthority::<RootProvider>::new_for_test(
        Address::from([0xabu8; 20]),
        provider,
        12_300,
        32,
    );

    let current = Address::from([0x11u8; 20]);
    let next = Address::from([0x22u8; 20]);
    push_whitelist_snapshot(
        &asserter,
        7,
        12_300,
        B256::from([0x77u8; 32]),
        Address::from([0xa1u8; 20]),
        Address::from([0xa2u8; 20]),
        current,
        next,
        12_288,
    );

    authority
        .ensure_payload_signer_allowed(current)
        .await
        .expect("initial signer lookup should seed the cache");

    let err = authority
        .ensure_fee_recipient_allowed(Address::from([0x55u8; 20]))
        .await
        .expect_err("fee recipient mismatch should fail from cached authority state");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(message)
            if message.contains("fee recipient")
                && message.contains(&current.to_string())
                && message.contains(&next.to_string())
    ));

    authority
        .ensure_payload_signer_allowed(current)
        .await
        .expect("cached signer should remain available after fee recipient mismatch");
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

#[tokio::test]
async fn publish_unsafe_request_command_reports_closed_channel() {
    let (network_command_tx, network_command_rx) = mpsc::channel(1);
    drop(network_command_rx);

    let queued = super::response::publish_unsafe_request_command(
        &network_command_tx,
        B256::from([0x44u8; 32]),
    )
    .await;

    assert!(!queued, "closed network command channel must be reported");
}
