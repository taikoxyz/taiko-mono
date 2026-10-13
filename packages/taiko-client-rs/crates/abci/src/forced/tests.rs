use super::*;
use crate::{
    l1::layout::inbox,
    test_utils::{
        InboxStorage, TestState, blob_versioned_hash, filler_accounts, forced_blob, inbox_account,
        manifest_payload, sample_genesis_record, sample_transactions,
    },
    types::InboxFacts,
};
use alloy_consensus::{SignableTransaction, TxEnvelope, TxLegacy};
use alloy_eips::{eip2718::Encodable2718, eip4844::BYTES_PER_BLOB};
use alloy_primitives::{Signature, address};
use protocol::shasta::manifest::{BlockManifest, DerivationSourceManifest};

/// The Inbox of the tests.
const INBOX: Address = address!("00000000000000000000000000000000e7a10001");
/// Timestamp of the first planted entry.
const T0: u64 = 1_760_000_000;
/// The forced inclusion delay `D` of the tests (the sample genesis record's).
const DELAY: u64 = 3_600;
/// Expiry `E`.
const EXPIRY: u64 = FORCED_INCLUSION_EXPIRY_SECS;

/// An Inbox entry at `index` committing to the blob with versioned hash `blob_hash`, submitted at
/// `timestamp`, its manifest at byte `offset` of the decoded blob.
fn entry(index: u64, blob_hash: B256, offset: u32, timestamp: u64) -> ForcedEntry {
    ForcedEntry { index, fee_in_gwei: 1_000 + index, blob_hash, offset, timestamp }
}

/// An L1 state whose Inbox holds `entries` and the queue tail `tail`.
fn queue_state(entries: &[ForcedEntry], tail: u64) -> TestState {
    let storage = InboxStorage {
        forced_inclusion_tail: tail,
        forced_inclusion_queue: entries.to_vec(),
        ..InboxStorage::genesis(sample_genesis_record(), B256::repeat_byte(0xe0))
    };
    let mut accounts = filler_accounts();
    accounts.push(inbox_account(INBOX, &storage));
    TestState::new(accounts)
}

/// A block anchor over `state` at `timestamp` whose Inbox tail is `tail`.
fn anchor(state: &TestState, timestamp: u64, tail: u64) -> AnchorState {
    AnchorState {
        number: 70,
        hash: B256::repeat_byte(0xa7),
        state_root: state.state_root(),
        timestamp,
        inbox: InboxFacts {
            status: inbox::ETNA_ACTIVE,
            recovery_generation: 0,
            last_checkpoint_height: 0,
            last_checkpoint_hash: B256::ZERO,
            forced_inclusion_head: 0,
            forced_inclusion_tail: tail,
        },
    }
}

/// A forced inclusion witness proving entry `index` in `state`, carrying `blob`.
fn witness(state: &TestState, index: u64, blob: Bytes) -> ForcedWitness {
    ForcedWitness {
        index,
        entry: state.witness(INBOX, &inbox::forced_inclusion_entry_slots(index)),
        blob,
    }
}

/// One pending entry 0 (submitted at `T0`, offset 0) whose blob codes `payload`: the L1 state
/// (tail 1), the entry and the blob.
fn one_entry(payload: &[u8]) -> (TestState, ForcedEntry, Bytes) {
    let (blob, hash) = forced_blob(payload);
    let e = entry(0, hash, 0, T0);
    (queue_state(&[e], 1), e, blob)
}

/// The rule on cursor `cursor` with the tests' delay and Inbox.
fn rule(
    cursor: u64,
    anchor: &AnchorState,
    witness: Option<&ForcedWitness>,
) -> Result<Option<ForcedConsumption>, ForcedError> {
    check(cursor, anchor, DELAY, INBOX, witness)
}

/// The engine `txList` of `transactions` built by hand: an RLP list of each transaction's network
/// encoding (a legacy transaction as its RLP list, a typed one as a byte string of its EIP-2718
/// bytes), as Go's `rlp.EncodeToBytes(types.Transactions)` writes it.
fn tx_list(transactions: &[TxEnvelope]) -> Bytes {
    let items: Vec<u8> = transactions
        .iter()
        .flat_map(|tx| match tx {
            TxEnvelope::Legacy(_) => tx.encoded_2718(),
            _ => alloy_rlp::encode(Bytes::from(tx.encoded_2718())),
        })
        .collect();
    let mut out = Vec::new();
    alloy_rlp::Header { list: true, payload_length: items.len() }.encode(&mut out);
    out.extend(items);
    out.into()
}

