use super::*;
use crate::types::InboxFacts;
use alloy_primitives::{b256, hex};
use protocol::shasta::constants::{TAIKO_DEVNET_CHAIN_ID, min_base_fee_for_chain};
use std::collections::HashSet;

/// Largest value of a `uint48` `extraData` field.
const UINT48_MAX: u64 = (1 << 48) - 1;
/// BFT time of the derived block, in seconds.
const BFT_SECS: u64 = 1_760_000_105;
/// Generation carried by the derived block.
const GENERATION: u64 = 2;

fn devnet() -> ChainParams {
    ChainParams::builtin(TAIKO_DEVNET_CHAIN_ID).expect("devnet is built in")
}

fn anchor(number: u64, timestamp: u64) -> AnchorState {
    AnchorState {
        number,
        hash: B256::repeat_byte(0xa1),
        state_root: B256::repeat_byte(0x5a),
        timestamp,
        inbox: InboxFacts {
            migration_state: 3,
            recovery_generation: GENERATION,
            last_checkpoint_height: 0,
            last_checkpoint_hash: B256::ZERO,
            committee: None,
        },
    }
}

/// A parent at `number` with 30M of 45M gas used, a 2 s block time and a 0.01 gwei base fee.
fn parent(number: u64) -> ParentInfo {
    ParentInfo {
        number,
        hash: B256::repeat_byte(0xbb),
        timestamp: 1_760_000_100,
        gas_limit: 45_000_000,
        gas_used: 30_000_000,
        base_fee: 10_000_000,
        difficulty: U256::from(0x1234_5678u64),
        grandparent_timestamp: 1_760_000_098,
    }
}

fn inputs<'a>(
    height: u64,
    parent: &'a ParentInfo,
    anchor: &'a AnchorState,
    params: &'a ChainParams,
) -> HeaderInputs<'a> {
    HeaderInputs {
        height,
        parent,
        anchor,
        bft_time_secs: BFT_SECS,
        generation: GENERATION,
        params,
        min_base_fee: min_base_fee_for_chain(params.l2_chain_id),
    }
}

/// A header carrying exactly `e`'s fields and the Etna body commitments, with arbitrary
/// execution results (which `check_header` does not inspect).
fn header_for(e: &ExpectedHeader) -> Header {
    Header {
        number: e.number,
        parent_hash: e.parent_hash,
        timestamp: e.timestamp,
        beneficiary: e.beneficiary,
        extra_data: e.extra_data.clone(),
        parent_beacon_block_root: Some(e.parent_beacon_block_root),
        gas_limit: e.gas_limit,
        base_fee_per_gas: Some(e.base_fee),
        mix_hash: e.mix_hash,
        withdrawals_root: Some(EMPTY_ROOT_HASH),
        blob_gas_used: Some(0),
        excess_blob_gas: Some(0),
        requests_hash: Some(EMPTY_REQUESTS_HASH),
        ommers_hash: EMPTY_OMMER_ROOT_HASH,
        nonce: B64::ZERO,
        state_root: B256::repeat_byte(0x01),
        transactions_root: B256::repeat_byte(0x02),
        receipts_root: B256::repeat_byte(0x03),
        gas_used: 21_000,
        difficulty: U256::from(7u64),
        ..Default::default()
    }
}

fn non_genesis_expected() -> ExpectedHeader {
    let (p, a, params) = (parent(10), anchor(500, 1_760_000_090), devnet());
    expected_header(&inputs(11, &p, &a, &params)).expect("derives")
}

// ---------------------------------------------------------------------------------------------
// timestamp (D9)
// ---------------------------------------------------------------------------------------------

#[test]
fn block_timestamp_parent_bound_wins() {
    assert_eq!(block_timestamp(100, 50, 60), 101);
    // BFT time equal to the parent's timestamp must still advance the clock.
    assert_eq!(block_timestamp(100, 100, 100), 101);
}

#[test]
fn block_timestamp_bft_time_wins() {
    assert_eq!(block_timestamp(100, 150, 120), 150);
}

