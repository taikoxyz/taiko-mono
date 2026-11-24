use super::*;
use crate::{config::ChainParamsExt, types::InboxFacts};
use alloy_primitives::{b256, hex};
use protocol::shasta::constants::{TAIKO_DEVNET_CHAIN_ID, min_base_fee_for_chain};
use std::collections::HashSet;

/// Largest value of a `uint48` `extraData` field.
const UINT48_MAX: u64 = (1 << 48) - 1;
/// BFT time of the derived block, in seconds.
const BFT_SECS: u64 = 1_760_000_105;
/// Generation carried by the derived block.
const GENERATION: u64 = 2;

/// The `extraData` fields of an Etna block: the sharing byte 100 and the given values.
fn extra(generation: u64, anchor: u64, miss_bitmap: u128) -> ExtraData {
    ExtraData { basefee_sharing_pctg: BASEFEE_SHARING_PCTG, generation, anchor, miss_bitmap }
}

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
            rules_schedule: alloy_primitives::U256::ZERO,
            recovery_generation: GENERATION,
            last_checkpoint_height: 0,
            last_checkpoint_hash: B256::ZERO,
            forced_inclusion_head: 0,
            forced_inclusion_tail: 0,
            fallback_keys_hash: B256::ZERO,
            min_total_stake: alloy_primitives::U256::ZERO,
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
        miss_bitmap: 0,
        params,
        min_base_fee: min_base_fee_for_chain(params.l2_chain_id),
        beneficiary: Address::repeat_byte(0x77),
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
// timestamp
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
// extraData
// ---------------------------------------------------------------------------------------------

#[test]
fn extra_data_round_trips_29_bytes() {
    let fields = extra(2, 123_456, (1 << 127) | 5);
    let bytes = encode_extra_data(&fields).expect("fits uint48");
    assert_eq!(bytes.len(), EXTRA_DATA_LEN);
    assert_eq!(
        bytes.as_ref(),
        hex!("64" "000000000002" "00000001e240" "80000000000000000000000000000005")
    );
    assert_eq!(decode_extra_data(&bytes), Ok(fields));

    let max = extra(UINT48_MAX, UINT48_MAX, u128::MAX);
    let bytes = encode_extra_data(&max).expect("max uint48 fits");
    assert_eq!(
        bytes.as_ref(),
        hex!("64" "ffffffffffff" "ffffffffffff" "ffffffffffffffffffffffffffffffff")
    );
    assert_eq!(decode_extra_data(&bytes), Ok(max));

    let zero = encode_extra_data(&extra(0, 0, 0)).expect("fits uint48");
    assert_eq!((zero[0], &zero[1..]), (0x64, &[0u8; 28][..]));
    assert_eq!(decode_extra_data(&zero), Ok(extra(0, 0, 0)));
}

#[test]
fn extra_data_length_other_than_29_is_refused() {
    let bytes = encode_extra_data(&extra(GENERATION, 500, 1)).unwrap();
    for len in [13, 28] {
        assert_eq!(
            decode_extra_data(&bytes[..len]),
            Err(RuleViolation::ExtraDataLength { len }),
            "length {len}"
        );
    }
    let longer = [bytes.as_ref(), &[0]].concat();
    assert_eq!(decode_extra_data(&longer), Err(RuleViolation::ExtraDataLength { len: 30 }));
    assert_eq!(decode_extra_data(&[]), Err(RuleViolation::ExtraDataLength { len: 0 }));
}

/// The base-fee sharing byte is a header field every Etna block carries as 100: a header with
/// 99 there differs from the derived header, and no decoder accepts it either.
#[test]
fn pctg_99_is_a_header_mismatch() {
    let e = non_genesis_expected();
    let mut bytes = e.extra_data.to_vec();
    bytes[0] = 99;
    let h = Header { extra_data: bytes.clone().into(), ..header_for(&e) };
    assert!(
        matches!(check_header(&h, &e), Err(RuleViolation::HeaderField { field: "extra_data", .. })),
        "{:?}",
        check_header(&h, &e)
    );
    assert_eq!(
        decode_extra_data(&bytes),
        Err(RuleViolation::HeaderField {
            field: "extra_data",
            expected: "100".into(),
            got: "99".into(),
        })
    );
}