/// A one-block manifest whose RLP (the decompressed payload) is exactly `len` bytes, padding the
/// input of its single legacy transaction with zeros (which compress to almost nothing).
fn manifest_with_rlp_len(len: usize) -> DerivationSourceManifest {
    let padded = |pad: usize| {
        let tx = TxLegacy { input: vec![0; pad].into(), ..Default::default() };
        let signed = tx.into_signed(Signature::new(U256::from(1), U256::from(1), false));
        DerivationSourceManifest {
            blocks: vec![BlockManifest {
                transactions: vec![TxEnvelope::Legacy(signed)],
                ..Default::default()
            }],
        }
    };
    let overhead = alloy_rlp::encode(padded(len)).len() - len;
    let manifest = padded(len - overhead);
    assert_eq!(alloy_rlp::encode(&manifest).len(), len);
    manifest
}

#[test]
fn constants_are_pinned() {
    assert_eq!(FORCED_INCLUSION_EXPIRY_SECS, 14 * 24 * 60 * 60);
    assert_eq!(FI_MAX_DECOMPRESSED_BYTES, 1_048_576);
    assert_eq!(EMPTY_TX_LIST.as_ref(), [0xc0]);
}

#[test]
fn verify_entry_reads_the_planted_fields() {
    let planted = ForcedEntry {
        index: 5,
        fee_in_gwei: u64::MAX,
        blob_hash: B256::repeat_byte(0x01),
        offset: (1 << 24) - 1,
        timestamp: (1 << 48) - 1,
    };
    let state = queue_state(&[planted], 6);
    let w = witness(&state, 5, Bytes::new());
    assert_eq!(verify_entry(state.state_root(), &w.entry, INBOX, 5), Ok(planted));
}

/// The store keeps exactly one blob hash per entry; a proven array of another length is refused
/// rather than read as a zero hash.
#[test]
fn entry_without_exactly_one_blob_hash_is_rejected() {
    let planted = entry(0, B256::repeat_byte(0x01), 0, T0);
    let storage = InboxStorage {
        forced_inclusion_tail: 1,
        forced_inclusion_queue: vec![planted],
        ..InboxStorage::genesis(sample_genesis_record(), B256::repeat_byte(0xe0))
    };
    let [_, length, _, _] = inbox::forced_inclusion_entry_slots(0);
    for count in [0u64, 2] {
        let (address, nonce, balance, code_hash, mut slots) = inbox_account(INBOX, &storage);
        slots.push((length, U256::from(count)));
        let mut accounts = filler_accounts();
        accounts.push((address, nonce, balance, code_hash, slots));
        let state = TestState::new(accounts);
        let w = witness(&state, 0, Bytes::new());
        assert!(
            matches!(
                verify_entry(state.state_root(), &w.entry, INBOX, 0),
                Err(ForcedError::Entry(_))
            ),
            "{count} blob hashes"
        );
        assert!(matches!(
            rule(0, &anchor(&state, T0 + EXPIRY, 1), Some(&w)),
            Err(ForcedError::Entry(_))
        ));
    }
}

#[test]
fn beyond_tail_without_witness_is_ordinary() {
    // An empty queue.
    let state = queue_state(&[], 0);
    assert_eq!(rule(0, &anchor(&state, T0 + EXPIRY, 0), None), Ok(None));
    // Every stored entry consumed: cursor == tail.
    let (state, e, _) = one_entry(&manifest_payload(sample_transactions()));
    assert_eq!(rule(1, &anchor(&state, e.timestamp + EXPIRY, 1), None), Ok(None));
}

#[test]
fn beyond_tail_with_witness_is_rejected() {
    let (state, e, blob) = one_entry(&manifest_payload(sample_transactions()));
    let a = anchor(&state, e.timestamp + DELAY, 1);
    // Re-carrying the consumed entry, with its blob or as a peek.
    for w in [witness(&state, 0, blob), witness(&state, 0, Bytes::new())] {
        assert_eq!(rule(1, &a, Some(&w)), Err(ForcedError::UnexpectedWitness));
    }
    // A witness for the free slot at the tail.
    let w = witness(&state, 1, Bytes::new());
    assert_eq!(rule(1, &a, Some(&w)), Err(ForcedError::UnexpectedWitness));
}