#[test]
fn block_timestamp_anchor_timestamp_wins() {
    assert_eq!(block_timestamp(100, 120, 150), 150);
}

#[test]
fn block_timestamp_saturates_at_u64_max() {
    assert_eq!(block_timestamp(u64::MAX, 0, 0), u64::MAX);
}

// ---------------------------------------------------------------------------------------------
// extraData (D10)
// ---------------------------------------------------------------------------------------------

#[test]
fn extra_data_encodes_the_13_byte_layout_and_round_trips() {
    let extra = encode_extra_data(2, 123_456).expect("fits uint48");
    assert_eq!(extra.as_ref(), hex!("6400000000000200000001e240"));
    assert_eq!(decode_extra_data(&extra), Ok((BASEFEE_SHARING_PCTG, 2, 123_456)));

    let max = encode_extra_data(UINT48_MAX, UINT48_MAX).expect("max uint48 fits");
    assert_eq!(max.as_ref(), hex!("64ffffffffffffffffffffffff"));
    assert_eq!(decode_extra_data(&max), Ok((100, UINT48_MAX, UINT48_MAX)));

    let zero = encode_extra_data(0, 0).expect("fits uint48");
    assert_eq!(decode_extra_data(&zero), Ok((100, 0, 0)));
}

#[test]
fn decode_extra_data_returns_the_pctg_byte_verbatim() {
    let mut raw = hex!("6400000000000200000001e240");
    raw[0] = 50;
    assert_eq!(decode_extra_data(&raw), Ok((50, 2, 123_456)));
}

#[test]
fn decode_extra_data_rejects_wrong_lengths() {
    for len in [0, 7, 12, 14, 32] {
        assert_eq!(
            decode_extra_data(&vec![0u8; len]),
            Err(RuleViolation::ExtraDataLength { len }),
            "length {len}"
        );
    }
}

#[test]
fn encode_extra_data_rejects_uint48_overflow() {
    assert_eq!(
        encode_extra_data(UINT48_MAX + 1, 1),
        Err(RuleViolation::ExtraDataOverflow { field: "proposal_id", value: UINT48_MAX + 1 })
    );
    assert_eq!(
        encode_extra_data(1, u64::MAX),
        Err(RuleViolation::ExtraDataOverflow { field: "anchor_block_number", value: u64::MAX })
    );
}

// ---------------------------------------------------------------------------------------------
// expected_header (§4.2)
// ---------------------------------------------------------------------------------------------

#[test]
fn expected_header_for_a_genesis_parent() {
    let (p, a, params) = (parent(0), anchor(500, 1_760_000_090), devnet());
    let e = expected_header(&inputs(1, &p, &a, &params)).expect("derives");

    assert_eq!(
        e,
        ExpectedHeader {
            number: 1,
            parent_hash: p.hash,
            timestamp: BFT_SECS,
            beneficiary: params.fee_vault,
            extra_data: Bytes::from(hex!("640000000000020000000001f4").to_vec()),
            parent_beacon_block_root: a.state_root,
            gas_limit: 45_000_000,
            // SHASTA_INITIAL_BASE_FEE: a genesis parent has no EIP-4396 history.
            base_fee: 25_000_000,
            // cast keccak $(cast abi-encode "f(bytes32,uint256)" 0x…12345678 1)
            mix_hash: b256!("34acd378dfd378594470c18d7731dc28468c2055cbf8740605e2cd01857fb36b"),
        }
    );
}

#[test]
fn expected_header_for_a_non_genesis_parent() {
    let (p, a, params) = (parent(10), anchor(500, 1_760_000_090), devnet());
    let e = expected_header(&inputs(11, &p, &a, &params)).expect("derives");

    assert_eq!(e.number, 11);
    assert_eq!(e.parent_hash, p.hash);
    assert_eq!(e.timestamp, BFT_SECS);
    assert_eq!(e.beneficiary, params.fee_vault);
    assert_eq!(decode_extra_data(&e.extra_data), Ok((100, GENERATION, 500)));
    assert_eq!(e.parent_beacon_block_root, a.state_root);
    assert_eq!(e.gas_limit, params.block_gas_limit);
    // 30M used against a 22.5M target over a 2 s block: 10_000_000 + 10_000_000·7.5M/22.5M/8.
    assert_eq!(e.base_fee, 10_416_666);
    // cast keccak $(cast abi-encode "f(bytes32,uint256)" 0x…12345678 11)
    assert_eq!(
        e.mix_hash,
        b256!("69a17d16a60a2683cbcd0dc437cf2684c6854540883f28a00d91310c13f45851")
    );
}