#[test]
fn encode_extra_data_rejects_uint48_overflow() {
    assert_eq!(
        encode_extra_data(&extra(UINT48_MAX + 1, 1, 0)),
        Err(RuleViolation::ExtraDataOverflow { field: "generation", value: UINT48_MAX + 1 })
    );
    assert_eq!(
        encode_extra_data(&extra(1, u64::MAX, 0)),
        Err(RuleViolation::ExtraDataOverflow { field: "anchor", value: u64::MAX })
    );
}

// ---------------------------------------------------------------------------------------------
// expected_header
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
            beneficiary: Address::repeat_byte(0x77),
            extra_data: Bytes::from(
                hex!("64" "000000000002" "0000000001f4" "00000000000000000000000000000000")
                    .to_vec()
            ),
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
    assert_eq!(e.beneficiary, Address::repeat_byte(0x77));
    assert_eq!(decode_extra_data(&e.extra_data), Ok(extra(GENERATION, 500, 0)));
    assert_eq!(e.parent_beacon_block_root, a.state_root);
    assert_eq!(e.gas_limit, params.block_gas_limit);
    // 30M used against a 22.5M target adjusted to 11.25M for a 2 s block under Etna's 4 s
    // target (ENC-A-10a): 10_000_000 + floor(10_000_000·18.75M/22.5M/8).
    assert_eq!(e.base_fee, 11_041_666);
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

/// The base fee `expected_header` derives at height 1,001 for a parent at 1,000 with a 30M gas
/// limit, `gas_used`, `base_fee` and the parent's own interval `interval` s, on `chain_id`.
fn etna_base_fee(chain_id: u64, base_fee: u64, gas_used: u64, interval: u64) -> u64 {
    let (a, params) = (anchor(500, 0), devnet());
    let p = ParentInfo {
        gas_limit: 30_000_000,
        gas_used,
        base_fee,
        timestamp: 1_760_000_100,
        grandparent_timestamp: 1_760_000_100 - interval,
        ..parent(1_000)
    };
    let i = HeaderInputs {
        min_base_fee: min_base_fee_for_chain(chain_id),
        ..inputs(1_001, &p, &a, &params)
    };
    expected_header(&i).unwrap().base_fee
}

/// ENC-A-10a (vectors 10a.a..m): Etna blocks, S + 1 included, adjust the base fee for a 4 s
/// target from the parent's own interval and header gas values, with every division floored and
/// the result clamped to [minBaseFee, 1 gwei].
#[test]
fn expected_header_base_fee_matches_the_enc_a_10a_vectors() {
    const MAINNET: u64 = 167_000;
    // 10a.a..g at a 4 s or 8 s parent interval.
    assert_eq!(etna_base_fee(MAINNET, 100_000_000, 15_000_000, 4), 100_000_000, "10a.a");
    assert_eq!(etna_base_fee(MAINNET, 100_000_000, 30_000_000, 4), 112_500_000, "10a.b");
    assert_eq!(etna_base_fee(MAINNET, 100_000_000, 15_000_000, 8), 88_750_000, "10a.c");
    assert_eq!(etna_base_fee(MAINNET, 10_000_000, 0, 4), 10_000_000, "10a.d");
    assert_eq!(etna_base_fee(TAIKO_DEVNET_CHAIN_ID, 10_000_000, 0, 4), 8_750_000, "10a.e");
    assert_eq!(etna_base_fee(MAINNET, 10_000_000, 15_000_001, 4), 10_000_001, "10a.f");
    assert_eq!(etna_base_fee(MAINNET, 950_000_000, 30_000_000, 4), 1_000_000_000, "10a.g");
    // 10a.k, 10a.l at a 2 s parent interval.
    assert_eq!(etna_base_fee(MAINNET, 100_000_000, 7_500_000, 2), 100_000_000, "10a.k");
    assert_eq!(etna_base_fee(MAINNET, 100_000_000, 15_000_000, 2), 106_250_000, "10a.l");
    // 10a.i: delta = 100,000,007 × 15M / 15M / 8 = 12,500,000.875 floors to 12,500,000.
    assert_eq!(etna_base_fee(MAINNET, 100_000_007, 30_000_000, 4), 112_500_007, "10a.i");
    // 10a.m: Unzen's 2 s target would turn 10a.a into 88,750,000.
    assert_eq!(
        protocol::shasta::constants::calculate_next_block_eip4396_base_fee_from_parent_values(
            1_000,
            30_000_000,
            15_000_000,
            4,
            100_000_000,
            min_base_fee_for_chain(MAINNET),
        ),
        88_750_000,
        "10a.m"
    );
}

