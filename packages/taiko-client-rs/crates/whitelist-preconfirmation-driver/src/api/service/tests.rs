use std::{
    io::Write,
    time::{Duration, Instant},
};

use alloy_primitives::{Address, B256, Bytes, U256};
use alloy_rpc_types::Header as RpcHeader;
use alloy_signer_local::PrivateKeySigner;
use flate2::{Compression, write::ZlibEncoder};
use protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID;
use tokio::sync::mpsc;

use crate::{
    api::{
        service::{
            HAND_OVER_WINDOW_SLOTS, SHUTDOWN_BLOCK_WINDOW, SHUTDOWN_IMMINENCE_MARGIN_SLOTS,
            WhitelistApiService, WhitelistApiServiceParams, can_shutdown_for,
            payload_build::{driver_payload_from_request, published_envelope},
        },
        types::ExecutableData,
    },
    cache::SharedPreconfState,
    codec::{
        MAX_COMPRESSED_TX_LIST_BYTES, MAX_DECOMPRESSED_TX_LIST_BYTES, decode_envelope_ssz,
        decompress_tx_list, encode_envelope_ssz,
    },
    error::WhitelistPreconfirmationDriverError,
    test_support::OfflineDeps,
};

/// Mainnet slots-per-epoch used by the shutdown tests.
const SLOTS_PER_EPOCH: u64 = 32;

/// First slot of the epoch at which the imminence guard starts refusing
/// shutdown: the hand-over boundary minus the imminence margin.
const IMMINENCE_BAND_START: u64 =
    SLOTS_PER_EPOCH - HAND_OVER_WINDOW_SLOTS - SHUTDOWN_IMMINENCE_MARGIN_SLOTS;

/// A slot comfortably outside the imminence band, so activity-focused tests
/// exercise only the request-recency rule.
const MID_EPOCH_SLOT: u64 = 2;

#[test]
fn whitelist_service_uses_standard_signer() {
    fn assert_standard_signer(_: &PrivateKeySigner) {}

    fn check_service_signer(service: &WhitelistApiService) {
        assert_standard_signer(&service.signer);
    }

    let _ = check_service_signer as fn(&WhitelistApiService);
}

fn compress(payload: &[u8]) -> Vec<u8> {
    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(payload).expect("write zlib payload");
    encoder.finish().expect("finish zlib encoding")
}

#[test]
fn decompress_tx_list_rejects_oversized_compressed_payload() {
    let oversized = vec![0u8; MAX_COMPRESSED_TX_LIST_BYTES + 1];
    let err = decompress_tx_list(&oversized).expect_err("oversized compressed payload must fail");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("compressed tx list exceeds maximum size")
    ));
}

#[test]
fn decompress_tx_list_rejects_oversized_decompressed_payload() {
    let oversized = vec![0x11u8; MAX_DECOMPRESSED_TX_LIST_BYTES + 1];
    let compressed = compress(&oversized);
    let err = decompress_tx_list(&compressed)
        .expect_err("oversized decompressed payload must fail before use");
    assert!(matches!(
        err,
        WhitelistPreconfirmationDriverError::InvalidPayload(msg)
            if msg.contains("decompressed tx list exceeds maximum size")
    ));
}

#[test]
fn decompress_tx_list_accepts_non_empty_payload_within_limits() {
    let expected = vec![0xAA, 0xBB, 0xCC];
    let compressed = compress(&expected);
    let decoded = decompress_tx_list(&compressed).expect("valid payload should decode");
    assert_eq!(decoded, expected);
}

/// Nonzero Etna root (the L1 state root of the anchor block).
const SAMPLE_ETNA_ROOT: B256 = B256::repeat_byte(0x5a);

/// Build a REST request body's executable data carrying `root`.
fn sample_executable_data(root: Option<B256>) -> ExecutableData {
    ExecutableData {
        parent_hash: B256::repeat_byte(0x01),
        fee_recipient: Address::repeat_byte(0x11),
        block_number: 42,
        gas_limit: 30_000_000,
        timestamp: 1_735_000_000,
        transactions: Bytes::from(compress(&[0xc0])),
        extra_data: Bytes::from(vec![0x32u8; 13]),
        base_fee_per_gas: 7,
        parent_beacon_block_root: root,
    }
}

/// Build the header the execution engine returns for the inserted block.
fn sample_inserted_header(difficulty: U256, base_fee_per_gas: Option<u64>) -> RpcHeader {
    RpcHeader {
        hash: B256::repeat_byte(0x05),
        inner: alloy_consensus::Header {
            parent_hash: B256::repeat_byte(0x01),
            number: 42,
            timestamp: 1_735_000_000,
            difficulty,
            base_fee_per_gas,
            ..Default::default()
        },
        ..Default::default()
    }
}