#[test]
fn expected_header_applies_the_timestamp_rule() {
    let params = devnet();
    let p = parent(10);
    // The anchor is newer than both the parent and BFT time.
    let a = anchor(500, BFT_SECS + 30);
    assert_eq!(expected_header(&inputs(11, &p, &a, &params)).unwrap().timestamp, BFT_SECS + 30);
    // BFT time lags the parent.
    let a = anchor(500, 0);
    let late = ParentInfo { timestamp: BFT_SECS + 9, ..parent(10) };
    assert_eq!(expected_header(&inputs(11, &late, &a, &params)).unwrap().timestamp, BFT_SECS + 10);
}

#[test]
fn expected_header_clamps_the_base_fee_to_the_minimum() {
    let (a, params) = (anchor(500, 0), devnet());
    let idle = ParentInfo { gas_used: 0, base_fee: 1, ..parent(10) };
    let e = expected_header(&inputs(11, &idle, &a, &params)).unwrap();
    assert_eq!(e.base_fee, min_base_fee_for_chain(params.l2_chain_id));
}

#[test]
fn expected_header_requires_the_next_height() {
    let (p, a, params) = (parent(10), anchor(500, 0), devnet());
    for height in [0, 10, 12, u64::MAX] {
        assert_eq!(
            expected_header(&inputs(height, &p, &a, &params)),
            Err(RuleViolation::HeightMismatch { height, parent: 10 }),
            "height {height}"
        );
    }
    let last = parent(u64::MAX);
    assert_eq!(
        expected_header(&inputs(0, &last, &a, &params)),
        Err(RuleViolation::HeightMismatch { height: 0, parent: u64::MAX })
    );
}

#[test]
fn expected_header_rejects_a_generation_beyond_uint48() {
    let (p, a, params) = (parent(10), anchor(500, 0), devnet());
    let i = HeaderInputs { generation: UINT48_MAX + 1, ..inputs(11, &p, &a, &params) };
    assert_eq!(
        expected_header(&i),
        Err(RuleViolation::ExtraDataOverflow { field: "proposal_id", value: UINT48_MAX + 1 })
    );
}

// ---------------------------------------------------------------------------------------------
// check_header
// ---------------------------------------------------------------------------------------------

#[test]
fn check_header_accepts_the_derived_header() {
    let e = non_genesis_expected();
    check_header(&header_for(&e), &e).expect("matches");
}

#[test]
fn check_header_ignores_execution_results() {
    let e = non_genesis_expected();
    let h = Header {
        state_root: B256::repeat_byte(0xee),
        receipts_root: B256::repeat_byte(0xef),
        transactions_root: B256::repeat_byte(0xf0),
        gas_used: 1,
        difficulty: U256::MAX,
        ..header_for(&e)
    };
    check_header(&h, &e).expect("execution results are the EL's to check");
}

