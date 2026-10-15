use super::*;
use crate::{
    forced::ForcedError,
    test_utils::{TestState, sample_transactions},
    types::{AnchorState, InboxFacts},
};
use alloy_consensus::{SignableTransaction, TxEnvelope, TxLegacy};
use alloy_eips::eip2718::Encodable2718;
use alloy_primitives::{Address, B256, Bytes, TxKind, U256, address, keccak256};
use alloy_rlp::Decodable;

const INBOX: Address = address!("00000000000000000000000000000000e7a10001");
const T0: u64 = 1_760_000_000;
const DELAY: u64 = 3_600;
const INDEX: u64 = 7;

fn fixture(tx: Bytes) -> (AnchorState, ForcedWitness) {
    let slots = entry_slots(INDEX);
    let metadata = U256::from(T0) | (U256::from(70) << 48) | (U256::from(1_000) << 112);
    let state = TestState::new(vec![(
        INBOX,
        1,
        U256::ZERO,
        keccak256(b"code"),
        vec![(slots[0], U256::from_be_bytes(keccak256(&tx).0)), (slots[1], metadata)],
    )]);
    let anchor = AnchorState {
        number: 70,
        hash: B256::repeat_byte(0xa7),
        state_root: state.state_root(),
        timestamp: T0 + DELAY,
        inbox: InboxFacts {
            status: 3,
            recovery_generation: 0,
            last_checkpoint_height: 0,
            last_checkpoint_hash: B256::ZERO,
            forced_inclusion_head: 0,
            forced_inclusion_tail: INDEX + 1,
        },
    };
    let w = ForcedWitness { index: INDEX, entry: state.witness(INBOX, &slots), tx };
    (anchor, w)
}

fn context(anchor: &AnchorState) -> ForcedContext<'_> {
    ForcedContext { cursor: INDEX, anchor, delay: DELAY, inbox: INBOX }
}

fn canonical_tx() -> Bytes {
    sample_transactions()[0].encoded_2718().into()
}

#[test]
fn calldata_due_arithmetic_does_not_saturate_into_due() {
    assert!(!is_due(1, u64::MAX, u64::MAX));
    assert!(is_due(10, 20, 30));
    assert!(!is_due(10, 20, 29));
}

#[test]
fn canonical_decoder_accepts_exact_legacy_and_typed_transactions() {
    for tx in sample_transactions() {
        assert_eq!(decode_canonical(&tx.encoded_2718()), Some(tx));
    }
}

#[test]
fn canonical_decoder_rejects_empty_malformed_and_trailing_bytes() {
    for bytes in [vec![], vec![0xff], vec![0x02], vec![0xc0]] {
        assert!(decode_canonical(&bytes).is_none());
    }
    for tx in sample_transactions() {
        let mut bytes = tx.encoded_2718();
        bytes.push(0);
        assert!(decode_canonical(&bytes).is_none());
    }
}

#[test]
fn canonical_decoder_rejects_network_wrapped_typed_bytes() {
    let bytes = sample_transactions()[1].encoded_2718();
    assert!(decode_canonical(&alloy_rlp::encode(bytes.as_slice())).is_none());
}

#[test]
fn entry_slots_match_solidity_mapping_layout() {
    // Independently assembled abi.encode(uint256(7), uint256(280)).
    let mut preimage = [0; 64];
    preimage[31] = 7;
    preimage[62] = 1;
    preimage[63] = 24;
    let base = keccak256(preimage);
    assert_eq!(entry_slots(INDEX), [base, B256::from(U256::from_be_bytes(base.0) + U256::from(1))]);
    assert_ne!(entry_slots(INDEX), entry_slots(INDEX + 1));
}

#[test]
fn authenticated_entry_decodes_packed_metadata() {
    let (anchor, w) = fixture(canonical_tx());
    assert_eq!(
        verify_entry(anchor.state_root, &w.entry, INBOX, INDEX).unwrap(),
        ForcedEntry {
            index: INDEX,
            tx_hash: keccak256(&w.tx),
            timestamp: T0,
            l1_block: 70,
            fee_in_gwei: 1_000,
        }
    );
}

#[test]
fn authenticated_entry_masks_field_widths_and_ignores_padding() {
    let slots = entry_slots(INDEX);
    let timestamp = (1_u64 << 48) - 1;
    let state = TestState::new(vec![(
        INBOX,
        1,
        U256::ZERO,
        keccak256(b"code"),
        vec![(slots[0], U256::from(1)), (slots[1], U256::MAX)],
    )]);
    let w = state.witness(INBOX, &slots);
    let e = verify_entry(state.state_root(), &w, INBOX, INDEX).unwrap();
    assert_eq!((e.timestamp, e.l1_block, e.fee_in_gwei), (timestamp, u64::MAX, u64::MAX));
}