#[test]
fn pending_without_witness_is_rejected() {
    let (state, e, _) = one_entry(&manifest_payload(sample_transactions()));
    for timestamp in [e.timestamp, e.timestamp + DELAY, e.timestamp + EXPIRY] {
        assert_eq!(
            rule(0, &anchor(&state, timestamp, 1), None),
            Err(ForcedError::MissingWitness { index: 0 }),
            "anchor at {timestamp}"
        );
    }
}

#[test]
fn peek_before_due_is_ordinary() {
    let (state, e, _) = one_entry(&manifest_payload(sample_transactions()));
    let a = anchor(&state, e.timestamp + DELAY - 1, 1);
    assert!(!is_due(&e, a.timestamp, DELAY));
    assert_eq!(rule(0, &a, Some(&witness(&state, 0, Bytes::new()))), Ok(None));
}

#[test]
fn peek_exactly_at_due_is_rejected() {
    let (state, e, _) = one_entry(&manifest_payload(sample_transactions()));
    let a = anchor(&state, e.timestamp + DELAY, 1);
    assert!(is_due(&e, a.timestamp, DELAY));
    assert!(!is_expired(&e, a.timestamp));
    assert_eq!(
        rule(0, &a, Some(&witness(&state, 0, Bytes::new()))),
        Err(ForcedError::Due { index: 0 })
    );
}

#[test]
fn early_inclusion_with_blob_consumes() {
    let transactions = sample_transactions();
    let (state, e, blob) = one_entry(&manifest_payload(transactions.clone()));
    for timestamp in [e.timestamp, e.timestamp + DELAY - 1] {
        let a = anchor(&state, timestamp, 1);
        assert!(!is_due(&e, a.timestamp, DELAY));
        assert_eq!(
            rule(0, &a, Some(&witness(&state, 0, blob.clone()))),
            Ok(Some(ForcedConsumption { index: 0, tx_list: tx_list(&transactions) })),
            "anchor at {timestamp}"
        );
    }
}

#[test]
fn due_with_blob_consumes_the_manifest_transactions() {
    let transactions = sample_transactions();
    let (state, e, blob) = one_entry(&manifest_payload(transactions.clone()));
    for timestamp in [e.timestamp + DELAY, e.timestamp + EXPIRY - 1] {
        let consumed =
            rule(0, &anchor(&state, timestamp, 1), Some(&witness(&state, 0, blob.clone())))
                .expect("the due entry is consumed")
                .expect("a forced inclusion block");
        assert_eq!(consumed.index, 0);
        assert_eq!(consumed.tx_list, tx_list(&transactions), "anchor at {timestamp}");
    }
    assert_eq!(derive_tx_list(&e, &blob), Ok(protocol::shasta::encode_transactions(&transactions)));
}

/// The entry's `offset` is a byte offset into the blob's decoded bytes, where the manifest's
/// version word starts.
#[test]
fn offset_locates_the_manifest_in_the_decoded_blob() {
    let transactions = sample_transactions();
    let payload = [vec![0x5a; 77], manifest_payload(transactions.clone())].concat();
    let (blob, hash) = forced_blob(&payload);
    assert_eq!(derive_tx_list(&entry(0, hash, 77, T0), &blob), Ok(tx_list(&transactions)));
    // Any other offset reads garbage: the default manifest, an empty list.
    for offset in [0, 76, 78] {
        assert_eq!(derive_tx_list(&entry(0, hash, offset, T0), &blob), Ok(EMPTY_TX_LIST));
    }
    // An offset past the decoded bytes.
    assert_eq!(derive_tx_list(&entry(0, hash, (1 << 24) - 1, T0), &blob), Ok(EMPTY_TX_LIST));
}

#[test]
fn expired_without_blob_consumes_empty_exactly_at_expiry() {
    let (state, e, _) = one_entry(&manifest_payload(sample_transactions()));
    let peek = witness(&state, 0, Bytes::new());

    // One second before expiry the entry is due, not expired: an empty blob is a skipping peek.
    let a = anchor(&state, e.timestamp + EXPIRY - 1, 1);
    assert!(!is_expired(&e, a.timestamp));
    assert_eq!(rule(0, &a, Some(&peek)), Err(ForcedError::Due { index: 0 }));

    for timestamp in [e.timestamp + EXPIRY, u64::MAX] {
        let a = anchor(&state, timestamp, 1);
        assert!(is_expired(&e, a.timestamp));
        assert_eq!(
            rule(0, &a, Some(&peek)),
            Ok(Some(ForcedConsumption { index: 0, tx_list: EMPTY_TX_LIST })),
            "anchor at {timestamp}"
        );
    }
}