#[test]
fn check_header_rejects_every_single_field_mutation() {
    type Mutation = fn(&mut Header);
    let cases: [(&str, Mutation); 15] = [
        ("number", |h| h.number += 1),
        ("parent_hash", |h| h.parent_hash = B256::repeat_byte(0x99)),
        ("timestamp", |h| h.timestamp += 1),
        ("beneficiary", |h| h.beneficiary = Address::repeat_byte(0x99)),
        ("extra_data", |h| h.extra_data = encode_extra_data(GENERATION, 501).unwrap()),
        ("parent_beacon_block_root", |h| h.parent_beacon_block_root = None),
        ("gas_limit", |h| h.gas_limit -= 1),
        ("base_fee_per_gas", |h| h.base_fee_per_gas = h.base_fee_per_gas.map(|f| f + 1)),
        ("mix_hash", |h| h.mix_hash = B256::ZERO),
        ("withdrawals_root", |h| h.withdrawals_root = None),
        ("blob_gas_used", |h| h.blob_gas_used = Some(131_072)),
        ("excess_blob_gas", |h| h.excess_blob_gas = None),
        ("requests_hash", |h| h.requests_hash = Some(B256::ZERO)),
        ("ommers_hash", |h| h.ommers_hash = EMPTY_ROOT_HASH),
        ("nonce", |h| h.nonce = B64::with_last_byte(1)),
    ];
    let e = non_genesis_expected();
    for (field, mutate) in cases {
        let mut h = header_for(&e);
        mutate(&mut h);
        match check_header(&h, &e) {
            Err(RuleViolation::HeaderField { field: got, expected, got: actual }) => {
                assert_eq!(got, field);
                assert_ne!(expected, actual, "{field}: the report must show the difference");
            }
            other => panic!("{field}: expected a HeaderField violation, got {other:?}"),
        }
    }
}

#[test]
fn check_header_reports_the_first_mismatch() {
    let e = non_genesis_expected();
    let h = Header { number: 99, nonce: B64::with_last_byte(1), ..header_for(&e) };
    assert_eq!(
        check_header(&h, &e),
        Err(RuleViolation::HeaderField {
            field: "number",
            expected: "11".to_string(),
            got: "99".to_string(),
        })
    );
}

// ---------------------------------------------------------------------------------------------
// payload_attributes
// ---------------------------------------------------------------------------------------------

#[test]
fn payload_attributes_mirror_the_expected_header() {
    let e = non_genesis_expected();
    let anchor_hash = B256::repeat_byte(0xa1);
    let attrs = payload_attributes(&e, anchor_hash);

    let eth = &attrs.payload_attributes;
    assert_eq!(eth.timestamp, e.timestamp);
    assert_eq!(eth.prev_randao, e.mix_hash);
    assert_eq!(eth.suggested_fee_recipient, e.beneficiary);
    assert_eq!(eth.suggested_fee_recipient, devnet().fee_vault);
    assert_eq!(eth.withdrawals, Some(vec![]));
    assert_eq!(eth.parent_beacon_block_root, Some(e.parent_beacon_block_root));

    assert_eq!(attrs.base_fee_per_gas, U256::from(e.base_fee));
    let meta = &attrs.block_metadata;
    assert_eq!(meta.beneficiary, e.beneficiary);
    assert_eq!(meta.gas_limit, e.gas_limit);
    assert_eq!(meta.timestamp, U256::from(e.timestamp));
    assert_eq!(meta.mix_hash, e.mix_hash);
    assert_eq!(meta.tx_list, None);
    assert_eq!(meta.extra_data, e.extra_data);

    let origin = &attrs.l1_origin;
    assert_eq!(origin.block_id, U256::from(e.number));
    assert_eq!(origin.l1_block_height, Some(U256::from(500u64)));
    assert_eq!(origin.l1_block_hash, Some(anchor_hash));
    assert!(!origin.is_forced_inclusion);
    assert_eq!(origin.signature, [0u8; 65]);
    assert_ne!(origin.build_payload_args_id, [0u8; 8], "payload id is stamped");
    assert_eq!(attrs.anchor_transaction, None);
}

#[test]
fn payload_attributes_id_depends_on_the_parent_hash() {
    let e = non_genesis_expected();
    let other = ExpectedHeader { parent_hash: B256::repeat_byte(0x42), ..e.clone() };
    assert_ne!(
        payload_attributes(&e, B256::ZERO).l1_origin.build_payload_args_id,
        payload_attributes(&other, B256::ZERO).l1_origin.build_payload_args_id
    );
}

// ---------------------------------------------------------------------------------------------
// anchor progress, back-pressure, generation
// ---------------------------------------------------------------------------------------------