/// Build the REST service over offline dependencies with Etna at `etna_fork_timestamp`.
fn offline_service(deps: &OfflineDeps, etna_fork_timestamp: Option<u64>) -> WhitelistApiService {
    let (network_command_tx, _) = mpsc::channel(1);
    WhitelistApiService::new(WhitelistApiServiceParams {
        event_syncer: deps.event_syncer.clone(),
        rpc: deps.rpc.clone(),
        chain_id: deps.rpc.chain_id,
        etna_fork_timestamp,
        signer: PrivateKeySigner::random(),
        beacon_client: deps.beacon_client.clone(),
        operator_set: Default::default(),
        state: SharedPreconfState::new(0),
        network_command_tx,
    })
}

/// A build request is validated under the service's own Etna schedule: an Etna request (no
/// anchor, a nonzero root, 13-byte `extraData`) passes once Etna is active at its timestamp and
/// is refused while Etna is not scheduled.
#[tokio::test]
async fn build_request_validation_follows_the_service_etna_schedule() {
    let deps = OfflineDeps::new(TAIKO_DEVNET_CHAIN_ID, Address::repeat_byte(0x44)).await;
    let data = sample_executable_data(Some(SAMPLE_ETNA_ROOT));

    offline_service(&deps, Some(data.timestamp))
        .validate_request_payload(&data, B256::ZERO)
        .expect("an Etna request passes once Etna is active");
    let err = offline_service(&deps, None)
        .validate_request_payload(&data, B256::ZERO)
        .expect_err("an Etna request is refused while Etna is not scheduled");
    assert!(
        matches!(err, WhitelistPreconfirmationDriverError::InvalidPayload(_)),
        "unexpected error: {err:?}"
    );
}

#[test]
fn published_envelope_carries_the_request_root() {
    let data = sample_executable_data(Some(SAMPLE_ETNA_ROOT));
    let header = sample_inserted_header(U256::ZERO, Some(9));

    let envelope = published_envelope(&data, &header, Some(true), None, [0x22u8; 65]);
    assert_eq!(envelope.parent_beacon_block_root, Some(SAMPLE_ETNA_ROOT));
    assert_eq!(envelope.execution_payload.block_hash, header.hash);
    assert_eq!(envelope.execution_payload.transactions, vec![data.transactions.clone()]);
    assert_eq!(envelope.end_of_sequencing, Some(true));
    assert_eq!(envelope.signature, Some([0x22u8; 65]));

    let decoded = decode_envelope_ssz(&encode_envelope_ssz(&envelope)).expect("decode envelope");
    assert_eq!(decoded.parent_beacon_block_root, Some(SAMPLE_ETNA_ROOT));
}

/// The REST build hands the request's root to the driver: an Etna request's nonzero root as
/// is, an absent or zero one as the zero root every pre-Etna build sends.
#[test]
fn driver_payload_from_request_sends_the_request_root() {
    let prev_randao = B256::repeat_byte(0x04);
    let etna = driver_payload_from_request(
        &sample_executable_data(Some(SAMPLE_ETNA_ROOT)),
        None,
        prev_randao,
        [0u8; 65],
    )
    .expect("Etna request builds");
    assert_eq!(etna.payload_attributes.parent_beacon_block_root, Some(SAMPLE_ETNA_ROOT));

    for root in [None, Some(B256::ZERO)] {
        let pre_etna = driver_payload_from_request(
            &sample_executable_data(root),
            None,
            prev_randao,
            [0u8; 65],
        )
        .expect("pre-Etna request builds");
        assert_eq!(
            pre_etna.payload_attributes.parent_beacon_block_root,
            Some(B256::ZERO),
            "request root {root:?}"
        );
        assert_ne!(
            pre_etna.l1_origin.build_payload_args_id, etna.l1_origin.build_payload_args_id,
            "the root is bound into the payload fingerprint"
        );
    }
}

#[test]
fn published_envelope_carries_an_absent_or_zero_request_root_as_none() {
    let header = sample_inserted_header(U256::from(21_000u64), Some(9));
    for root in [None, Some(B256::ZERO)] {
        let envelope =
            published_envelope(&sample_executable_data(root), &header, None, None, [0u8; 65]);
        assert_eq!(envelope.parent_beacon_block_root, None, "request root {root:?}");
    }
}

#[test]
fn published_envelope_sets_header_difficulty_only_when_nonzero() {
    let data = sample_executable_data(Some(SAMPLE_ETNA_ROOT));

    let empty = published_envelope(
        &data,
        &sample_inserted_header(U256::ZERO, Some(9)),
        None,
        None,
        [0u8; 65],
    );
    assert_eq!(empty.header_difficulty, None);

    let full = published_envelope(
        &data,
        &sample_inserted_header(U256::from(21_000u64), Some(9)),
        None,
        None,
        [0u8; 65],
    );
    assert_eq!(full.header_difficulty, Some(U256::from(21_000u64)));
}