#[test]
fn expired_with_blob_is_rejected() {
    let (state, e, blob) = one_entry(&manifest_payload(sample_transactions()));
    let a = anchor(&state, e.timestamp + EXPIRY, 1);
    assert_eq!(
        rule(0, &a, Some(&witness(&state, 0, blob))),
        Err(ForcedError::BlobForExpired { index: 0 })
    );
}

#[test]
fn wrong_index_is_rejected() {
    let (blob0, hash0) = forced_blob(&manifest_payload(sample_transactions()));
    let (blob1, hash1) = forced_blob(&manifest_payload(vec![]));
    let state = queue_state(&[entry(0, hash0, 0, T0), entry(1, hash1, 0, T0 + 1)], 2);
    let a = anchor(&state, T0 + DELAY + 1, 2);

    // Skipping entry 0 for entry 1 (a reorder), and naming an entry behind the cursor.
    assert_eq!(
        rule(0, &a, Some(&witness(&state, 1, blob1.clone()))),
        Err(ForcedError::WrongIndex { expected: 0, got: 1 })
    );
    assert_eq!(
        rule(1, &a, Some(&witness(&state, 0, blob0.clone()))),
        Err(ForcedError::WrongIndex { expected: 1, got: 0 })
    );

    // The right index over another entry's proof: the slot set does not match.
    let mut w = witness(&state, 1, blob1);
    w.index = 0;
    assert!(matches!(rule(0, &a, Some(&w)), Err(ForcedError::Entry(_))));
}

#[test]
fn blob_with_wrong_versioned_hash_is_rejected() {
    let (state, e, _) = one_entry(&manifest_payload(sample_transactions()));
    let a = anchor(&state, e.timestamp + DELAY, 1);

    let (other, other_hash) = forced_blob(&manifest_payload(vec![]));
    assert_eq!(
        rule(0, &a, Some(&witness(&state, 0, other.clone()))),
        Err(ForcedError::BlobHashMismatch { expected: e.blob_hash, got: other_hash })
    );
    assert_eq!(
        derive_tx_list(&e, &other),
        Err(ForcedError::BlobHashMismatch { expected: e.blob_hash, got: other_hash })
    );

    // Not a blob: a wrong length, or a field element not below the BLS modulus.
    for bad in [other.slice(..BYTES_PER_BLOB - 1), [other.to_vec(), vec![0]].concat().into()] {
        assert_eq!(rule(0, &a, Some(&witness(&state, 0, bad))), Err(ForcedError::BadBlob));
    }
    let non_canonical = Bytes::from(vec![0xff; BYTES_PER_BLOB]);
    assert_eq!(rule(0, &a, Some(&witness(&state, 0, non_canonical))), Err(ForcedError::BadBlob));
}

#[test]
fn entry_proof_under_another_root_is_rejected() {
    let (state, e, blob) = one_entry(&manifest_payload(sample_transactions()));
    let w = witness(&state, 0, blob);

    // The same queue with one more pending entry: another state root.
    let later = queue_state(&[e, entry(1, B256::repeat_byte(0x01), 0, T0)], 2);
    let a = anchor(&later, e.timestamp + DELAY, 1);
    assert!(matches!(rule(0, &a, Some(&w)), Err(ForcedError::Entry(_))));

    // A proof of another account.
    let mut other = w.clone();
    other.entry.address = Address::repeat_byte(0xf1);
    let a = anchor(&state, e.timestamp + DELAY, 1);
    assert!(matches!(rule(0, &a, Some(&other)), Err(ForcedError::Entry(_))));
    assert!(matches!(
        verify_entry(state.state_root(), &w.entry, Address::repeat_byte(0xf1), 0),
        Err(ForcedError::Entry(_))
    ));

    // A tampered word.
    let mut tampered = w;
    tampered.entry.storage[2].value += U256::from(1);
    assert!(matches!(rule(0, &a, Some(&tampered)), Err(ForcedError::Entry(_))));
}