/// `H_0 = 101`, `L = 20`, `L1_0 = 50`, `EPOCH_LEN_L1 = 4`: epoch 2 starts at height 141 and needs
/// an anchor >= 58.
fn schedule() -> Schedule {
    Schedule { genesis_height: 100, l1_0: 50, epoch_len: 20, epoch_len_l1: 4 }
}

#[test]
fn anchor_progress_accepts_monotone_anchors_at_or_past_the_epoch_minimum() {
    let s = schedule();
    // Same anchor as the parent, at L1_0, at H_0.
    check_anchor_progress(50, 50, &s, 101).unwrap();
    // Exactly L1_first(2) at the first height of epoch 2.
    check_anchor_progress(55, 58, &s, 141).unwrap();
    // Unchanged anchor past the epoch minimum.
    check_anchor_progress(70, 70, &s, 160).unwrap();
}

#[test]
fn anchor_progress_rejects_a_regression() {
    assert_eq!(
        check_anchor_progress(60, 59, &schedule(), 141),
        Err(RuleViolation::AnchorRegressed { parent: 60, anchor: 59 })
    );
}

#[test]
fn anchor_progress_rejects_an_anchor_before_activation() {
    assert_eq!(
        check_anchor_progress(40, 49, &schedule(), 101),
        Err(RuleViolation::AnchorBeforeActivation { anchor: 49, l1_0: 50 })
    );
}

#[test]
fn anchor_progress_rejects_an_epoch_not_yet_open_on_l1() {
    assert_eq!(
        check_anchor_progress(55, 57, &schedule(), 141),
        Err(RuleViolation::EpochNotOpenOnL1 { epoch: 2, l1_first: 58 })
    );
    // The last height of epoch 1 only needs L1_first(1) = 54.
    check_anchor_progress(55, 57, &schedule(), 140).unwrap();
}

#[test]
fn back_pressure_boundary() {
    check_back_pressure(110, 100, 10).expect("depth == cap is allowed");
    assert_eq!(
        check_back_pressure(111, 100, 10),
        Err(RuleViolation::BackPressure { depth: 11, cap: 10 })
    );
    check_back_pressure(100, 100, 0).expect("depth 0 with cap 0");
    check_back_pressure(90, 100, 0).expect("a checkpoint ahead of the height saturates to 0");
}

#[test]
fn generation_matrix() {
    // (chain, extra, inbox, expected)
    let cases = [
        (0, 0, 0, Ok(GenerationCheck::Ok)),
        (3, 3, 3, Ok(GenerationCheck::Ok)),
        (3, 3, 4, Ok(GenerationCheck::Superseded)),
        (3, 3, u64::MAX, Ok(GenerationCheck::Superseded)),
        (3, 3, 2, Err(RuleViolation::GenerationAhead { chain: 3, inbox: 2 })),
        (3, 4, 3, Err(RuleViolation::GenerationMismatch { chain: 3, extra: 4 })),
        (3, 2, 3, Err(RuleViolation::GenerationMismatch { chain: 3, extra: 2 })),
        // A mismatching extraData is rejected even when the chain is superseded.
        (3, 4, 9, Err(RuleViolation::GenerationMismatch { chain: 3, extra: 4 })),
    ];
    for (chain, extra, inbox, expected) in cases {
        assert_eq!(
            check_generation(chain, extra, inbox),
            expected,
            "chain={chain} extra={extra} inbox={inbox}"
        );
    }
}

// ---------------------------------------------------------------------------------------------
// chain id
// ---------------------------------------------------------------------------------------------

#[test]
fn chain_id_format_and_round_trip() {
    assert_eq!(chain_id_for(167_001, 0), "taiko-etna-167001-g0");
    assert_eq!(chain_id_for(167_000, 12), "taiko-etna-167000-g12");
    for generation in [0, 1, 9, 10, 1_000, u64::MAX] {
        let id = chain_id_for(167_001, generation);
        assert_eq!(generation_from_chain_id(&id, 167_001), Ok(generation), "{id}");
    }
}