/// ENC-A-10a (10a.h, 10a.j): the interval is the parent's timestamp minus the grandparent's, not
/// the block's own, and `target` uses the parent header's full gas limit.
#[test]
fn expected_header_base_fee_uses_the_parent_interval_and_gas_limit() {
    let (a, params) = (anchor(500, 0), devnet());
    let p = ParentInfo {
        gas_limit: 30_000_000,
        gas_used: 15_000_000,
        base_fee: 100_000_000,
        timestamp: BFT_SECS - 8,
        grandparent_timestamp: BFT_SECS - 12,
        ..parent(1_000)
    };
    let i = HeaderInputs {
        min_base_fee: min_base_fee_for_chain(167_000),
        ..inputs(1_001, &p, &a, &params)
    };
    let e = expected_header(&i).unwrap();
    // The block lands 8 s after its parent; the parent's own 4 s interval sets 10a.a's value.
    assert_eq!(e.timestamp - p.timestamp, 8);
    assert_eq!(e.base_fee, 100_000_000);
    // A 45M parent gas limit moves the target: the derived fee follows the header value.
    let wide = ParentInfo { gas_limit: 45_000_000, ..p };
    let i = HeaderInputs {
        min_base_fee: min_base_fee_for_chain(167_000),
        ..inputs(1_001, &wide, &a, &params)
    };
    assert_ne!(expected_header(&i).unwrap().base_fee, 100_000_000);
}