#[test]
fn invalid_manifest_gives_an_empty_list() {
    // A blob that decodes, but to bytes that are no manifest.
    let (blob, hash) = forced_blob(&[0x5a; 1_000]);
    assert_eq!(derive_tx_list(&entry(0, hash, 0, T0), &blob), Ok(EMPTY_TX_LIST));

    // A manifest whose zlib stream fails its checksum (last byte flipped).
    let mut payload = manifest_payload(sample_transactions());
    let last = payload.len() - 1;
    payload[last] ^= 0xff;
    let (blob, hash) = forced_blob(&payload);
    assert_eq!(derive_tx_list(&entry(0, hash, 0, T0), &blob), Ok(EMPTY_TX_LIST));

    // A valid blob the blob coder cannot decode (encoding version byte 1).
    let mut raw = vec![0u8; BYTES_PER_BLOB];
    raw[1] = 1;
    let hash = blob_versioned_hash(&raw);
    let e = entry(0, hash, 0, T0);
    assert_eq!(derive_tx_list(&e, &raw), Ok(EMPTY_TX_LIST));

    // The rule consumes the entry with that empty list.
    let state = queue_state(&[e], 1);
    assert_eq!(
        rule(0, &anchor(&state, T0 + DELAY, 1), Some(&witness(&state, 0, raw.into()))),
        Ok(Some(ForcedConsumption { index: 0, tx_list: EMPTY_TX_LIST }))
    );
}

#[test]
fn two_block_manifest_gives_an_empty_list() {
    let block = BlockManifest { transactions: sample_transactions(), ..Default::default() };
    for blocks in [vec![block.clone(), block], vec![]] {
        let payload = DerivationSourceManifest { blocks }.encode_and_compress().unwrap();
        let (blob, hash) = forced_blob(&payload);
        assert_eq!(derive_tx_list(&entry(0, hash, 0, T0), &blob), Ok(EMPTY_TX_LIST));
    }
}

#[test]
fn manifest_over_one_mebibyte_gives_an_empty_list() {
    let manifest = manifest_with_rlp_len(FI_MAX_DECOMPRESSED_BYTES + 1);
    let (blob, hash) = forced_blob(&manifest.encode_and_compress().unwrap());
    assert_eq!(derive_tx_list(&entry(0, hash, 0, T0), &blob), Ok(EMPTY_TX_LIST));
}

#[test]
fn manifest_of_exactly_one_mebibyte_gives_its_transactions() {
    let manifest = manifest_with_rlp_len(FI_MAX_DECOMPRESSED_BYTES);
    let (blob, hash) = forced_blob(&manifest.encode_and_compress().unwrap());
    assert_eq!(
        derive_tx_list(&entry(0, hash, 0, T0), &blob),
        Ok(tx_list(&manifest.blocks[0].transactions))
    );
}

/// Review Focus 2: two entries due at one anchor fill consecutive blocks; the second block names
/// entry `c + 1` with its own fresh proof.
#[test]
fn consecutive_due_entries_fill_consecutive_blocks() {
    let first = sample_transactions();
    let second = vec![first[1].clone()];
    let (blob0, hash0) = forced_blob(&manifest_payload(first.clone()));
    let (blob1, hash1) = forced_blob(&manifest_payload(second.clone()));
    let state = queue_state(&[entry(0, hash0, 0, T0), entry(1, hash1, 0, T0 + 12)], 2);
    let a = anchor(&state, T0 + 12 + DELAY, 2);

    // Block h consumes entry 0.
    let w0 = witness(&state, 0, blob0);
    assert_eq!(
        rule(0, &a, Some(&w0)),
        Ok(Some(ForcedConsumption { index: 0, tx_list: tx_list(&first) }))
    );

    // Block h + 1 (cursor 1, same anchor) must consume entry 1 with a fresh proof of index 1.
    assert_eq!(rule(1, &a, None), Err(ForcedError::MissingWitness { index: 1 }));
    assert_eq!(rule(1, &a, Some(&w0)), Err(ForcedError::WrongIndex { expected: 1, got: 0 }));
    let mut stale = w0.clone();
    stale.index = 1;
    assert!(matches!(rule(1, &a, Some(&stale)), Err(ForcedError::Entry(_))));
    assert_eq!(
        rule(1, &a, Some(&witness(&state, 1, Bytes::new()))),
        Err(ForcedError::Due { index: 1 })
    );
    let w1 = witness(&state, 1, blob1);
    assert_eq!(
        rule(1, &a, Some(&w1)),
        Ok(Some(ForcedConsumption { index: 1, tx_list: tx_list(&second) }))
    );

    // Block h + 2 (cursor 2 == tail) is ordinary and carries no witness.
    assert_eq!(rule(2, &a, None), Ok(None));
    assert_eq!(rule(2, &a, Some(&w1)), Err(ForcedError::UnexpectedWitness));
}