#[test]
fn published_envelope_prefers_the_header_base_fee() {
    let data = sample_executable_data(None);

    let from_header = published_envelope(
        &data,
        &sample_inserted_header(U256::ZERO, Some(9)),
        None,
        None,
        [0; 65],
    );
    assert_eq!(from_header.execution_payload.base_fee_per_gas, U256::from(9u64));

    let from_request =
        published_envelope(&data, &sample_inserted_header(U256::ZERO, None), None, None, [0; 65]);
    assert_eq!(from_request.execution_payload.base_fee_per_gas, U256::from(7u64));
}

#[test]
fn can_shutdown_returns_true_when_no_request_received() {
    assert!(can_shutdown_for(None, MID_EPOCH_SLOT, SLOTS_PER_EPOCH));
}

#[test]
fn can_shutdown_returns_false_for_request_just_now() {
    assert!(!can_shutdown_for(Some(Instant::now()), MID_EPOCH_SLOT, SLOTS_PER_EPOCH));
}

#[test]
fn can_shutdown_returns_true_after_full_window_has_elapsed() {
    let well_past = Instant::now()
        .checked_sub(SHUTDOWN_BLOCK_WINDOW + Duration::from_secs(1))
        .expect("test platform must support subtracting from Instant::now");
    assert!(can_shutdown_for(Some(well_past), MID_EPOCH_SLOT, SLOTS_PER_EPOCH));
}

#[test]
fn can_shutdown_returns_false_just_before_window_boundary() {
    let almost = Instant::now()
        .checked_sub(SHUTDOWN_BLOCK_WINDOW - Duration::from_secs(1))
        .expect("test platform must support subtracting from Instant::now");
    assert!(!can_shutdown_for(Some(almost), MID_EPOCH_SLOT, SLOTS_PER_EPOCH));
}

#[test]
fn can_shutdown_allows_just_before_imminence_band() {
    assert!(can_shutdown_for(None, IMMINENCE_BAND_START - 1, SLOTS_PER_EPOCH));
}

#[test]
fn can_shutdown_blocks_at_imminence_band_start() {
    assert!(!can_shutdown_for(None, IMMINENCE_BAND_START, SLOTS_PER_EPOCH));
}

#[test]
fn can_shutdown_blocks_through_epoch_tail() {
    assert!(!can_shutdown_for(None, SLOTS_PER_EPOCH - 1, SLOTS_PER_EPOCH));
}

#[test]
fn can_shutdown_allows_at_epoch_start() {
    assert!(can_shutdown_for(None, 0, SLOTS_PER_EPOCH));
}

#[test]
fn shutdown_block_window_is_one_hundred_forty_four_seconds() {
    assert_eq!(SHUTDOWN_BLOCK_WINDOW, Duration::from_secs(144));
}

#[test]
fn reported_head_prefers_live_head_and_records_it_as_fallback() {
    let state = SharedPreconfState::new(5_811_208);
    // The live head always wins — the Catalyst sync gate compares the reported value
    // against the execution head exactly, and reporting anything else wedges it in a
    // restart loop. This covers both the L1-reorg (head rewound) and the catch-up
    // (head advanced via canonical derivation with no gossip) directions.
    assert_eq!(state.reconcile_reported_head(Some(5_811_227)), 5_811_227);
    assert_eq!(state.reconcile_reported_head(Some(5_811_190)), 5_811_190);
    // A later failed read reports the most recently observed head, not the startup seed.
    assert_eq!(state.reconcile_reported_head(None), 5_811_190);
}

#[test]
fn reported_head_falls_back_to_seed_before_first_observation() {
    // Best-effort: a failed head read before any successful observation reports the
    // startup seed.
    let state = SharedPreconfState::new(5_811_208);
    assert_eq!(state.reconcile_reported_head(None), 5_811_208);
}

#[test]
fn reported_head_covers_locally_inserted_blocks_when_head_unreadable() {
    // Blocks inserted by this process (cached import or local build) must survive a failed
    // head read even before any successful status poll observed them.
    let state = SharedPreconfState::new(5_811_208);
    state.record_inserted_block(5_811_209);
    assert_eq!(state.reconcile_reported_head(None), 5_811_209);
    // A successful poll still overwrites the fallback with the live head.
    assert_eq!(state.reconcile_reported_head(Some(5_811_210)), 5_811_210);
    assert_eq!(state.reconcile_reported_head(None), 5_811_210);
}
