//! Recovery fixtures with real Inbox proofs and native Comet signatures.
use super::*;
use crate::{
    batch::{BatchBuilder, BatchBuilderConfig, BatchSource},
    types::{Limits, SidecarMode},
};
use std::sync::Arc;

fn builder(f: Arc<Fixture>) -> BatchBuilder<Fixture, Fixture> {
    BatchBuilder::new(
        f.clone(),
        f.clone(),
        BatchBuilderConfig {
            params: f.params.clone(),
            limits: Limits {
                max_blocks: 18,
                max_blobs: 2,
                max_payload_bytes: 240_000,
                max_message_bytes: 200_000,
                max_decompressed_bytes: 2_000_000,
            },
            mode: SidecarMode::Eip4844,
            engine: Arc::new(test_harness::unavailable_engine::UnavailableEngine),
            engine_timeout: std::time::Duration::from_secs(1),
            max_batch_blocks: MAX_BATCH_BLOCKS,
        },
    )
    .unwrap()
}

/// The fallback key list generation two's origin record holds the hash of: the keys of the
/// fixture's two signers, which sign every height of the generation, each at power 1. It is
/// generation zero's origin list too.
pub(crate) fn origin_keys() -> abci::fallback::FallbackKeys {
    fallback_keys(&[1u8, 2].map(|seed| SigningKey::from_slice(&[seed; 32]).unwrap()))
}