#[test]
fn rule_rejects_missing_witness_for_pending_entry() {
    let (anchor, _) = fixture(canonical_tx());
    assert_eq!(
        check(context(&anchor), None, None),
        Err(ForcedError::MissingWitness { index: INDEX })
    );
}

#[test]
fn rule_allows_no_witness_only_after_tail_and_rejects_extra_witness() {
    let (mut anchor, w) = fixture(canonical_tx());
    anchor.inbox.forced_inclusion_tail = INDEX;
    assert_eq!(check(context(&anchor), None, None), Ok(ForcedDecision::Ordinary));
    assert_eq!(check(context(&anchor), Some(&w), None), Err(ForcedError::UnexpectedWitness));
    anchor.inbox.forced_inclusion_tail = INDEX - 1;
    assert_eq!(check(context(&anchor), None, None), Ok(ForcedDecision::Ordinary));
}

#[test]
fn rule_rejects_wrong_index() {
    let (anchor, mut w) = fixture(canonical_tx());
    w.index += 1;
    assert_eq!(
        check(context(&anchor), Some(&w), None),
        Err(ForcedError::WrongIndex { expected: INDEX, got: INDEX + 1 })
    );
}

#[test]
fn rule_rejects_wrong_account_and_state_root() {
    let (anchor, w) = fixture(canonical_tx());
    let mut other = w.clone();
    other.entry.address = Address::repeat_byte(0x42);
    assert!(matches!(check(context(&anchor), Some(&other), None), Err(ForcedError::Entry(_))));
    let mut anchor = anchor;
    anchor.state_root = B256::repeat_byte(0x99);
    assert!(matches!(check(context(&anchor), Some(&w), None), Err(ForcedError::Entry(_))));
}

#[test]
fn rule_rejects_wrong_slot_set_or_tampered_proofs() {
    let (anchor, w) = fixture(canonical_tx());
    let mut mutations = Vec::new();
    let mut other = w.clone();
    other.entry.storage[0].slot = B256::ZERO;
    mutations.push(other);
    let mut other = w.clone();
    other.entry.storage.swap(0, 1);
    mutations.push(other);
    let mut other = w.clone();
    other.entry.storage.pop();
    mutations.push(other);
    let mut other = w.clone();
    other.entry.storage.push(other.entry.storage[0].clone());
    mutations.push(other);
    let mut other = w.clone();
    other.entry.storage[0].value += U256::from(1);
    mutations.push(other);
    let mut other = w;
    other.entry.storage[1].proof.clear();
    mutations.push(other);
    for other in mutations {
        assert!(matches!(check(context(&anchor), Some(&other), None), Err(ForcedError::Entry(_))));
    }
}

#[test]
fn rule_rejects_bytes_not_matching_authenticated_hash_even_before_due() {
    let (mut anchor, mut w) = fixture(canonical_tx());
    anchor.timestamp = T0;
    let expected = keccak256(&w.tx);
    w.tx = Bytes::from_static(&[0xff]);
    assert_eq!(
        check(context(&anchor), Some(&w), Some(&w.tx)),
        Err(ForcedError::TxHashMismatch { expected, got: keccak256(&w.tx) })
    );
}

#[test]
fn rule_rejects_8193_bytes_before_classification() {
    let (anchor, w) = fixture(vec![0; 8193].into());
    assert_eq!(
        check(context(&anchor), Some(&w), None),
        Err(ForcedError::TxTooLarge { size: 8193, max: 8192 })
    );
}

#[test]
fn rule_accepts_8192_invalid_bytes_as_due_skip() {
    let (anchor, w) = fixture(vec![0; 8192].into());
    assert_eq!(check(context(&anchor), Some(&w), None), Ok(ForcedDecision::SkippedInvalid(INDEX)));
}

#[test]
fn rule_does_not_skip_invalid_input_early_even_if_first_tx_matches() {
    for bytes in [Bytes::new(), Bytes::from_static(&[0xff])] {
        let (mut anchor, w) = fixture(bytes);
        anchor.timestamp -= 1;
        assert_eq!(check(context(&anchor), Some(&w), Some(&w.tx)), Ok(ForcedDecision::Ordinary));
    }
}

#[test]
fn rule_skips_empty_and_undecodable_input_at_inclusive_due_boundary() {
    for bytes in [Bytes::new(), Bytes::from_static(&[0xff])] {
        let (anchor, w) = fixture(bytes);
        assert_eq!(
            check(context(&anchor), Some(&w), Some(&w.tx)),
            Ok(ForcedDecision::SkippedInvalid(INDEX))
        );
    }
}

#[test]
fn rule_includes_canonical_first_transaction_early_due_and_without_expiry() {
    for tx in sample_transactions() {
        let (mut anchor, w) = fixture(tx.encoded_2718().into());
        for timestamp in [T0, T0 + DELAY - 1, T0 + DELAY, u64::MAX] {
            anchor.timestamp = timestamp;
            assert_eq!(
                check(context(&anchor), Some(&w), Some(&w.tx)),
                Ok(ForcedDecision::Included(INDEX))
            );
        }
    }
}