#[test]
fn chain_id_fits_cometbft_max_len() {
    assert!(chain_id_for(167_000, u64::MAX).len() <= MAX_CHAIN_ID_LEN);
    assert_eq!(MAX_CHAIN_ID_LEN, 50);
}

#[test]
fn generation_from_chain_id_rejects_malformed_ids() {
    for id in [
        "",
        "taiko-etna-167001-g",
        "taiko-etna-167001-g01",
        "taiko-etna-167001-g00",
        "taiko-etna-167001-g+1",
        "taiko-etna-167001-g-1",
        "taiko-etna-167001-g1a",
        "taiko-etna-167001-g 1",
        "taiko-etna-167001-g1 ",
        "taiko-etna-167001-g\u{0661}",
        "taiko-etna-167001-g18446744073709551616",
        "taiko-etna-167001-1",
        "taiko-etna-167000-g1",
        "taiko-etna-0167001-g1",
        "taiko-etna-1670010-g1",
        "Taiko-etna-167001-g1",
        "taiko-shasta-167001-g1",
        " taiko-etna-167001-g1",
    ] {
        assert_eq!(
            generation_from_chain_id(id, 167_001),
            Err(RuleViolation::InvalidChainId { chain_id: id.to_string(), l2_chain_id: 167_001 }),
            "{id:?}"
        );
    }
}

// ---------------------------------------------------------------------------------------------
// labels
// ---------------------------------------------------------------------------------------------

/// One value of every [`RuleViolation`] variant.
fn every_violation() -> Vec<RuleViolation> {
    let all = vec![
        RuleViolation::HeightMismatch { height: 2, parent: 0 },
        RuleViolation::HeaderField { field: "number", expected: "1".into(), got: "2".into() },
        RuleViolation::ExtraDataOverflow { field: "proposal_id", value: u64::MAX },
        RuleViolation::ExtraDataLength { len: 7 },
        RuleViolation::BaseFeeUnavailable { parent: 1 },
        RuleViolation::AnchorRegressed { parent: 2, anchor: 1 },
        RuleViolation::AnchorBeforeActivation { anchor: 1, l1_0: 2 },
        RuleViolation::EpochNotOpenOnL1 { epoch: 1, l1_first: 2 },
        RuleViolation::BackPressure { depth: 11, cap: 10 },
        RuleViolation::GenerationMismatch { chain: 1, extra: 2 },
        RuleViolation::GenerationAhead { chain: 2, inbox: 1 },
        RuleViolation::InvalidChainId { chain_id: "x".into(), l2_chain_id: 1 },
    ];
    // Exhaustiveness guard: adding a variant without listing it above fails to compile here.
    for v in &all {
        match v {
            RuleViolation::HeightMismatch { .. } |
            RuleViolation::HeaderField { .. } |
            RuleViolation::ExtraDataOverflow { .. } |
            RuleViolation::ExtraDataLength { .. } |
            RuleViolation::BaseFeeUnavailable { .. } |
            RuleViolation::AnchorRegressed { .. } |
            RuleViolation::AnchorBeforeActivation { .. } |
            RuleViolation::EpochNotOpenOnL1 { .. } |
            RuleViolation::BackPressure { .. } |
            RuleViolation::GenerationMismatch { .. } |
            RuleViolation::GenerationAhead { .. } |
            RuleViolation::InvalidChainId { .. } => {}
        }
    }
    all
}

#[test]
fn every_label_is_unique_and_snake_case() {
    let all = every_violation();
    let labels: HashSet<&str> = all.iter().map(RuleViolation::label).collect();
    assert_eq!(labels.len(), all.len(), "labels must be unique: {labels:?}");
    for label in labels {
        assert!(!label.is_empty(), "empty label");
        assert!(
            label.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'_'),
            "{label} is not snake_case"
        );
    }
}

#[test]
fn every_violation_has_a_message() {
    for v in every_violation() {
        assert!(!v.to_string().is_empty(), "{v:?}");
    }
}