/// Retains generation-zero c=6 and starts generation two at c+1, using R=20.
pub(crate) async fn fixture(length: u64, checkpoint: u64, tip: u64) -> Fixture {
    let mut f = Fixture::with_epoch(6, 6, 0, length);
    let genesis = f.snapshot.genesis.clone();
    let genesis_witness = abci::GenesisWitness {
        l1_header: f.l1_headers[&10].clone(),
        inbox: f.states[&10].witness(f.params.inbox, &inbox::genesis_slots()),
    };
    let old_el = f.headers[&6].clone();
    let old_comet = f.snapshot.checkpoint_comet_hash;
    let epoch = 6 / length;
    // The origin keys, each at power 1, sign every height after c. The set takes every slot
    // the fixture's committees are keyed by, so every committee the tests index is the set that
    // signs the generation.
    let keys = origin_keys();
    let origin_set = FixtureCommittee::fallback(&keys);
    for e in 0..=((tip + 1) / length).max(epoch + 2) {
        f.committees.insert(e, origin_set.clone());
    }
    f.val_states = replay_val_states((6, &origin_set.members), tip);
    f.fallback_lists.insert(keys.hash(), keys.clone());
    let state_at = |height: u64, hash: B256, comet: B256| {
        let base = state_with_queue(
            &f.params,
            &f.origin_keys,
            (height, hash, comet),
            &genesis,
            &Queue { head: 0, tail: 0, entries: vec![] },
        );
        let mut accounts = base
            .accounts
            .iter()
            .map(|(a, (s, _))| (*a, s.iter().map(|(k, v)| (*k, *v)).collect::<Vec<_>>()))
            .collect::<Vec<_>>();
        let slots = &mut accounts.iter_mut().find(|(a, _)| *a == f.params.inbox).unwrap().1;
        slots.push((inbox::slot(inbox::RECOVERY_GENERATION), U256::from(2)));
        slots.extend(inbox::origin_slots(2).into_iter().zip([
            U256::from(6),
            U256::from(20),
            U256::from(20),
            keys.hash().into(),
        ]));
        slots.extend(inbox::landing_record_slots(6).into_iter().zip([
            U256::ZERO,
            old_el.hash_slow().into(),
            old_comet.into(),
        ]));
        if height > 6 {
            slots.push((
                inbox::landing_record_slots(height)[0],
                U256::from(6) | (U256::from(2) << 48),
            ));
        }
        State::new(accounts)
    };
    let r_state = state_at(6, old_el.hash_slow(), old_comet);
    let r_header = l1_header(20, &r_state, B256::repeat_byte(19));
    let empty = Queue { head: 0, tail: 0, entries: vec![] };
    let words = fallback_words(&f.origin_keys);
    let mut r_anchor = anchor(&r_header, 6, old_el.hash_slow(), &empty, words);
    r_anchor.inbox.recovery_generation = 2;
    let witness = abci::recovery::RecoveryWitness {
        version: abci::recovery::RECOVERY_WITNESS_VERSION,
        generation: 2,
        genesis: genesis_witness,
        finalized_header: r_header.clone(),
        finalized_inbox: r_state.witness(f.params.inbox, &inbox::recovery_slots(2, 6)),
        recovery_header: r_header.clone(),
        recovery_inbox: r_state.witness(f.params.inbox, &inbox::recovery_slots(2, 6)),
        el_header: old_el.clone(),
        parent_headers: vec![f.headers[&5].clone()],
    };
    let origin = abci::recovery::verify_recovery_witness(&witness, &f.params).unwrap();
    let next_header = l1_header(21, &r_state, r_header.hash());
    let mut next_anchor = anchor(&next_header, 6, old_el.hash_slow(), &empty, words);
    next_anchor.inbox.recovery_generation = 2;
    let keys =
        vec![SigningKey::from_slice(&[1; 32]).unwrap(), SigningKey::from_slice(&[2; 32]).unwrap()];
    f.blocks.clear();
    for height in 7..=tip {
        let a = if height == 7 { &r_anchor } else { &next_anchor };
        let raw_anchor = if height == 7 { &r_header } else { &next_header };
        let parent = &f.headers[&(height - 1)];
        let info = ParentInfo {
            number: parent.number,
            hash: parent.hash_slow(),
            timestamp: parent.timestamp,
            gas_limit: parent.gas_limit,
            gas_used: parent.gas_used,
            base_fee: parent.base_fee_per_gas.unwrap(),
            difficulty: parent.difficulty,
            grandparent_timestamp: f.headers[&(height - 2)].timestamp,
        };
        let expected = rules::expected_header(&HeaderInputs {
            height,
            beneficiary: super::super::consensus::BATCH_RECIPIENT,
            parent: &info,
            anchor: a,
            bft_time_secs: 100 + height,
            generation: 2,
            miss_bitmap: 0,
            params: &f.params,
            min_base_fee: protocol::shasta::constants::min_base_fee_for_chain(f.params.l2_chain_id),
        })
        .unwrap();
        let el = Header {
            number: height,
            parent_hash: expected.parent_hash,
            state_root: B256::from(U256::from(height + 200)),
            timestamp: expected.timestamp,
            beneficiary: expected.beneficiary,
            extra_data: expected.extra_data,
            parent_beacon_block_root: Some(expected.parent_beacon_block_root),
            gas_limit: expected.gas_limit,
            base_fee_per_gas: Some(expected.base_fee),
            mix_hash: expected.mix_hash,
            withdrawals_root: Some(EMPTY_ROOT_HASH),
            blob_gas_used: Some(0),
            excess_blob_gas: Some(0),
            requests_hash: Some(EMPTY_REQUESTS_HASH),
            ommers_hash: EMPTY_OMMER_ROOT_HASH,
            transactions_root: EMPTY_ROOT_HASH,
            ..Default::default()
        };
        let envelope = EtnaEnvelope {
            block: ExecutionBlock { header: el.clone(), transactions: vec![] },
            anchor: (height <= 8).then(|| AnchorWitness {
                l1_header: raw_anchor.clone(),
                inbox: r_state.witness(f.params.inbox, &inbox::anchor_slots()),
            }),
            forced: None,
        };
        let mut pair =
            pair_with_envelope(envelope, &f.committees[&epoch], &keys, f.blocks.get(&(height - 1)));
        pair.block.header.chain_id = rules::chain_id_for(&f.params, 2).unwrap().parse().unwrap();
        pair.block.header.next_validators_hash = f.committees[&epoch].validators.hash();
        // At c + 1 the parent state is generation two's genesis state (RECOV-8.4-7).
        pair.block.header.app_hash = app_hash(parent.hash_slow(), &f.val_states[&(height - 1)]);
        super::super::consensus::resign(&mut pair, &f.committees[&epoch], &keys);
        f.blocks.insert(height, pair);
        f.headers.insert(height, el);
        f.anchors.insert(height, a.clone());
    }
    let cp_comet = if checkpoint == 6 {
        old_comet
    } else {
        B256::from_slice(f.blocks[&checkpoint].block.header.hash().as_bytes())
    };
    let state = state_at(checkpoint, f.headers[&checkpoint].hash_slow(), cp_comet);
    f.states.insert(21, r_state.clone());
    f.states.insert(20, r_state);
    f.l1_headers.insert(20, r_header);
    f.l1_headers.insert(21, next_header);
    for n in 22..=23 {
        f.l1_headers.insert(n, l1_header(n, &state, f.l1_headers[&(n - 1)].hash()));
    }
    f.states.insert(23, state.clone());
    let raw = f.l1_headers[&23].clone();
    f.snapshot = LandingSnapshot {
        recovery: Some(origin),
        recovery_witness: Some(alloy_rlp::encode(&witness).into()),
        generation: 2,
        checkpoint_height: checkpoint,
        checkpoint_hash: f.headers[&checkpoint].hash_slow(),
        checkpoint_comet_hash: cp_comet,
        l1_header: raw.clone(),
        l1_block_hash: raw.hash(),
        l1_block_number: 23,
        inbox_witness: state
            .witness(f.params.inbox, &crate::l1::snapshot_landing_slots(checkpoint)),
        ..f.snapshot
    };
    f.parent_anchor_override = Some(if checkpoint == 6 { r_anchor } else { next_anchor });
    f
}