/// ENC-A-10b (vector 10b.a): `mixHash = keccak256(abi.encode(bytes32(p.difficulty),
/// uint256(b.number)))`, two 32-byte words, for a parent difficulty of 1,000,000 at block 12345.
#[test]
fn expected_header_mix_hash_matches_vector_10b_a() {
    let (a, params) = (anchor(500, 0), devnet());
    let p = ParentInfo { difficulty: U256::from(1_000_000u64), ..parent(12_344) };
    assert_eq!(
        expected_header(&inputs(12_345, &p, &a, &params)).unwrap().mix_hash,
        b256!("05a173eee05e0e03682acaef0ca4dea2f32b47cd3e10eed85233465b524d4507")
    );
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
fn expected_header_carries_the_supplied_bitmap() {
    let (p, a, params) = (parent(10), anchor(500, 0), devnet());
    let i = HeaderInputs { miss_bitmap: 5, ..inputs(11, &p, &a, &params) };
    let e = expected_header(&i).expect("derives");
    assert_eq!(e.extra_data.len(), EXTRA_DATA_LEN);
    assert_eq!(e.extra_data[28], 5);
    assert_eq!(e.extra_data[13..28], [0u8; 15]);
    assert_eq!(decode_extra_data(&e.extra_data), Ok(extra(GENERATION, 500, 5)));
    // Seat 127 is the high bit of byte 13.
    let i = HeaderInputs { miss_bitmap: 1 << 127, ..inputs(11, &p, &a, &params) };
    assert_eq!(expected_header(&i).unwrap().extra_data[13], 0x80);
}

#[test]
fn expected_header_rejects_a_generation_beyond_uint48() {
    let (p, a, params) = (parent(10), anchor(500, 0), devnet());
    let i = HeaderInputs { generation: UINT48_MAX + 1, ..inputs(11, &p, &a, &params) };
    assert_eq!(
        expected_header(&i),
        Err(RuleViolation::ExtraDataOverflow { field: "generation", value: UINT48_MAX + 1 })
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
    let cases: [(&str, Mutation); 17] = [
        ("number", |h| h.number += 1),
        ("parent_hash", |h| h.parent_hash = B256::repeat_byte(0x99)),
        ("timestamp", |h| h.timestamp += 1),
        ("beneficiary", |h| h.beneficiary = Address::repeat_byte(0x99)),
        ("extra_data", |h| h.extra_data = encode_extra_data(&extra(GENERATION, 501, 0)).unwrap()),
        ("extra_data", |h| h.extra_data = encode_extra_data(&extra(GENERATION, 500, 1)).unwrap()),
        ("extra_data", |h| {
            let mut bytes = h.extra_data.to_vec();
            bytes[0] = 50;
            h.extra_data = bytes.into();
        }),
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

/// A proposer controls header fields such as `extraData` (up to the block size): a violation
/// keeps at most [`HEADER_FIELD_DEBUG_MAX`] characters of a rendered value, so a hostile header
/// cannot blow up error strings and log lines.
#[test]
fn header_field_violations_bound_a_huge_proposed_value() {
    let huge = Bytes::from(vec![0xab; 100_000]);
    let e = non_genesis_expected();
    let h = Header { extra_data: huge.clone(), ..header_for(&e) };
    let Err(RuleViolation::HeaderField { field, expected, got }) = check_header(&h, &e) else {
        panic!("expected a HeaderField violation");
    };
    assert_eq!(field, "extra_data");
    assert_eq!(expected, format!("{:?}", e.extra_data), "a short value stays whole");
    assert_eq!(got.chars().count(), HEADER_FIELD_DEBUG_MAX + 1, "the bound plus the ellipsis");
    assert!(got.ends_with('…'), "{got}");
    assert!(format!("{huge:?}").starts_with(got.trim_end_matches('…')), "a prefix is kept");
    let message = check_header(&h, &e).unwrap_err().to_string();
    assert!(message.len() < 4 * HEADER_FIELD_DEBUG_MAX, "{} bytes", message.len());
}

/// Both rendered values are bounded; one of exactly the bound is kept whole.
#[test]
fn header_field_bounds_both_values() {
    let huge = Bytes::from(vec![0xcd; 1_000]);
    let exact = "x".repeat(HEADER_FIELD_DEBUG_MAX - 2); // `Debug` adds the two quotes
    let one_more = "x".repeat(HEADER_FIELD_DEBUG_MAX - 1);
    match RuleViolation::header_field("f", &huge, &exact) {
        RuleViolation::HeaderField { field, expected, got } => {
            assert_eq!(field, "f");
            assert_eq!(expected.chars().count(), HEADER_FIELD_DEBUG_MAX + 1);
            assert!(expected.ends_with('…'));
            assert_eq!(got, format!("{exact:?}"));
            assert_eq!(got.chars().count(), HEADER_FIELD_DEBUG_MAX);
        }
        other => panic!("{other:?}"),
    }
    match RuleViolation::header_field("f", &one_more, &huge) {
        RuleViolation::HeaderField { expected, got, .. } => {
            // One character over: the closing quote gives way to the ellipsis.
            assert_eq!(expected, format!("\"{}…", "x".repeat(HEADER_FIELD_DEBUG_MAX - 1)));
            assert_eq!(got.chars().count(), HEADER_FIELD_DEBUG_MAX + 1);
        }
        other => panic!("{other:?}"),
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
    let attrs = payload_attributes(&e, anchor_hash, None);

    let eth = &attrs.payload_attributes;
    assert_eq!(eth.timestamp, e.timestamp);
    assert_eq!(eth.prev_randao, e.mix_hash);
    assert_eq!(eth.suggested_fee_recipient, e.beneficiary);
    assert_eq!(eth.suggested_fee_recipient, Address::repeat_byte(0x77));
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

/// A forced inclusion block's attributes carry its explicit transaction list (the EL builds
/// from it alone) and mark the L1 origin forced; the list enters the payload id, every other
/// field is the ordinary block's.
#[test]
fn payload_attributes_carry_a_forced_inclusion_tx_list() {
    let e = non_genesis_expected();
    let anchor_hash = B256::repeat_byte(0xa1);
    let tx_list = Bytes::from_static(&[0xc2, 0x01, 0x02]);
    let ordinary = payload_attributes(&e, anchor_hash, None);
    let forced = payload_attributes(&e, anchor_hash, Some(tx_list.clone()));

    assert_eq!(forced.block_metadata.tx_list, Some(tx_list));
    assert!(forced.l1_origin.is_forced_inclusion);
    assert_ne!(forced.l1_origin.build_payload_args_id, ordinary.l1_origin.build_payload_args_id);

    let mut expected = ordinary;
    expected.block_metadata.tx_list = forced.block_metadata.tx_list.clone();
    expected.l1_origin.is_forced_inclusion = true;
    expected.l1_origin.build_payload_args_id = forced.l1_origin.build_payload_args_id;
    assert_eq!(forced, expected);
}

#[test]
fn payload_attributes_id_depends_on_the_parent_hash() {
    let e = non_genesis_expected();
    let other = ExpectedHeader { parent_hash: B256::repeat_byte(0x42), ..e.clone() };
    assert_ne!(
        payload_attributes(&e, B256::ZERO, None).l1_origin.build_payload_args_id,
        payload_attributes(&other, B256::ZERO, None).l1_origin.build_payload_args_id
    );
}

// ---------------------------------------------------------------------------------------------
// anchor progress, back-pressure, generation
// ---------------------------------------------------------------------------------------------

/// `L1_0`, the Etna initialization block of the anchor progress tests.
const L1_0: u64 = 50;

#[test]
fn anchor_progress_accepts_monotone_anchors_at_or_after_activation() {
    // Same anchor as the parent, at L1_0.
    check_anchor_progress(L1_0, L1_0, L1_0).unwrap();
    // A moving anchor.
    check_anchor_progress(55, 58, L1_0).unwrap();
    // An unchanged anchor, however far the chain has advanced since it.
    check_anchor_progress(70, 70, L1_0).unwrap();
    check_anchor_progress(u64::MAX, u64::MAX, L1_0).unwrap();
}

#[test]
fn anchor_progress_rejects_a_regression() {
    assert_eq!(
        check_anchor_progress(60, 59, L1_0),
        Err(RuleViolation::AnchorRegressed { parent: 60, anchor: 59 })
    );
}

#[test]
fn anchor_progress_rejects_an_anchor_before_activation() {
    assert_eq!(
        check_anchor_progress(40, 49, L1_0),
        Err(RuleViolation::AnchorBeforeActivation { anchor: 49, origin: L1_0 })
    );
}

#[test]
fn back_pressure_boundary() {
    check_back_pressure(110, 100, 10).expect("depth == limit is allowed");
    assert_eq!(
        check_back_pressure(111, 100, 10),
        Err(RuleViolation::BackPressure { depth: 11, limit: 10 })
    );
    check_back_pressure(100, 100, 0).expect("depth 0 with limit 0");
    check_back_pressure(90, 100, 0).expect("a checkpoint ahead of the height saturates to 0");
}

#[test]
fn checkpoint_at_or_below_the_parent_matching_the_local_block_is_accepted() {
    let hash = B256::repeat_byte(0x5a);
    check_checkpoint(10, 10, hash, hash).expect("checkpoint at the parent");
    check_checkpoint(10, 4, hash, hash).expect("checkpoint below the parent");
    check_checkpoint(0, 0, hash, hash).expect("genesis checkpoint");
    check_checkpoint_height(10, 10).expect("height half at the parent");
}

#[test]
fn checkpoint_above_the_parent_is_rejected() {
    let expected = Err(RuleViolation::CheckpointAboveParent { checkpoint: 11, parent: 10 });
    assert_eq!(check_checkpoint_height(10, 11), expected);
    let hash = B256::repeat_byte(0x5a);
    assert_eq!(check_checkpoint(10, 11, hash, hash), expected, "even when the hashes agree");
}

#[test]
fn checkpoint_hash_differing_from_the_local_block_is_rejected() {
    let (proven, local) = (B256::repeat_byte(0x5a), B256::repeat_byte(0x5b));
    let violation = check_checkpoint(10, 6, proven, local).unwrap_err();
    assert_eq!(violation, RuleViolation::CheckpointConflict { height: 6, proven, local });
    assert!(violation.is_checkpoint_conflict());
    assert!(!RuleViolation::BackPressure { depth: 1, limit: 0 }.is_checkpoint_conflict());
}

#[test]
fn anchor_freshness_accepts_age_equal_to_max() {
    check_anchor_freshness(1_760_007_300, 1_760_000_100, 7_200).expect("age == max is allowed");
    check_anchor_freshness(1_760_000_100, 1_760_000_100, 7_200).expect("age 0");
    check_anchor_freshness(100, 200, 0).expect("an anchor newer than the block saturates to 0");
}

#[test]
fn anchor_freshness_rejects_age_one_past_max() {
    assert_eq!(
        check_anchor_freshness(1_760_007_301, 1_760_000_100, 7_200),
        Err(RuleViolation::AnchorTooOld { age: 7_201, max: 7_200 })
    );
    assert_eq!(
        check_anchor_freshness(u64::MAX, 0, u64::MAX - 1),
        Err(RuleViolation::AnchorTooOld { age: u64::MAX, max: u64::MAX - 1 })
    );
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
// planned stop
// ---------------------------------------------------------------------------------------------

/// START-10.1-14d: with `stopTime` set at its anchor, a block is invalid exactly when its
/// parent's timestamp is at least `stopTime`, at any height.
#[test]
fn planned_stop_boundary() {
    let stop_time = 1_760_000_100;
    let schedule = U256::from(stop_time) << 144;
    for number in [7, 13, 1_000_001] {
        let mut parent = parent(number);
        parent.timestamp = stop_time;
        assert_eq!(
            check_rules_schedule(schedule, &parent, stop_time + 1),
            Err(RuleViolation::PlannedStop { parent_height: number }),
            "parent {number} at stopTime"
        );
        parent.timestamp = stop_time - 1;
        assert_eq!(
            check_rules_schedule(schedule, &parent, stop_time),
            Ok(()),
            "parent {number} at stopTime - 1"
        );
    }
    // stopTime 0 means no stop.
    assert_eq!(check_rules_schedule(U256::ZERO, &parent(7), BFT_SECS), Ok(()));
}

// ---------------------------------------------------------------------------------------------
// chain id
// ---------------------------------------------------------------------------------------------

#[test]
fn chain_id_fits_cometbft_max_len() {
    assert!(chain_id_for(&devnet(), (1 << 48) - 1).unwrap().len() <= MAX_CHAIN_ID_LEN);
    assert_eq!(MAX_CHAIN_ID_LEN, 50);
}

// ---------------------------------------------------------------------------------------------
// labels
// ---------------------------------------------------------------------------------------------

/// One value of every [`RuleViolation`] variant.
fn every_violation() -> Vec<RuleViolation> {
    let all = vec![
        RuleViolation::UnsupportedRuleset { rules: 1 },
        RuleViolation::PlannedStop { parent_height: 6 },
        RuleViolation::HeightMismatch { height: 2, parent: 0 },
        RuleViolation::HeaderField { field: "number", expected: "1".into(), got: "2".into() },
        RuleViolation::ExtraDataOverflow { field: "generation", value: u64::MAX },
        RuleViolation::ExtraDataLength { len: 7 },
        RuleViolation::BaseFeeUnavailable { parent: 1 },
        RuleViolation::AnchorRegressed { parent: 2, anchor: 1 },
        RuleViolation::AnchorBeforeActivation { anchor: 1, origin: 2 },
        RuleViolation::AnchorTooOld { age: 7_201, max: 7_200 },
        RuleViolation::BackPressure { depth: 11, limit: 10 },
        RuleViolation::GenerationMismatch { chain: 1, extra: 2 },
        RuleViolation::GenerationAhead { chain: 2, inbox: 1 },
        RuleViolation::MissBitmap { expected: 8, got: 0 },
        RuleViolation::InvalidChainId { chain_id: "x".into(), l2_chain_id: 1 },
        RuleViolation::CheckpointAboveParent { checkpoint: 2, parent: 1 },
        RuleViolation::CheckpointConflict {
            height: 1,
            proven: B256::repeat_byte(1),
            local: B256::repeat_byte(2),
        },
    ];
    // Exhaustiveness guard: adding a variant without listing it above fails to compile here.
    for v in &all {
        match v {
            RuleViolation::UnsupportedRuleset { .. } | RuleViolation::PlannedStop { .. } => {}
            RuleViolation::HeightMismatch { .. } |
            RuleViolation::HeaderField { .. } |
            RuleViolation::ExtraDataOverflow { .. } |
            RuleViolation::ExtraDataLength { .. } |
            RuleViolation::BaseFeeUnavailable { .. } |
            RuleViolation::AnchorRegressed { .. } |
            RuleViolation::AnchorBeforeActivation { .. } |
            RuleViolation::AnchorTooOld { .. } |
            RuleViolation::BackPressure { .. } |
            RuleViolation::GenerationMismatch { .. } |
            RuleViolation::GenerationAhead { .. } |
            RuleViolation::MissBitmap { .. } |
            RuleViolation::InvalidChainId { .. } |
            RuleViolation::CheckpointAboveParent { .. } |
            RuleViolation::CheckpointConflict { .. } => {}
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

#[test]
fn v1_proposer_receives_all_basefees() {
    assert_eq!(encode_extra_data(&extra(0, 42, 0)).unwrap()[0], 100);
}

#[test]
fn v1_all_engine_builds_are_byte_bounded() {
    let header = non_genesis_expected();
    for tx_list in [None, Some(Bytes::new())] {
        let attrs = payload_attributes(&header, B256::ZERO, tx_list);
        assert_eq!(serde_json::to_value(attrs).unwrap()["maxBlockBytes"], 124000);
    }
}

#[test]
fn v1_domain_matches_schema4_vector() {
    let mut params = devnet();
    params.inbox = Address::repeat_byte(0x11);
    assert_eq!(
        chain_id_for(&params, 0).unwrap(),
        "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4"
    );
}
