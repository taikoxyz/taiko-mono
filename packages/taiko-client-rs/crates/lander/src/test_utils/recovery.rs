//! Recovery fixtures with real Inbox/registry proofs and native Comet signatures.
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

/// Retains generation-zero c=6 and starts generation two at c+1, using R=20.
pub(crate) async fn fixture(length: u64, checkpoint: u64, tip: u64) -> Fixture {
    let mut f = Fixture::with_epoch(6, 6, 0, length);
    let genesis = f.snapshot.genesis.clone();
    let schedule = Schedule::from_genesis(&genesis);
    let entries = f.registry_entries();
    let genesis_committee = f.committee_witness(&f.anchors[&0], 1, 0).await.unwrap();
    let genesis_witness = abci::GenesisWitness {
        l1_header: f.l1_headers[&10].clone(),
        inbox: f.states[&10].witness(f.params.inbox, &inbox::genesis_slots()),
        committee: genesis_committee,
    };
    let old_el = f.headers[&6].clone();
    let old_comet = f.snapshot.checkpoint_comet_hash;
    // Generation zero's state at c: the retained record's word 4, which generation two binds as
    // stored but never replays from.
    let old_val_state = f.snapshot.checkpoint_val_state_hash;
    let epoch = 6 / length;
    let old_committees = f.committees.clone();
    for e in epoch..=schedule.epoch_of(tip + 2).max(epoch + 2) {
        let cutoff = if e == epoch || schedule.derivation_parent_height(e).is_none_or(|h| h <= 7) {
            20
        } else {
            21
        };
        let (record, members) = derive(
            &Snapshot { checkpoint_index: 0, l1_block: 1, entries: entries.clone() },
            cutoff,
            e,
            &f.params,
        )
        .unwrap();
        f.committees
            .insert(e, AuthenticatedCommittee::new(CommitteeState { record, members }).unwrap());
    }
    f.val_states = replay_val_states(
        &schedule,
        &f.committees,
        (6, &f.committees[&epoch].state),
        tip,
        |height| schedule.active_committee_epoch(height, 6).unwrap(),
    );
    let val_state_hash =
        |height: u64| if height == 6 { old_val_state } else { f.val_states[&height].hash() };
    let state_at = |height: u64, hash: B256, comet: B256| {
        let base = state_with_queue(
            &f.params,
            &entries,
            (height, hash, comet, val_state_hash(height)),
            &old_committees,
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
        ]));
        slots.extend(inbox::landing_slots(6).into_iter().zip([
            U256::ZERO,
            old_el.hash_slow().into(),
            old_comet.into(),
            old_val_state.into(),
        ]));
        if height > 6 {
            slots.push((inbox::landing_slots(height)[0], U256::from(6) | (U256::from(2) << 48)));
        }
        State::new(accounts)
    };
    let r_state = state_at(6, old_el.hash_slow(), old_comet);
    let r_header = l1_header(20, &r_state, B256::repeat_byte(19));
    let mut r_anchor =
        anchor(&r_header, 6, old_el.hash_slow(), &Queue { head: 0, tail: 0, entries: vec![] });
    r_anchor.inbox.recovery_generation = 2;
    let witness = abci::recovery::RecoveryWitness {
        version: 1,
        generation: 2,
        genesis: genesis_witness,
        finalized_header: r_header.clone(),
        finalized_inbox: r_state.witness(f.params.inbox, &inbox::recovery_slots(2, 6)),
        recovery_header: r_header.clone(),
        recovery_inbox: r_state.witness(f.params.inbox, &inbox::recovery_slots(2, 6)),
        committee: CommitteeWitness {
            record: f.committees[&epoch].state.record.clone(),
            registry: r_state.witness(f.params.registry, &snapshot_slots(0, false)),
            entries: entries.clone(),
        },
        el_header: old_el.clone(),
        parent_headers: vec![f.headers[&5].clone()],
    };
    let origin = abci::recovery::verify_recovery_witness(&witness, &f.params).unwrap();
    let next_header = l1_header(21, &r_state, r_header.hash());
    let mut next_anchor =
        anchor(&next_header, 6, old_el.hash_slow(), &Queue { head: 0, tail: 0, entries: vec![] });
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
        let active = schedule.active_committee_epoch(height, 6).unwrap();
        let envelope = EtnaEnvelope {
            block: ExecutionBlock { header: el.clone(), transactions: vec![] },
            anchor: (height <= 8).then(|| AnchorWitness {
                l1_header: raw_anchor.clone(),
                inbox: r_state.witness(f.params.inbox, &inbox::anchor_slots()),
            }),
            committee: schedule.switch_target(height).map(|e| CommitteeWitness {
                record: f.committees[&e].state.record.clone(),
                registry: r_state.witness(f.params.registry, &snapshot_slots(0, false)),
                entries: entries.clone(),
            }),
            forced: None,
        };
        let mut pair = pair_with_envelope(
            envelope,
            &f.committees[&active],
            &keys,
            f.blocks.get(&(height - 1)),
        );
        pair.block.header.chain_id = rules::chain_id_for(&f.params, 2).unwrap().parse().unwrap();
        pair.block.header.next_validators_hash = f.committees
            [&schedule.active_committee_epoch(height + 1, 6).unwrap()]
            .validators
            .hash();
        super::super::consensus::resign(&mut pair, &f.committees[&active], &keys);
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
        checkpoint_val_state_hash: val_state_hash(checkpoint),
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