#[test]
fn rule_requires_skip_for_due_canonical_tx_absent_from_position_zero() {
    let (mut anchor, w) = fixture(canonical_tx());
    // An absent first transaction also covers an empty candidate block.
    for first in [None, Some(&[0xff][..])] {
        for timestamp in [T0 + DELAY, u64::MAX] {
            anchor.timestamp = timestamp;
            assert_eq!(
                check(context(&anchor), Some(&w), first),
                Ok(ForcedDecision::NeedsSkip { index: INDEX, tx: w.tx.clone() })
            );
        }
    }
}

#[test]
fn rule_does_not_count_same_nonce_replacement_or_later_transaction_as_inclusion() {
    let original = TxLegacy {
        nonce: 3,
        gas_price: 10,
        gas_limit: 21_000,
        to: TxKind::Call(INBOX),
        ..Default::default()
    };
    let replacement = TxLegacy { gas_price: 11, ..original.clone() };
    let signer = protocol::FixedKSigner::golden_touch().unwrap();
    let sign = |tx: TxLegacy| -> TxEnvelope {
        let signature = signer.sign_with_predefined_k(&tx.signature_hash().0).unwrap().signature;
        tx.into_signed(signature).into()
    };
    let tx = sign(original);
    let replacement = sign(replacement);
    let (anchor, w) = fixture(tx.encoded_2718().into());
    let block = [replacement.encoded_2718(), w.tx.to_vec()];
    assert_eq!(
        check(context(&anchor), Some(&w), Some(&block[0])),
        Ok(ForcedDecision::NeedsSkip { index: INDEX, tx: w.tx.clone() })
    );
}

#[test]
fn rule_allows_ordinary_block_when_canonical_entry_not_due_and_not_first() {
    let (mut anchor, w) = fixture(canonical_tx());
    anchor.timestamp -= 1;
    assert_eq!(check(context(&anchor), Some(&w), None), Ok(ForcedDecision::Ordinary));
}

#[test]
fn rule_does_not_saturate_large_delay_into_due() {
    let (mut anchor, w) = fixture(Bytes::new());
    anchor.timestamp = u64::MAX;
    let context = ForcedContext { delay: u64::MAX, ..context(&anchor) };
    assert_eq!(check(context, Some(&w), None), Ok(ForcedDecision::Ordinary));
}

#[test]
fn witness_rlp_round_trips_authenticated_entry_and_exact_bytes() {
    let (_, w) = fixture(canonical_tx());
    let bytes = alloy_rlp::encode(&w);
    let mut remaining = bytes.as_slice();
    assert_eq!(ForcedWitness::decode(&mut remaining).unwrap(), w);
    assert!(remaining.is_empty());
}

#[test]
fn witness_rlp_rejects_tx_above_protocol_byte_cap() {
    let (_, witness) = fixture(vec![0x42; MAX_FORCED_TX_BYTES + 1].into());
    let encoded = alloy_rlp::encode(&witness);
    assert_eq!(
        ForcedWitness::decode(&mut encoded.as_slice()),
        Err(alloy_rlp::Error::Custom("forced transaction exceeds byte limit"))
    );
}

#[test]
fn witness_rlp_accepts_empty_invalid_bytes_and_exact_byte_cap() {
    for size in [0, 1, MAX_FORCED_TX_BYTES] {
        let (_, witness) = fixture(vec![0x42; size].into());
        let mut encoded = alloy_rlp::encode(&witness);
        encoded.push(0x80);
        let mut remaining = encoded.as_slice();
        assert_eq!(ForcedWitness::decode(&mut remaining).unwrap(), witness);
        assert_eq!(remaining, &[0x80], "only the witness is consumed");
    }
}

#[test]
fn witness_rlp_rejects_missing_list_tx_list_truncation_and_extra_fields() {
    let (_, witness) = fixture(Bytes::new());
    let mut fields = alloy_rlp::encode(witness.index);
    fields.extend(alloy_rlp::encode(&witness.entry));
    let wrap = |payload: &[u8]| {
        let mut encoded = Vec::new();
        alloy_rlp::Header { list: true, payload_length: payload.len() }.encode(&mut encoded);
        encoded.extend(payload);
        encoded
    };
    for suffix in [vec![], vec![0xc0], vec![0xb8, 56], vec![0x80, 0x80]] {
        let mut payload = fields.clone();
        payload.extend(suffix);
        assert!(ForcedWitness::decode(&mut wrap(&payload).as_slice()).is_err());
    }
    assert!(ForcedWitness::decode(&mut &[0x80][..]).is_err());
    let mut encoded = alloy_rlp::encode(&witness);
    encoded.pop();
    assert!(ForcedWitness::decode(&mut encoded.as_slice()).is_err());
}