/// From the recovery origin c = 6 the batch to 12 takes its anchors at or after R (20), and the
/// origin record's fallback keys, each at power 1, sign every height of the generation.
#[tokio::test]
async fn recovery_origin_uses_retained_boundary_and_the_origin_keys() {
    for length in [6, 7, 8] {
        let f = Arc::new(fixture(length, 6, 12).await);
        let snapshot = &f.snapshot;
        let old_landing_comet_hash = snapshot.checkpoint_comet_hash;
        assert_eq!(snapshot.origin_height(), 6);
        assert_eq!(snapshot.recovery.as_ref().unwrap().comet_hash, old_landing_comet_hash);
        assert_eq!(snapshot.recovery.as_ref().unwrap().fallback_keys_hash, origin_keys().hash());
        let prepared = builder(f.clone()).prepare(snapshot.clone()).await.unwrap().unwrap();
        prepared.batch.verify_restored().unwrap();
        let origin_set =
            crate::committee::Validators::from_powers(&origin_keys().validator_set()).unwrap();
        assert!(
            prepared
                .batch
                .blocks
                .iter()
                .all(|pair| pair.block.header.validators_hash == origin_set.hash())
        );
        assert!(prepared.batch.anchors.iter().all(|a| a.number >= 20));
        assert!(prepared.batch.blocks[0].block.last_commit.is_none());
    }
}

/// From the recovery origin c the statement's parent words are the retained record's EL and
/// Comet hashes as stored, the old generation's values, and the batch carries one leaf for every
/// height strictly inside (c, h).
#[tokio::test]
async fn recovered_origin_binds_the_stored_parent_words() {
    for length in [6, 7, 8] {
        let f = Arc::new(fixture(length, 6, 18).await);
        let origin = f.snapshot.recovery.clone().unwrap();
        let prepared = builder(f.clone()).prepare(f.snapshot.clone()).await.unwrap().unwrap();
        let batch = &prepared.batch;
        let leaves: Vec<_> = (7..18)
            .map(|height| {
                crate::statement::cut_leaf(
                    height,
                    f.headers[&height].hash_slow(),
                    B256::from_slice(f.blocks[&height].block.header.hash().as_bytes()),
                    0,
                )
            })
            .collect();
        assert_eq!(batch.leaves, leaves);
        let reference = RawL1Header::from_raw(batch.reference_headers[0].clone()).unwrap();
        let words = crate::statement::preimage(
            &batch.snapshot,
            &batch.input,
            reference.hash(),
            &batch.blobs.versioned_hashes,
            &batch.leaves,
        );
        assert_eq!(&words[6 * 32..7 * 32], origin.el_hash.as_slice(), "length {length}");
        assert_eq!(&words[7 * 32..8 * 32], origin.comet_hash.as_slice(), "length {length}");
        batch.verify_restored().unwrap();
    }
}