#[tokio::test]
async fn recovery_origin_uses_retained_boundary_and_r_committee() {
    for length in [6, 7, 8] {
        let f = Arc::new(fixture(length, 6, 12).await);
        let snapshot = &f.snapshot;
        let r_committee = &snapshot.recovery.as_ref().unwrap().committee;
        let old_landing_comet_hash = snapshot.checkpoint_comet_hash;
        assert_eq!(snapshot.origin_height(), 6);
        assert_eq!(snapshot.recovery.as_ref().unwrap().comet_hash, old_landing_comet_hash);
        assert_eq!(snapshot.initial_committee(), Some(r_committee));
        let prepared = builder(f.clone()).prepare(snapshot.clone()).await.unwrap().unwrap();
        prepared.batch.validate_statement().unwrap();
        assert_eq!(prepared.batch.input.activeCommitteeSnapshot, U256::from(20));
        assert!(prepared.batch.anchors.iter().all(|a| a.number >= 20));
        assert!(prepared.batch.blocks[0].block.last_commit.is_none());
        assert!(prepared.batch.committee_witnesses.iter().all(|c| c.anchor.number >= 20));
    }
}

/// From the recovery origin c the replay starts at the genesis state of R's committee, with no
/// query (the fixture panics on one), while the statement's `parentValStateHash` is the retained
/// record's word 4 as stored: the old generation's value, here generation zero's state at c.
#[tokio::test]
async fn recovered_origin_starts_from_genesis_but_binds_the_stored_parent_word() {
    for length in [6, 7, 8] {
        let f = Arc::new(fixture(length, 6, 18).await);
        let origin = f.snapshot.recovery.clone().unwrap();
        let members = origin.committee.members.iter().map(|m| (m.pubkey, m.power));
        let genesis = ValState::genesis(6, &members.collect::<Vec<_>>()).unwrap();
        let stored = f.snapshot.checkpoint_val_state_hash;
        assert_eq!(stored, origin.val_state_hash);
        assert!(!stored.is_zero());
        assert_ne!(stored, genesis.hash());

        let prepared = builder(f.clone()).prepare(f.snapshot.clone()).await.unwrap().unwrap();
        let batch = &prepared.batch;
        assert_eq!(batch.start_val_state, genesis);
        assert_eq!(batch.input.lastValStateHash, f.val_states[&18].hash());
        let leaf = crate::statement::cut_leaf(
            12,
            f.headers[&12].hash_slow(),
            B256::from_slice(f.blocks[&12].block.header.hash().as_bytes()),
            0,
            f.val_states[&12].hash(),
        );
        assert_eq!(batch.leaves, vec![leaf]);
        let reference = RawL1Header::from_raw(batch.reference_headers[0].clone()).unwrap();
        let words = crate::statement::preimage(
            &batch.snapshot,
            &batch.input,
            reference.hash(),
            &batch.blobs.versioned_hashes,
            &batch.leaves,
        );
        assert_eq!(&words[9 * 32..10 * 32], stored.as_slice(), "length {length}");
        batch.validate_statement().unwrap();
    }
}

#[tokio::test]
async fn recovery_later_checkpoint_and_epoch_crossing_keep_authenticated_origin() {
    let mut terminal_leaves = BTreeMap::new();
    for (length, checkpoint) in [6, 7, 8].into_iter().flat_map(|l| [6, 12].map(|p| (l, p))) {
        let f = Arc::new(fixture(length, checkpoint, 18).await);
        let prepared = builder(f.clone()).prepare(f.snapshot.clone()).await.unwrap().unwrap();
        assert_eq!(prepared.batch.input.parentHeight, U256::from(checkpoint));
        assert_eq!(prepared.batch.input.lastHeight, U256::from(18));
        assert_eq!(prepared.batch.input.activeCommitteeSnapshot, U256::from(21));
        prepared.batch.validate_statement().unwrap();
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
        let mut truncated = prepared.batch.clone();
        truncated.reference_headers.pop();
        assert!(truncated.validate_statement().is_err());
        assert!(
            prepared
                .batch
                .reference_headers
                .iter()
                .all(|h| RawL1Header::from_raw(h.clone()).unwrap().number() >= 20)
        );
    }
}

/// R joins the reference chain only while a batch uses recovery material: a proof from the
/// origin c, or one that uses the committee selected from R's registry snapshot (PROOF-6.2-14,
/// PROOF-6.2-30). Requiring it in every batch would make the generation unlandable once R falls
/// more than the reference bound (BATCH-6.3-6, 131,072 headers) behind the finalized tip.
#[tokio::test]
async fn recovery_root_is_consumed_only_while_recovery_material_is_used() {
    // c = 6, R = 20, next anchor 21. At L = 8, ordinary epoch 1 was selected by the first
    // recovered switch at 7, whose own proving anchor is R. Its provenance still consumes R
    // at p = 12. The later batch from 18 uses only epoch 2 and later switches at anchor 21.
    for (length, checkpoint, tip, uses_r) in [
        (6, 6, 18, true),
        (6, 12, 18, true),
        (7, 6, 18, true),
        (7, 12, 18, true),
        (8, 6, 18, true),
        (8, 12, 18, true),
        (8, 18, 24, false),
    ] {
        let f = Arc::new(fixture(length, checkpoint, tip).await);
        let prepared = builder(f.clone()).prepare(f.snapshot.clone()).await.unwrap().unwrap();
        let oldest = prepared.batch.reference_headers.last().unwrap().clone();
        let oldest = RawL1Header::from_raw(oldest).unwrap().number();
        assert_eq!(oldest, if uses_r { 20 } else { 21 }, "length {length}, p {checkpoint}");
        prepared.batch.validate_statement().unwrap();
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
    assert_eq!(record, [origin.height, origin.l1_number, origin.l1_timestamp].map(U256::from));

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
            3 => bad.recovery.as_mut().unwrap().committee.record.target_epoch += 1,
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