/// A later checkpoint keeps the authenticated origin, and the origin keys stay the set that
/// signs through the heights the global schedule called switches.
#[tokio::test]
async fn recovery_later_checkpoint_keeps_authenticated_origin_and_the_origin_keys() {
    let mut terminal_leaves = BTreeMap::new();
    for (length, checkpoint) in [6, 7, 8].into_iter().flat_map(|l| [6, 12].map(|p| (l, p))) {
        let f = Arc::new(fixture(length, checkpoint, 18).await);
        let prepared = builder(f.clone()).prepare(f.snapshot.clone()).await.unwrap().unwrap();
        assert_eq!(prepared.batch.input.parentHeight, U256::from(checkpoint));
        assert_eq!(prepared.batch.input.lastHeight, U256::from(18));
        prepared.batch.verify_restored().unwrap();
        if checkpoint == 6 {
            terminal_leaves.insert(
                length,
                (
                    prepared.batch.input.lastBlockHash,
                    prepared.batch.input.lastCometHash,
                    prepared.batch.input.lastStateRoot,
                ),
            );
        } else {
            assert_eq!(
                Some(&(
                    prepared.batch.input.lastBlockHash,
                    prepared.batch.input.lastCometHash,
                    prepared.batch.input.lastStateRoot
                )),
                terminal_leaves.get(&length)
            );
        }
        // The chain must reach its oldest consumed anchor; dropping that header is refused.
        let b = &prepared.batch;
        let anchors =
            crate::batch::consumed_anchors(&b.snapshot, &b.parent_anchor, &b.anchors).unwrap();
        let headers = |raw: &[alloy_primitives::Bytes]| {
            raw.iter().map(|h| RawL1Header::from_raw(h.clone()).unwrap()).collect::<Vec<_>>()
        };
        crate::batch::verify_reference_chain(&headers(&b.reference_headers), &anchors).unwrap();
        let truncated = &b.reference_headers[..b.reference_headers.len() - 1];
        assert!(crate::batch::verify_reference_chain(&headers(truncated), &anchors).is_err());
        assert!(
            prepared
                .batch
                .reference_headers
                .iter()
                .all(|h| RawL1Header::from_raw(h.clone()).unwrap().number() >= 20)
        );
    }
}

/// R joins the reference chain only for a batch from the origin c: a later batch
/// authenticates the fixed origin record under its own starting anchor. Requiring R in every
/// batch would make the generation unlandable once R falls more than the reference bound
/// (131,072 headers) behind the finalized tip.
#[tokio::test]
async fn recovery_root_is_consumed_only_from_the_origin() {
    // c = 6, R = 20, next anchor 21: blocks from 9 on inherit anchor 21.
    for (length, checkpoint, tip, uses_r) in [
        (6, 6, 18, true),
        (6, 12, 18, false),
        (7, 6, 18, true),
        (7, 12, 18, false),
        (8, 6, 18, true),
        (8, 12, 18, false),
        (8, 18, 24, false),
    ] {
        let f = Arc::new(fixture(length, checkpoint, tip).await);
        let prepared = builder(f.clone()).prepare(f.snapshot.clone()).await.unwrap().unwrap();
        let oldest = prepared.batch.reference_headers.last().unwrap().clone();
        let oldest = RawL1Header::from_raw(oldest).unwrap().number();
        assert_eq!(oldest, if uses_r { 20 } else { 21 }, "length {length}, p {checkpoint}");
        prepared.batch.verify_restored().unwrap();
    }
}

/// Without R, a batch still authenticates its generation's fixed origin record (slot 290)
/// under its own starting anchor (PROOF-6.2-14): the starting proof must carry it.
#[tokio::test]
async fn starting_witness_authenticates_the_generation_origin_record() {
    let f = Arc::new(fixture(8, 12, 18).await);
    let origin = f.snapshot.recovery.clone().unwrap();
    let prepared = builder(f.clone()).prepare(f.snapshot.clone()).await.unwrap().unwrap();
    let witness = &prepared.batch.starting_inbox_witness;
    let slots = inbox::origin_slots(origin.generation);
    let record = slots.map(|slot| {
        witness.inbox.storage.iter().find(|p| p.slot == slot).expect("origin slot is proven").value
    });
    assert_eq!(
        record,
        [
            U256::from(origin.height),
            U256::from(origin.l1_number),
            U256::from(origin.l1_timestamp),
            origin.fallback_keys_hash.into(),
        ]
    );

    let mut without_origin = witness.clone();
    without_origin.inbox.storage.retain(|p| !slots.contains(&p.slot));
    let anchor = &prepared.batch.parent_anchor;
    assert!(crate::l1::verify_starting_inbox(&without_origin, anchor, f.params.inbox).is_err());
}

#[tokio::test]
async fn recovery_requires_origin_evidence_pair_and_rejects_tampering() {
    let f = fixture(6, 6, 12).await;
    crate::l1::authenticate_snapshot(&f.snapshot, &f.params).unwrap();
    for mutation in 0..8 {
        let mut bad = f.snapshot.clone();
        match mutation {
            0 => bad.recovery = None,
            1 => bad.recovery_witness = None,
            2 => bad.recovery.as_mut().unwrap().l1_number += 1,
            3 => bad.recovery.as_mut().unwrap().fallback_keys_hash = B256::repeat_byte(3),
            4 => bad.recovery.as_mut().unwrap().comet_hash = B256::ZERO,
            5 => bad.generation = 0,
            6 => {
                let mut bytes = bad.recovery_witness.take().unwrap().to_vec();
                bytes.push(0);
                bad.recovery_witness = Some(bytes.into());
            }
            7 => bad.checkpoint_height += 6,
            _ => unreachable!(),
        }
        assert!(crate::l1::authenticate_snapshot(&bad, &f.params).is_err(), "mutation {mutation}");
    }
}

#[tokio::test]
async fn recovery_empty_last_commit_only_authenticates_at_first_generation_height() {
    let f = fixture(8, 6, 12).await;
    let first = &f.blocks[&7];
    let parent = f.headers[&6].hash_slow();
    crate::validate::verify_structure_at_origin(first, None, 7, parent, 6).unwrap();
    assert!(crate::validate::verify_structure(first, None, 7, parent).is_err());
    assert!(crate::validate::verify_structure_at_origin(first, None, 7, parent, 5).is_err());
    let mut bad = first.clone();
    bad.block.header.last_block_id = Some(first.commit.block_id);
    let keys =
        vec![SigningKey::from_slice(&[1; 32]).unwrap(), SigningKey::from_slice(&[2; 32]).unwrap()];
    super::super::consensus::resign(&mut bad, &f.committees[&0], &keys);
    assert!(crate::validate::verify_structure_at_origin(&bad, None, 7, parent, 6).is_err());
    let mut second = f.blocks[&8].clone();
    second.block.last_commit = None;
    second.block.header.last_block_id = None;
    second.block.header.last_commit_hash = Some(super::super::consensus::merkle(&[]));
    super::super::consensus::resign(&mut second, &f.committees[&0], &keys);
    assert!(
        crate::validate::verify_structure_at_origin(&second, None, 8, f.headers[&7].hash_slow(), 6)
            .is_err()
    );
    let mut raw = first.block_proto().unwrap();
    raw.last_commit.as_mut().unwrap().height = 1;
    let malformed = CertifiedBlock::from_raw(raw, first.commit.clone()).unwrap();
    assert!(crate::validate::verify_structure_at_origin(&malformed, None, 7, parent, 6).is_err());
}

#[tokio::test]
async fn recovery_before_first_commit_waits_for_missing_history() {
    let mut f = fixture(7, 6, 6).await;
    f.headers.retain(|height, _| *height == 0 || *height == 5 || *height == 6);
    // The RPC's empty store reports zero, independent from the retained execution header.
    let source = Arc::new(f);
    assert!(matches!(
        builder(source.clone()).validate_checkpoint(&source.snapshot).await,
        Err(LanderError::Unavailable(_))
    ));
    assert!(matches!(
        builder(source.clone()).prepare(source.snapshot.clone()).await,
        Err(LanderError::Unavailable(_))
    ));
}

#[test]
fn recovery_optional_fields_preserve_generation_zero_projection() {
    let f = Fixture::new(0, 6);
    let bytes = serde_json::to_vec(&f.snapshot).unwrap();
    let value: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
    assert!(value.get("recovery").is_none());
    assert!(value.get("recovery_witness").is_none());
    let restored: LandingSnapshot = serde_json::from_slice(&bytes).unwrap();
    assert_eq!(serde_json::to_vec(&restored).unwrap(), bytes);
}
