use super::*;

#[test]
fn evidence_uses_post_s_state_and_strict_and_expiry() {
    let time = |seconds| tendermint::Time::from_unix_timestamp(seconds, 0).unwrap();
    // START-10-21: 16 blocks and 3 min; both must be exceeded.
    assert!(!evidence_expired(200_000, time(800_000), 199_984, time(1)));
    assert!(!evidence_expired(200_000, time(800_000), 199_983, time(799_820)));
    assert!(evidence_expired(200_000, time(800_000), 199_983, time(799_819)));
    assert!(!evidence_expired(200_000, time(800_000), 1, time(799_820)));
    assert!(!evidence_expired(200_000, time(800_000), 1, time(800_001)));
}

#[test]
fn nonlanded_and_other_generation_are_candidate_errors() {
    for record in [
        Landing {
            height: 12,
            parent_height: 0,
            generation: 1,
            forced_cursor: 0,
            el_hash: B256::ZERO,
            comet_hash: B256::ZERO,
        },
        Landing {
            height: 12,
            parent_height: 6,
            generation: 0,
            forced_cursor: 0,
            el_hash: B256::repeat_byte(1),
            comet_hash: B256::repeat_byte(2),
        },
    ] {
        assert!(matches!(
            validate_selected_landing(&record, 1, 6, 18),
            Err(ImportError::Candidate(_))
        ));
    }
}

/// DATA-5.4-3/5: a preimage for s - 1 that does not give header(s)'s app_hash with ELHash(s - 1)
/// is an invalid candidate; once it gives it, the header commits it, so bytes that do not
/// decode, or the state after another height, are an authenticated contradiction.
#[test]
fn preimage_app_hash_mismatch_is_candidate_but_committed_invalid_preimage_is_safety() {
    let fx = Fixture::new(6, 6);
    let parent = fx.headers[&5].hash_slow();
    let header = fx.blocks[&6].block.header.clone();
    let before = fx.val_states[&5].encode();
    assert_eq!(authenticate_preimage(&before, &header, parent), Ok(fx.val_states[&5].clone()));
    // The same preimage with another parent EL hash does not give header(6)'s app_hash.
    assert!(matches!(
        authenticate_preimage(&before, &header, B256::repeat_byte(1)),
        Err(ImportError::Candidate(_))
    ));
    for (bytes, committed) in [
        (b"not a validator state".to_vec(), "decode"),
        (fx.val_states[&6].encode(), "height"),
        (fx.val_states[&4].encode(), "height"),
    ] {
        assert!(matches!(
            authenticate_preimage(&bytes, &header, parent),
            Err(ImportError::Candidate(_))
        ));
        let mut header = header.clone();
        header.app_hash = app_hash_of(parent, &bytes);
        let result = authenticate_preimage(&bytes, &header, parent);
        assert!(matches!(result, Err(ImportError::Safety(_))), "{committed}: {result:?}");
    }
}

/// A header `app_hash` field holding appHash (ENC-A-29b) of `block_hash` and the hash of the
/// raw preimage `bytes`.
fn app_hash_of(block_hash: B256, bytes: &[u8]) -> tendermint::AppHash {
    let hash = abci::valstate::app_hash(block_hash, keccak256(bytes));
    tendermint::AppHash::try_from(hash.to_vec()).unwrap()
}

/// Make header(`s`) commit `before` as the validator state after s - 1 (CONS-3.1-8), and,
/// with `next_hash`, its set for s + 1 as `next_validators_hash`; then re-sign it and land its
/// new Comet hash. The window ends at s, so no successor needs relinking.
fn commit_terminal(fx: &mut Fixture, s: u64, before: &abci::valstate::ValState, next_hash: bool) {
    use crate::test_utils::consensus::{SigningKey, resign};
    let parent = fx.headers[&(s - 1)].hash_slow();
    let pair = fx.blocks.get_mut(&s).unwrap();
    pair.block.header.app_hash = crate::test_utils::consensus_mpt::app_hash(parent, before);
    if next_hash {
        pair.block.header.next_validators_hash =
            tendermint::Hash::Sha256(before.next.validators_hash().unwrap().0);
    }
    resign(
        pair,
        &fx.committees[&0],
        &[SigningKey::from_slice(&[1; 32]).unwrap(), SigningKey::from_slice(&[2; 32]).unwrap()],
    );
    let comet = B256::from_slice(pair.block.header.hash().as_bytes());
    fx.import_landings(&[(s, fx.headers[&s].hash_slow(), comet)]);
}

use crate::test_utils::consensus_mpt::{Fixture, import_package};
use abci::{AccountWitness, L1Error, RawL1Header};
use alloy_primitives::Address;
use async_trait::async_trait;
use prost::Message;

struct OwnL1(std::sync::Arc<Fixture>);
#[async_trait]
impl L1Source for OwnL1 {
    async fn finalized_number(&self) -> Result<u64, L1Error> {
        Ok(self.0.snapshot.l1_block_number)
    }
    async fn canonical_hash(&self, number: u64) -> Result<B256, L1Error> {
        Ok(self.0.l1_headers[&number].hash())
    }
    async fn header(&self, number: u64) -> Result<RawL1Header, L1Error> {
        Ok(self.0.l1_headers[&number].clone())
    }
    async fn account_witness(
        &self,
        address: Address,
        slots: &[B256],
        number: u64,
    ) -> Result<AccountWitness, L1Error> {
        Ok(self.0.import_witness(address, slots, number))
    }
    async fn forced_transaction(&self, _: Address, _: u64, _: u64) -> Result<Bytes, L1Error> {
        panic!("pre-s FI acquisition forbidden")
    }
    async fn storage_at(&self, _: Address, _: B256, _: u64) -> Result<U256, L1Error> {
        panic!("unproven storage discovery forbidden during import")
    }
}

fn frames(fx: &Fixture, height: u64) -> Vec<Result<WindowBlock, ImportError>> {
    (fx.snapshot.origin_height() + 1..=height)
        .map(|h| {
            let pair = &fx.blocks[&h];
            // The generation's initial set signs every height; every fixture committee holds
            // the same members.
            let committee = &fx.committees[&0];
            Ok(WindowBlock {
                block: pair.raw_block.clone(),
                commit: tendermint_proto::v0_38::types::Commit::from(pair.commit.clone())
                    .encode_to_vec()
                    .into(),
                validators: committee
                    .state
                    .members
                    .iter()
                    .map(|m| ImportValidator { key: m.pubkey, power: m.power })
                    .collect(),
            })
        })
        .collect()
}

#[tokio::test]
async fn reconstructs_exact_post_checkpoint_without_successor_or_execution_source() {
    let fx = std::sync::Arc::new(Fixture::new(6, 6));
    let package = import_package(&fx, 6).await;
    let result =
        authenticate_import(&package, frames(&fx, 6).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await
            .unwrap();
    assert_eq!(result.state().last_height, 6);
    assert_eq!(result.state().val_state, fx.val_states[&6]);
    assert_eq!(result.state().parent.hash, fx.headers[&6].hash_slow());
    assert_eq!(result.state().anchor, fx.anchors[&6]);
    assert_eq!(result.genesis().initial_height, "1");
    assert_eq!(result.first_height(), Some(1));
    assert_eq!(result.execution_headers().last(), Some(&fx.headers[&6]));
    assert_eq!(
        result.state().execution_floor,
        Some(abci::ExecutionFloor { number: 6, hash: fx.headers[&6].hash_slow() })
    );
}

/// DATA-5.4-3/8: the package carries the validator state after s - 1, which with ELHash(s - 1)
/// gives header(s)'s app_hash; the import derives the state after s from it.
#[tokio::test]
async fn import_accepts_preimage_for_s_minus_1() {
    let fx = std::sync::Arc::new(Fixture::new(6, 6));
    let package = import_package(&fx, 6).await;
    assert_eq!(package.schema, IMPORT_SCHEMA);
    assert_eq!(package.validator_state.as_ref(), fx.val_states[&5].encode().as_slice());
    let imported =
        authenticate_import(&package, frames(&fx, 6).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await
            .unwrap();
    assert_eq!(imported.val_state_before(), Some(&fx.val_states[&5]));
    assert_eq!(imported.state().val_state, fx.val_states[&6]);
    assert_eq!(imported.state().last_height, 6);
}

/// DATA-5.4-5: a preimage that does not give header(s)'s app_hash, including the old schema's
/// state after s, is an invalid candidate, as is the old schema itself.
#[tokio::test]
async fn import_rejects_preimage_with_wrong_app_hash() {
    let fx = std::sync::Arc::new(Fixture::new(6, 6));
    let honest = import_package(&fx, 6).await;
    let mut tampered = fx.val_states[&5].clone();
    tampered.current.entries[0].power += 1;
    for preimage in [fx.val_states[&6].encode(), tampered.encode(), Vec::new()] {
        let mut package = honest.clone();
        package.validator_state = preimage.into();
        let result = authenticate_import(
            &package,
            frames(&fx, 6).into_iter(),
            &fx.params,
            &OwnL1(fx.clone()),
        )
        .await;
        assert!(
            matches!(result, Err(ImportError::Candidate(ref m)) if m.contains("app_hash")),
            "{result:?}"
        );
    }
    let mut old = honest.clone();
    old.schema = 1;
    let result =
        authenticate_import(&old, frames(&fx, 6).into_iter(), &fx.params, &OwnL1(fx.clone())).await;
    assert!(matches!(result, Err(ImportError::Candidate(ref m)) if m.contains("schema")));
}

/// At s the preimage for s - 1 verifies against header(s)'s app_hash, and block s's update
/// list, the empty one, applies once: the state after s is the replay's, its current set is
/// the one before s's next, and both its sets are the generation's initial set. The state after
/// s is no valid preimage.
#[tokio::test]
async fn import_advances_s_once_with_no_updates() {
    let fx = std::sync::Arc::new(Fixture::with_epoch(12, 12, 0, 13));
    let before = &fx.val_states[&11];
    let package = import_package(&fx, 12).await;
    let imported =
        authenticate_import(&package, frames(&fx, 12).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await
            .unwrap();
    let after = &imported.state().val_state;
    assert_eq!(after, &fx.val_states[&12]);
    assert_eq!(after, &before.advance(&[]).unwrap());
    assert_eq!(after.current, before.next);
    let initial = fx.committees[&0]
        .state
        .members
        .iter()
        .map(|m| (m.pubkey, m.power))
        .collect::<std::collections::BTreeMap<_, _>>();
    for (h, set) in [(13, &after.current), (14, &after.next)] {
        assert_eq!(
            set.entries
                .iter()
                .map(|e| (e.key, e.power as u64))
                .collect::<std::collections::BTreeMap<_, _>>(),
            initial,
            "height {h}"
        );
    }
    let mut wrong = package.clone();
    wrong.validator_state = fx.val_states[&12].encode().into();
    let result =
        authenticate_import(&wrong, frames(&fx, 12).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await;
    assert!(
        matches!(result, Err(ImportError::Candidate(ref m)) if m.contains("app_hash")),
        "{result:?}"
    );
}

/// DATA-5.4-4/CONS-3.1-8: the stock stores install appHash of ELHash(s) and the state after s,
/// the app_hash the decided header s + 1 carries, not the bare EL hash.
#[tokio::test]
async fn import_post_s_app_hash_is_app_hash() {
    let fx = std::sync::Arc::new(Fixture::new(6, 7));
    let package = import_package(&fx, 6).await;
    let imported =
        authenticate_import(&package, frames(&fx, 6).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await
            .unwrap();
    let el_hash = fx.headers[&6].hash_slow();
    assert_eq!(imported.app_hash(), abci::valstate::app_hash(el_hash, fx.val_states[&6].hash()));
    assert_eq!(imported.app_hash().as_slice(), fx.blocks[&7].block.header.app_hash.as_bytes());
    assert_ne!(imported.app_hash(), el_hash);
}

/// DATA-5.4-2: only w + 1's original envelope authenticates the publisher's EL header at w, as
/// its parentHash; header(w + 1)'s app_hash also commits the validator state and links nothing.
#[tokio::test]
async fn first_window_envelope_parent_hash_authenticates_the_execution_header_at_w() {
    let fx = std::sync::Arc::new(Fixture::new(6, 6));
    let mut package = import_package(&fx, 6).await;
    package.boundary_header = Some(fx.blocks[&1].block.header.clone());
    package.execution_headers = vec![fx.headers[&0].clone(), fx.headers[&1].clone()];
    let window = || frames(&fx, 6).into_iter().skip(1);
    let unlinked = |result: &Result<VerifiedImport, ImportError>| matches!(result, Err(ImportError::Candidate(m)) if m.contains("does not link"));
    let honest = authenticate_import(&package, window(), &fx.params, &OwnL1(fx.clone())).await;
    assert!(!unlinked(&honest), "{honest:?}");
    package.execution_headers[1].state_root = B256::repeat_byte(0xab);
    let forged = authenticate_import(&package, window(), &fx.params, &OwnL1(fx.clone())).await;
    assert!(unlinked(&forged), "{forged:?}");
}

/// LAND-6.1-5: any height can become a checkpoint, so s = 7, off the retired six-block grid,
/// imports both as the latest finalized landing and as an older retained one, whose parent
/// record is also off the grid.
#[tokio::test]
async fn import_at_a_checkpoint_off_the_retired_grid() {
    let fx = std::sync::Arc::new(Fixture::new(7, 7));
    let package = import_package(&fx, 7).await;
    let imported =
        authenticate_import(&package, frames(&fx, 7).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await
            .unwrap();
    assert_eq!(imported.landing().height, 7);
    assert_eq!(imported.val_state_before(), Some(&fx.val_states[&6]));
    assert_eq!(imported.state().val_state, fx.val_states[&7]);
    assert_eq!(imported.state().last_height, 7);

    let mut fx = Fixture::new(7, 13);
    fx.advance_import_frontier(13, 7, 0);
    let fx = std::sync::Arc::new(fx);
    assert_eq!(fx.snapshot.checkpoint_height, 13);
    let package = import_package(&fx, 7).await;
    let imported =
        authenticate_import(&package, frames(&fx, 7).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await
            .unwrap();
    assert_eq!(imported.landing().height, 7);
    assert_eq!(imported.state().val_state, fx.val_states[&7]);
}

/// A retained checkpoint below the latest finalized landing imports (ACC §7.7 older).
#[tokio::test]
async fn older_retained_checkpoint_below_the_latest_landing_imports() {
    let mut fx = Fixture::new(6, 18);
    fx.advance_import_frontier(12, 6, 0);
    fx.advance_import_frontier(18, 12, 0);
    let fx = std::sync::Arc::new(fx);
    let package = import_package(&fx, 6).await;
    let result =
        authenticate_import(&package, frames(&fx, 6).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await
            .unwrap();
    assert_eq!(result.landing().height, 6);
    assert_eq!(result.state().last_height, 6);
}

#[tokio::test]
async fn origin_uses_fixed_genesis_without_old_consensus_parent() {
    let fx = std::sync::Arc::new(Fixture::new(0, 0));
    let package = import_package(&fx, 0).await;
    let result = authenticate_import(&package, std::iter::empty(), &fx.params, &OwnL1(fx.clone()))
        .await
        .unwrap();
    assert_eq!(result.state().last_comet_hash, B256::ZERO);
    assert_eq!(result.block_id(), None);
    assert_eq!(result.state().val_state, fx.val_states[&0]);
    assert_eq!(result.state().execution_floor, None);
}

/// The imported state after s is the replay's whatever the genesis epoch length.
#[tokio::test]
async fn imported_state_matches_replay_for_every_epoch_length() {
    for length in [11, 12, 13, 24] {
        let fx = std::sync::Arc::new(Fixture::with_epoch(12, 12, 0, length));
        let package = import_package(&fx, 12).await;
        let imported = authenticate_import(
            &package,
            frames(&fx, 12).into_iter(),
            &fx.params,
            &OwnL1(fx.clone()),
        )
        .await
        .unwrap();
        assert_eq!(imported.state().val_state, fx.val_states[&12], "epoch length {length}");
    }
}

#[tokio::test]
async fn corrupt_bytes_reject_but_authenticated_envelope_contradiction_halts() {
    let fx = Fixture::new(6, 6);
    let package = import_package(&fx, 6).await;
    let mut bad = frames(&fx, 6);
    bad[5].as_mut().unwrap().block = Bytes::from_static(b"corrupt native protobuf");
    let fx = std::sync::Arc::new(fx);
    assert!(matches!(
        authenticate_import(&package, bad.into_iter(), &fx.params, &OwnL1(fx.clone())).await,
        Err(ImportError::Candidate(_))
    ));
    let mut owned = std::sync::Arc::try_unwrap(fx).ok().unwrap();
    let other_el = B256::repeat_byte(0xee);
    owned.import_landings(&[(
        6,
        other_el,
        B256::from_slice(owned.blocks[&6].block.header.hash().as_bytes()),
    )]);
    let fx = std::sync::Arc::new(owned);
    assert!(
        matches!(authenticate_import(&package, frames(&fx, 6).into_iter(), &fx.params, &OwnL1(fx.clone())).await, Err(ImportError::Safety(ref message)) if message.contains("execution hash"))
    );
}

/// The preimage for 11 that header(12) commits, its set for 13 included, so the derived state
/// after 12 is authenticated; its keys/powers for 13 differ from the generation's initial set.
async fn contradicting_pending_set() -> (Fixture, ImportPackage) {
    let mut fx = Fixture::with_epoch(12, 12, 0, 13);
    let mut package = import_package(&fx, 12).await;
    let mut before = fx.val_states[&11].clone();
    before.next.entries[0].power += 1;
    package.validator_state = before.encode().into();
    commit_terminal(&mut fx, 12, &before, true);
    (fx, package)
}

/// An authenticated validator state whose keys and powers differ from the generation's initial
/// set, which signs every height, halts for safety.
#[tokio::test]
async fn pending_set_other_than_the_initial_set_is_authenticated_safety_error() {
    let (fx, package) = contradicting_pending_set().await;
    let fx = std::sync::Arc::new(fx);
    assert!(
        matches!(authenticate_import(&package, frames(&fx, 12).into_iter(), &fx.params, &OwnL1(fx.clone())).await, Err(ImportError::Safety(ref message)) if message.contains("initial set"))
    );
}

#[tokio::test]
async fn incomplete_stream_waits_and_successor_is_not_consumed_as_import_state() {
    let fx = std::sync::Arc::new(Fixture::new(6, 7));
    let package = import_package(&fx, 6).await;
    assert!(matches!(
        authenticate_import(&package, frames(&fx, 5).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await,
        Err(ImportError::Unavailable(_))
    ));
    assert!(matches!(
        authenticate_import(&package, frames(&fx, 7).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await,
        Err(ImportError::Candidate(_))
    ));
}

#[test]
fn fast_blocks_require_more_than_height_limit_and_boundary_equality_is_not_expired() {
    let fx = Fixture::new(0, 1);
    let mut boundary = fx.blocks[&1].block.header.clone();
    // At 12 s per block the 16-block limit binds (w = s - 17); at 1 s the 3 min limit does
    // (w = s - 181).
    for (seconds_per_block, w) in [(12, 199_983), (1, 199_819)] {
        let heights = ((w + 1)..=200_000)
            .map(|h| {
                (
                    h,
                    tendermint::Time::from_unix_timestamp((h * seconds_per_block) as i64, 0)
                        .unwrap(),
                )
            })
            .collect::<Vec<_>>();
        boundary.height = w.try_into().unwrap();
        boundary.time =
            tendermint::Time::from_unix_timestamp((w * seconds_per_block) as i64, 0).unwrap();
        window::verify_complete_window(
            w,
            &heights,
            Some(&boundary),
            window::WindowContext { origin: 0, terminal: 200_000, latest_anchor: 200_000 },
        )
        .unwrap();
        // One block shorter omits w + 1, whose evidence stock still accepts.
        let mut shorter = boundary.clone();
        shorter.height = (w + 1).try_into().unwrap();
        shorter.time = heights[0].1;
        assert!(matches!(
            window::verify_complete_window(
                w + 1,
                &heights[1..],
                Some(&shorter),
                window::WindowContext { origin: 0, terminal: 200_000, latest_anchor: 200_000 }
            ),
            Err(ImportError::Unavailable(_))
        ));
        assert!(matches!(
            window::verify_complete_window(
                w,
                &heights,
                None,
                window::WindowContext { origin: 0, terminal: 200_000, latest_anchor: 200_000 }
            ),
            Err(ImportError::Unavailable(_))
        ));
        boundary.time =
            tendermint::Time::from_unix_timestamp(200_000 * seconds_per_block as i64 - 180, 0)
                .unwrap();
        assert!(matches!(
            window::verify_complete_window(
                w,
                &heights,
                Some(&boundary),
                window::WindowContext { origin: 0, terminal: 200_000, latest_anchor: 200_000 }
            ),
            Err(ImportError::Unavailable(_))
        ));
    }
}

async fn recovery_package(fx: &Fixture, height: u64) -> ImportPackage {
    use alloy_rlp::Decodable;
    let bytes = fx.snapshot.recovery_witness.as_ref().unwrap();
    let witness = abci::recovery::RecoveryWitness::decode(&mut bytes.as_ref()).unwrap();
    let origin = fx.snapshot.recovery.as_ref().unwrap();
    let anchor_height =
        abci::rules::decode_extra_data(&witness.el_header.extra_data).unwrap().anchor;
    let anchor = abci::AnchorWitness {
        l1_header: fx.l1_headers[&anchor_height].clone(),
        inbox: fx.import_witness(
            fx.params.inbox,
            &abci::l1::layout::inbox::anchor_slots(),
            anchor_height,
        ),
    };
    let keys = crate::test_utils::consensus_mpt::recovery::origin_keys();
    assert_eq!(keys.hash(), origin.fallback_keys_hash);
    let bootstrap = serde_json::from_value(serde_json::json!({
        "version": abci::recovery::RECOVERY_BOOTSTRAP_VERSION,
        "witness": bytes,
        "anchor": Bytes::from(alloy_rlp::encode(anchor)),
        "fallback_keys": keys,
    }))
    .unwrap();
    let genesis = GenesisDoc {
        genesis_time: tendermint::Time::from_unix_timestamp(origin.l1_timestamp as i64, 0)
            .unwrap()
            .to_rfc3339(),
        chain_id: abci::rules::chain_id_for(&fx.params, origin.generation).unwrap(),
        initial_height: (origin.height + 1).to_string(),
        consensus_params: abci::genesis::GenesisConsensusParams::etna(fx.params.n_max),
        validators: keys
            .keys()
            .iter()
            .map(|key| abci::genesis::GenesisValidator::new(*key, 1))
            .collect(),
        app_hash: abci::genesis::genesis_app_hash(
            origin.height,
            origin.el_hash,
            &keys.validator_set(),
        )
        .unwrap(),
        app_state: abci::genesis::AppStateJson::from(&witness),
    };
    ImportPackage {
        schema: IMPORT_SCHEMA,
        genesis,
        checkpoint_height: height,
        origin_header: Some(witness.el_header),
        recovery_bootstrap: Some(bootstrap),
        boundary_header: None,
        validator_state: if height == origin.height {
            Bytes::new()
        } else {
            fx.val_states[&(height - 1)].encode().into()
        },
        execution_headers: (0..=origin.height).map(|h| fx.headers[&h].clone()).collect(),
    }
}

#[tokio::test]
async fn recovery_origin_and_later_import_preserve_r_floor_and_historical_anchor() {
    for length in [6, 7, 8] {
        for height in [6, 12] {
            let fx = std::sync::Arc::new(
                crate::test_utils::consensus_mpt::recovery::fixture(length, height, height).await,
            );
            let package = recovery_package(&fx, height).await;
            let imported = authenticate_import(
                &package,
                frames(&fx, height).into_iter(),
                &fx.params,
                &OwnL1(fx.clone()),
            )
            .await
            .unwrap();
            assert_eq!(imported.state().val_state, fx.val_states[&height]);
            assert_eq!(imported.state().generation, 2);
            assert_eq!(imported.genesis().initial_height, "7");
            assert_eq!(imported.state().anchor_floor(), 20);
            if height == 6 {
                assert_eq!(imported.state().last_comet_hash, B256::ZERO);
                assert_eq!(imported.state().anchor.number, 10);
            }
        }
    }
}

/// An import at the generation's origin installs the state InitChain persists for the same
/// genesis: `VerifiedGenesis::origin_state` of the verified original genesis, over the origin
/// EL header and, for a recovery, the sidecar's historical anchor rather than R (DATA-5.4-1).
#[tokio::test]
async fn origin_import_installs_the_verified_genesis_origin_state() {
    let fx = std::sync::Arc::new(Fixture::new(0, 0));
    let package = import_package(&fx, 0).await;
    let imported =
        authenticate_import(&package, std::iter::empty(), &fx.params, &OwnL1(fx.clone()))
            .await
            .unwrap();
    let fixed = abci::genesis::verify_original_genesis(&package.genesis, &fx.params).unwrap();
    let parent = parent_info(package.origin_header.as_ref().unwrap(), 0).unwrap();
    let origin = fixed.origin_state(package.genesis.chain_id.clone(), parent, fixed.anchor.clone());
    assert_eq!(imported.state(), &origin.unwrap());

    let fx =
        std::sync::Arc::new(crate::test_utils::consensus_mpt::recovery::fixture(6, 6, 6).await);
    let package = recovery_package(&fx, 6).await;
    let imported =
        authenticate_import(&package, frames(&fx, 6).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await
            .unwrap();
    let fixed = abci::genesis::verify_original_genesis(&package.genesis, &fx.params).unwrap();
    let history = package.recovery_bootstrap.as_ref().unwrap().verify(&fx.params).unwrap();
    assert_ne!(history.anchor, fixed.anchor);
    let parent = abci::recovery::recovery_parent(&history.witness);
    let origin = fixed.origin_state(package.genesis.chain_id.clone(), parent, history.anchor);
    assert_eq!(imported.state(), &origin.unwrap());
}

#[test]
fn committed_preimage_with_excessive_stock_power_is_safety_error() {
    let fx = Fixture::new(6, 6);
    let mut state = fx.val_states[&5].clone();
    state.current.entries[0].power = i64::MAX;
    let bytes = state.encode();
    let parent = fx.headers[&5].hash_slow();
    let mut header = fx.blocks[&6].block.header.clone();
    header.app_hash = app_hash_of(parent, &bytes);
    assert!(matches!(authenticate_preimage(&bytes, &header, parent), Err(ImportError::Safety(_))));
}

#[tokio::test]
async fn authenticated_terminal_el_conflict_precedes_metadata_interpretation() {
    use crate::test_utils::consensus::{SigningKey, resign};
    let mut fx = Fixture::new(6, 6);
    let package = import_package(&fx, 6).await;
    let pair = fx.blocks.get_mut(&6).unwrap();
    let mut env = abci::EtnaEnvelope::decode(&pair.block.data[0]).unwrap();
    env.block.header.extra_data = Bytes::from_static(b"malformed");
    pair.block.data[0] = env.encode().to_vec();
    pair.block.header.data_hash = Some(crate::validate::data_hash(&pair.block.data));
    resign(
        pair,
        &fx.committees[&0],
        &[SigningKey::from_slice(&[1; 32]).unwrap(), SigningKey::from_slice(&[2; 32]).unwrap()],
    );
    let comet_hash = B256::from_slice(pair.block.header.hash().as_bytes());
    fx.import_landings(&[(6, fx.headers[&6].hash_slow(), comet_hash)]);
    let fx = std::sync::Arc::new(fx);
    assert!(
        matches!(authenticate_import(&package, frames(&fx, 6).into_iter(), &fx.params, &OwnL1(fx.clone())).await, Err(ImportError::Safety(ref message)) if message.contains("execution hash"))
    );
}

#[tokio::test]
async fn authenticated_terminal_el_conflict_precedes_parent_link_validation() {
    use crate::test_utils::consensus::{SigningKey, resign};
    let mut fx = Fixture::new(6, 6);
    let package = import_package(&fx, 6).await;
    let pair = fx.blocks.get_mut(&6).unwrap();
    let mut env = abci::EtnaEnvelope::decode(&pair.block.data[0]).unwrap();
    env.block.header.parent_hash = B256::repeat_byte(0xab);
    pair.block.data[0] = env.encode().to_vec();
    pair.block.header.data_hash = Some(crate::validate::data_hash(&pair.block.data));
    resign(
        pair,
        &fx.committees[&0],
        &[SigningKey::from_slice(&[1; 32]).unwrap(), SigningKey::from_slice(&[2; 32]).unwrap()],
    );
    let comet_hash = B256::from_slice(pair.block.header.hash().as_bytes());
    fx.import_landings(&[(6, fx.headers[&6].hash_slow(), comet_hash)]);
    let fx = std::sync::Arc::new(fx);
    assert!(
        matches!(authenticate_import(&package, frames(&fx, 6).into_iter(), &fx.params, &OwnL1(fx.clone())).await, Err(ImportError::Safety(ref message)) if message.contains("execution hash"))
    );
}

/// Break one generation-fixed native header field of a test block.
fn break_fixed_header_field(header: &mut tendermint::block::Header, field: &str) {
    match field {
        "consensus" => header.consensus_hash = tendermint::Hash::Sha256([3; 32]),
        "app" => header.version.app = 0,
        "chain" => header.chain_id = "etna-other".parse().unwrap(),
        _ => unreachable!("{field}"),
    }
}

#[tokio::test]
async fn forged_terminal_height_cannot_turn_unlanded_fixed_fields_into_a_safety_halt() {
    let fx = std::sync::Arc::new(Fixture::new(6, 6));
    let package = import_package(&fx, 6).await;
    for height in [5u64, 7] {
        for field in ["consensus", "app", "chain"] {
            let mut input = frames(&fx, 6);
            let frame = input.last_mut().unwrap().as_mut().unwrap();
            let mut raw = crate::native::RawBlock::decode(frame.block.as_ref()).unwrap();
            let mut header: tendermint::block::Header =
                raw.header.take().unwrap().try_into().unwrap();
            header.height = height.try_into().unwrap();
            break_fixed_header_field(&mut header, field);
            raw.header = Some(header.into());
            // The publisher has no authority to replace the terminal header. No resigning or
            // change to the own-L1 landing is needed for this attack.
            frame.block = raw.encode_to_vec().into();
            let result =
                authenticate_import(&package, input.into_iter(), &fx.params, &OwnL1(fx.clone()))
                    .await;
            assert!(
                matches!(result, Err(ImportError::Candidate(_))),
                "{height}/{field}: {result:?}"
            );
        }
    }
}

#[tokio::test]
async fn landed_wrong_fixed_native_header_fields_halt_even_with_valid_commits() {
    use crate::test_utils::consensus::{SigningKey, resign};
    // The native commit check also refuses another APP_VERSION or chain id; at the landed s
    // those are authenticated contradictions, not a bad certificate.
    for field in ["consensus", "app", "chain"] {
        let mut fx = Fixture::new(6, 6);
        let package = import_package(&fx, 6).await;
        let pair = fx.blocks.get_mut(&6).unwrap();
        break_fixed_header_field(&mut pair.block.header, field);
        resign(
            pair,
            &fx.committees[&0],
            &[SigningKey::from_slice(&[1; 32]).unwrap(), SigningKey::from_slice(&[2; 32]).unwrap()],
        );
        let comet = B256::from_slice(pair.block.header.hash().as_bytes());
        fx.import_landings(&[(6, fx.headers[&6].hash_slow(), comet)]);
        let fx = std::sync::Arc::new(fx);
        let result = authenticate_import(
            &package,
            frames(&fx, 6).into_iter(),
            &fx.params,
            &OwnL1(fx.clone()),
        )
        .await;
        assert!(
            matches!(result, Err(ImportError::Safety(ref m)) if m.contains("consensus parameters")),
            "{field}: {result:?}"
        );
    }
}

/// Re-sign `from` after a test edit, then relink and re-sign each later block through `to`.
fn relink_after(fx: &mut Fixture, from: u64, to: u64) {
    use crate::test_utils::consensus::{SigningKey, resign};
    let keys =
        [SigningKey::from_slice(&[1; 32]).unwrap(), SigningKey::from_slice(&[2; 32]).unwrap()];
    resign(fx.blocks.get_mut(&from).unwrap(), &fx.committees[&0], &keys);
    let mut previous = fx.blocks[&from].commit.clone();
    for h in from + 1..=to {
        let pair = fx.blocks.get_mut(&h).unwrap();
        pair.block.header.last_block_id = Some(previous.block_id);
        pair.block.header.last_commit_hash = Some(crate::validate::commit_hash(&previous));
        pair.block.last_commit = Some(previous);
        resign(pair, &fx.committees[&0], &keys);
        previous = pair.commit.clone();
    }
}

#[tokio::test]
async fn rule_failure_below_s_halts_only_when_the_landed_chain_contains_it() {
    for (case, landed) in ["consensus", "app", "chain", "anchor"]
        .into_iter()
        .flat_map(|case| [(case, true), (case, false)])
    {
        let mut fx = Fixture::new(6, 6);
        let package = import_package(&fx, 6).await;
        let pair = fx.blocks.get_mut(&3).unwrap();
        if case == "anchor" {
            let mut env = abci::EtnaEnvelope::decode(&pair.block.data[0]).unwrap();
            env.block.header.extra_data = Bytes::from_static(b"malformed");
            pair.block.data[0] = env.encode().to_vec();
            pair.block.header.data_hash = Some(crate::validate::data_hash(&pair.block.data));
        } else {
            break_fixed_header_field(&mut pair.block.header, case);
        }
        // A forged block keeps the published successors, whose links name the original block.
        relink_after(&mut fx, 3, if landed { 6 } else { 3 });
        let comet = B256::from_slice(fx.blocks[&6].block.header.hash().as_bytes());
        fx.import_landings(&[(6, fx.headers[&6].hash_slow(), comet)]);
        let fx = std::sync::Arc::new(fx);
        let result = authenticate_import(
            &package,
            frames(&fx, 6).into_iter(),
            &fx.params,
            &OwnL1(fx.clone()),
        )
        .await;
        if landed {
            assert!(
                matches!(result, Err(ImportError::Safety(ref m)) if m.contains("landed window block")),
                "{case}: {result:?}"
            );
        } else {
            assert!(
                matches!(result, Err(ImportError::Candidate(ref m)) if m.contains("not on the landed chain")),
                "{case}: {result:?}"
            );
        }
    }
}

/// Give block `at` one duplicate-vote evidence item, committed by its EvidenceHash, re-sign it
/// and relink and re-sign each later block through `to`.
fn land_evidence(fx: &mut Fixture, at: u64, to: u64) {
    use crate::test_utils::consensus::{SigningKey, merkle, raw_block, resign, sign_commit};
    let keys =
        [SigningKey::from_slice(&[1; 32]).unwrap(), SigningKey::from_slice(&[2; 32]).unwrap()];
    let item = tendermint_proto::v0_38::types::DuplicateVoteEvidence {
        total_voting_power: 2,
        validator_power: 1,
        ..Default::default()
    };
    let pair = fx.blocks.get_mut(&at).unwrap();
    pair.block.header.evidence_hash = Some(merkle(&[item.encode_to_vec()]));
    let mut raw = raw_block(&pair.block);
    raw.evidence = Some(crate::native::EvidenceList {
        evidence: vec![crate::native::Evidence {
            sum: Some(crate::native::evidence::Sum::DuplicateVoteEvidence(item)),
        }],
    });
    pair.raw_block = raw.encode_to_vec().into();
    pair.commit.block_id.part_set_header = crate::validate::block_parts(&raw);
    pair.commit.block_id.hash = pair.block.header.hash();
    let chain = pair.block.header.chain_id.clone();
    sign_commit(&mut pair.commit, &chain, &fx.committees[&0], &keys, pair.block.header.time);
    let mut previous = pair.commit.clone();
    for h in at + 1..=to {
        let pair = fx.blocks.get_mut(&h).unwrap();
        pair.block.header.last_block_id = Some(previous.block_id);
        pair.block.header.last_commit_hash = Some(crate::validate::commit_hash(&previous));
        pair.block.last_commit = Some(previous);
        resign(pair, &fx.committees[&0], &keys);
        previous = pair.commit.clone();
    }
}

/// Vector 2.u (CONS-3.1-10, DATA-5.4-2/5): a window block whose header commits nonempty evidence
/// halts for safety once the landed chain authenticates it, at s or below. A forged block off the
/// landed chain, or evidence bytes its header does not commit, only rejects the candidate.
#[tokio::test]
async fn window_evidence_halts_only_when_the_landed_chain_contains_it() {
    for (at, landed) in [(3u64, true), (6, true), (3, false)] {
        let mut fx = Fixture::new(6, 6);
        let package = import_package(&fx, 6).await;
        // A forged block keeps the published successors, whose links name the original block.
        land_evidence(&mut fx, at, if landed { 6 } else { at });
        let comet = B256::from_slice(fx.blocks[&6].block.header.hash().as_bytes());
        fx.import_landings(&[(6, fx.headers[&6].hash_slow(), comet)]);
        let fx = std::sync::Arc::new(fx);
        let result = authenticate_import(
            &package,
            frames(&fx, 6).into_iter(),
            &fx.params,
            &OwnL1(fx.clone()),
        )
        .await;
        if landed {
            assert!(
                matches!(result, Err(ImportError::Safety(ref m)) if m.contains("carries evidence")),
                "{at}: {result:?}"
            );
        } else {
            assert!(
                matches!(result, Err(ImportError::Candidate(ref m)) if m.contains("not on the landed chain")),
                "{at}: {result:?}"
            );
        }
    }
    // The landed header at 3 commits no evidence; a publisher's evidence bytes beside it fail
    // the EvidenceHash commitment.
    let fx = std::sync::Arc::new(Fixture::new(6, 6));
    let package = import_package(&fx, 6).await;
    let mut input = frames(&fx, 6);
    let frame = input[2].as_mut().unwrap();
    let mut raw = crate::native::RawBlock::decode(frame.block.as_ref()).unwrap();
    raw.evidence = Some(crate::native::EvidenceList {
        evidence: vec![crate::native::Evidence {
            sum: Some(crate::native::evidence::Sum::DuplicateVoteEvidence(Default::default())),
        }],
    });
    frame.block = raw.encode_to_vec().into();
    let result =
        authenticate_import(&package, input.into_iter(), &fx.params, &OwnL1(fx.clone())).await;
    assert!(
        matches!(result, Err(ImportError::Candidate(ref m)) if m.contains("evidence")),
        "{result:?}"
    );
}

#[tokio::test]
async fn rule_failure_below_s_waits_for_missing_frames_before_classifying() {
    let mut fx = Fixture::new(6, 6);
    let package = import_package(&fx, 6).await;
    fx.blocks.get_mut(&3).unwrap().block.header.consensus_hash = tendermint::Hash::Sha256([3; 32]);
    relink_after(&mut fx, 3, 6);
    let comet = B256::from_slice(fx.blocks[&6].block.header.hash().as_bytes());
    fx.import_landings(&[(6, fx.headers[&6].hash_slow(), comet)]);
    let fx = std::sync::Arc::new(fx);
    let mut input = frames(&fx, 6);
    input.truncate(4);
    let result =
        authenticate_import(&package, input.into_iter(), &fx.params, &OwnL1(fx.clone())).await;
    assert!(matches!(result, Err(ImportError::Unavailable(_))), "{result:?}");
}

#[tokio::test]
async fn landed_terminal_with_malformed_envelope_halts() {
    use crate::test_utils::consensus::{SigningKey, resign};
    let mut fx = Fixture::new(6, 6);
    let package = import_package(&fx, 6).await;
    let pair = fx.blocks.get_mut(&6).unwrap();
    pair.block.data.push(vec![0xc0]);
    pair.block.header.data_hash = Some(crate::validate::data_hash(&pair.block.data));
    resign(
        pair,
        &fx.committees[&0],
        &[SigningKey::from_slice(&[1; 32]).unwrap(), SigningKey::from_slice(&[2; 32]).unwrap()],
    );
    let comet = B256::from_slice(pair.block.header.hash().as_bytes());
    fx.import_landings(&[(6, fx.headers[&6].hash_slow(), comet)]);
    let fx = std::sync::Arc::new(fx);
    let result =
        authenticate_import(&package, frames(&fx, 6).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await;
    assert!(
        matches!(result, Err(ImportError::Safety(ref m)) if m.contains("envelope is malformed")),
        "{result:?}"
    );
}

#[tokio::test]
async fn restores_landed_fi_cursor_without_historical_fi_acquisition_or_trials() {
    let fx = std::sync::Arc::new(Fixture::with_forced(
        6,
        6,
        crate::test_utils::consensus_mpt::ForcedPlan {
            delay: 1,
            entries: vec![(10, 10)],
            consume_at: vec![3],
        },
    ));
    let package = import_package(&fx, 6).await;
    let imported =
        authenticate_import(&package, frames(&fx, 6).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await
            .unwrap();
    assert_eq!(imported.state().forced_cursor, 1);
    assert_eq!(imported.state().anchor.inbox.forced_inclusion_head, 0);
    assert_eq!(imported.state().parent.hash, fx.headers[&6].hash_slow());
}

#[test]
fn metadata_and_frame_schemas_reject_unknown_fields() {
    let fixture = Fixture::new(0, 0);
    let mut validator = serde_json::to_value(ImportValidator {
        key: fixture.committees[&0].state.members[0].pubkey,
        power: 1,
    })
    .unwrap();
    assert!(serde_json::from_value::<ImportValidator>(validator.clone()).is_ok());
    validator["priority"] = serde_json::json!(5);
    assert!(serde_json::from_value::<ImportValidator>(validator).is_err());
    assert!(
        serde_json::from_str::<WindowBlock>(
            r#"{"block":"0x","commit":"0x","validators":[],"trusted":true}"#
        )
        .is_err()
    );
}

#[tokio::test]
async fn own_finality_is_required_before_any_consensus_reads() {
    let mut fixture = Fixture::new(6, 6);
    let package = import_package(&fixture, 6).await;
    fixture.snapshot.l1_block_number = 9;
    let fixture = std::sync::Arc::new(fixture);
    let forbidden = std::iter::from_fn(|| -> Option<Result<WindowBlock, ImportError>> {
        panic!("unfinalized package read consensus bytes")
    });
    assert!(matches!(
        authenticate_import(&package, forbidden, &fixture.params, &OwnL1(fixture.clone())).await,
        Err(ImportError::Unavailable(_))
    ));
}

#[tokio::test]
async fn current_generation_change_rejects_before_any_consensus_reads() {
    let previous = Fixture::with_epoch(6, 6, 0, 8);
    let package = import_package(&previous, 6).await;
    let previous = std::sync::Arc::new(previous);
    let verified = authenticate_import(
        &package,
        frames(&previous, 6).into_iter(),
        &previous.params,
        &OwnL1(previous.clone()),
    )
    .await
    .unwrap();
    assert_eq!(verified.landing().height, 6);
    let current =
        std::sync::Arc::new(crate::test_utils::consensus_mpt::recovery::fixture(8, 12, 12).await);
    assert!(matches!(
        select_export(&package.genesis, 6, &current.params, &OwnL1(current.clone())).await,
        Err(ImportError::Candidate(_))
    ));
    let forbidden = std::iter::from_fn(|| -> Option<Result<WindowBlock, ImportError>> {
        panic!("superseded package read consensus bytes")
    });
    assert!(
        matches!(authenticate_import(&package, forbidden, &current.params, &OwnL1(current.clone())).await, Err(ImportError::Candidate(ref message)) if message.contains("current finalized generation"))
    );
}

/// DATA-5.4-5: a preimage that gives header(s)'s app_hash but whose set for s or s + 1 differs
/// from header(s)'s validators_hash or next_validators_hash proves a contradiction inside the
/// authenticated header.
#[tokio::test]
async fn committed_preimage_contradicting_header_validator_hashes_halts() {
    for current in [true, false] {
        let mut fx = Fixture::new(6, 6);
        let mut package = import_package(&fx, 6).await;
        let mut before = fx.val_states[&5].clone();
        let set = if current { &mut before.current } else { &mut before.next };
        set.entries[0].power += 1;
        package.validator_state = before.encode().into();
        commit_terminal(&mut fx, 6, &before, false);
        let fx = std::sync::Arc::new(fx);
        let result = authenticate_import(
            &package,
            frames(&fx, 6).into_iter(),
            &fx.params,
            &OwnL1(fx.clone()),
        )
        .await;
        assert!(
            matches!(result, Err(ImportError::Safety(ref m)) if m.contains("validators_hash")),
            "current={current}: {result:?}"
        );
    }
}

#[test]
fn header_floor_covers_blockhash_and_the_inherited_fence() {
    assert_eq!(header_floor(0, 900, 300), 601); // next block must prove q >= s-U+1
    assert_eq!(header_floor(0, 70_000, 65_536), 4_465);
    assert_eq!(header_floor(0, 1000, 100), 745); // s-255 (BLOCKHASH) dominates
    assert_eq!(header_floor(600, 900, 3600), 600); // origin bound
    assert_eq!(header_floor(700, 900, 300), 645); // BLOCKHASH context may precede o (5.3)
    assert_eq!(header_floor(0, 6, 3600), 0);
}

/// The window reaches the latest anchor-witness block at or below s and every height still
/// within an evidence age limit at s. With 4 s blocks and s = 500,000 the age limit keeps
/// 499,955 (45 blocks, 180 s), so with a later anchor the shortest window starts after 499,954;
/// with the latest anchor at 450,000 it starts after 449,999. One more leading block is still
/// complete; one fewer is not.
#[test]
fn window_reaches_the_latest_anchor_witness_and_the_evidence_age() {
    let fx = Fixture::new(0, 1);
    let time = |h: u64| tendermint::Time::from_unix_timestamp((h * 4) as i64, 0).unwrap();
    // The window (first - 1, s] as (height, time) pairs, starting at `first`.
    let heights_from = |first: u64| (first..=500_000).map(|h| (h, time(h))).collect::<Vec<_>>();
    let boundary_at = |w: u64| {
        let mut boundary = fx.blocks[&1].block.header.clone();
        boundary.height = w.try_into().unwrap();
        boundary.time = time(w);
        boundary
    };
    for (w, latest_anchor) in [(499_954u64, 499_990u64), (449_999, 450_000)] {
        let ctx = || window::WindowContext { origin: 0, terminal: 500_000, latest_anchor };
        window::verify_complete_window(w, &heights_from(w + 1), Some(&boundary_at(w)), ctx())
            .unwrap();
        // Only a shorter window is incomplete: one more leading block is still complete.
        window::verify_complete_window(w - 1, &heights_from(w), Some(&boundary_at(w - 1)), ctx())
            .unwrap();
        assert!(matches!(
            window::verify_complete_window(
                w + 1,
                &heights_from(w + 2),
                Some(&boundary_at(w + 1)),
                ctx()
            ),
            Err(ImportError::Unavailable(_))
        ));
    }
}

/// Vector 2.v (DATA-5.4-2): the window holds every height within either age limit at s,
/// including a height exactly at one. At s = 1802 with 4 s blocks a window from 1798 omits 1790,
/// still within 16 blocks; the shortest window reaches 1757, exactly 180 s before s. With 12 s
/// blocks it reaches 1786, exactly 16 blocks back, and with 1 s blocks 1622, exactly 180 s back.
/// A window one height longer is still complete; one height shorter remains incomplete.
#[test]
fn window_keeps_every_height_within_either_age_limit_including_equality() {
    let fx = Fixture::new(0, 1);
    let s = 1802u64;
    for (seconds_per_block, shortest_w) in [(4u64, 1756u64), (12, 1785), (1, 1621)] {
        let time = |h: u64| {
            tendermint::Time::from_unix_timestamp((h * seconds_per_block) as i64, 0).unwrap()
        };
        let check = |w: u64| {
            let mut boundary = fx.blocks[&1].block.header.clone();
            boundary.height = w.try_into().unwrap();
            boundary.time = time(w);
            let heights = (w + 1..=s).map(|h| (h, time(h))).collect::<Vec<_>>();
            window::verify_complete_window(
                w,
                &heights,
                Some(&boundary),
                window::WindowContext { origin: 0, terminal: s, latest_anchor: s },
            )
        };
        check(shortest_w).unwrap();
        check(shortest_w - 1).unwrap();
        assert!(
            matches!(check(shortest_w + 1), Err(ImportError::Unavailable(_))),
            "{seconds_per_block} s: the window omits a height exactly at an age limit"
        );
        if seconds_per_block == 4 {
            assert!(matches!(check(1797), Err(ImportError::Unavailable(_))));
        }
    }
}

#[tokio::test]
async fn embedded_successor_commit_requires_native_validity_full_id_and_exact_original_bytes() {
    use crate::{
        native::{CommitSig, Signature},
        test_utils::consensus::{SigningKey, resign},
    };
    for mutation in ["signature", "full ID", "different valid commit"] {
        let mut fx = Fixture::new(6, 6);
        let package = import_package(&fx, 6).await;
        let keys =
            [SigningKey::from_slice(&[1; 32]).unwrap(), SigningKey::from_slice(&[2; 32]).unwrap()];
        let mut prior = fx.blocks[&5].clone();
        let original = prior.commit.clone();
        let mut mutated = original.clone();
        match mutation {
            "signature" => {
                if let CommitSig::BlockIdFlagCommit { signature, .. } = &mut mutated.signatures[0] {
                    *signature = Some(Signature::try_from(vec![0; 65]).unwrap());
                } else {
                    panic!("expected block vote");
                }
            }
            "full ID" => {
                mutated.block_id.part_set_header =
                    tendermint::block::parts::Header::new(2, tendermint::Hash::Sha256([0xee; 32]))
                        .unwrap()
            }
            _ => {
                prior.commit.round = 1u16.into();
                resign(&mut prior, &fx.committees[&0], &keys);
                mutated = prior.commit;
                crate::validate::verify_commit(
                    &mutated,
                    &prior.block.header,
                    &fx.committees[&0].validators,
                    &package.genesis.chain_id,
                )
                .unwrap();
            }
        }
        assert_ne!(original, mutated);
        let tip = fx.blocks.get_mut(&6).unwrap();
        tip.block.header.last_commit_hash = Some(crate::validate::commit_hash(&mutated));
        tip.block.header.last_block_id = Some(mutated.block_id);
        tip.block.last_commit = Some(mutated);
        resign(tip, &fx.committees[&0], &keys);
        let comet = B256::from_slice(tip.block.header.hash().as_bytes());
        fx.import_landings(&[(6, fx.headers[&6].hash_slow(), comet)]);
        let fx = std::sync::Arc::new(fx);
        let result = authenticate_import(
            &package,
            frames(&fx, 6).into_iter(),
            &fx.params,
            &OwnL1(fx.clone()),
        )
        .await;
        let expected = match mutation {
            "signature" => "signature verification",
            "full ID" => "discontinuous",
            _ => "nonterminal own commit differs",
        };
        assert!(
            matches!(result, Err(ImportError::Candidate(ref message)) if message.contains(expected)),
            "{mutation}: {result:?}"
        );
    }
}

#[tokio::test]
async fn terminal_own_commit_cannot_authenticate_a_publisher_changed_last_commit_round() {
    use crate::test_utils::consensus::{SigningKey, resign};
    let mut fx = Fixture::new(6, 6);
    let package = import_package(&fx, 6).await;
    let pair = fx.blocks.get_mut(&6).unwrap();
    let landed_hash = pair.block.header.hash();
    let original_parts = pair.commit.block_id.part_set_header;
    let last = pair.block.last_commit.as_mut().unwrap();
    // Commit.Hash binds signature protobufs, not the round used to verify those signatures.
    last.round = 1u16.into();
    assert_eq!(pair.block.header.last_commit_hash, Some(crate::validate::commit_hash(last)));
    // Historical quorum keys can certify a new terminal part-set for the same landed header.
    // That part-set is not anchored independently to L1, so it cannot turn an invalid embedded
    // certificate into authority to halt the importer.
    resign(
        pair,
        &fx.committees[&0],
        &[SigningKey::from_slice(&[1; 32]).unwrap(), SigningKey::from_slice(&[2; 32]).unwrap()],
    );
    assert_eq!(pair.block.header.hash(), landed_hash);
    assert_ne!(pair.commit.block_id.part_set_header, original_parts);
    crate::validate::verify_commit(
        &pair.commit,
        &pair.block.header,
        &fx.committees[&0].validators,
        &package.genesis.chain_id,
    )
    .unwrap();
    let fx = std::sync::Arc::new(fx);
    let result =
        authenticate_import(&package, frames(&fx, 6).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await;
    assert!(
        matches!(result, Err(ImportError::Candidate(ref detail)) if detail.contains("signature verification failed")),
        "{result:?}"
    );
}

/// DATA-5.4-2: only the own-L1 landing ties the window to the real chain. A terminal header the
/// committee keys re-signed, changed in a field no other check reads, must still be refused.
#[tokio::test]
async fn terminal_comet_hash_must_equal_the_own_l1_finalized_landing() {
    use crate::test_utils::consensus::{SigningKey, resign};
    let mut fx = Fixture::new(6, 6);
    let package = import_package(&fx, 6).await;
    let pair = fx.blocks.get_mut(&6).unwrap();
    let landed = pair.block.header.hash();
    pair.block.header.last_results_hash = Some(tendermint::Hash::Sha256([0xab; 32]));
    resign(
        pair,
        &fx.committees[&0],
        &[SigningKey::from_slice(&[1; 32]).unwrap(), SigningKey::from_slice(&[2; 32]).unwrap()],
    );
    assert_ne!(pair.block.header.hash(), landed);
    let fx = std::sync::Arc::new(fx);
    let result =
        authenticate_import(&package, frames(&fx, 6).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await;
    assert!(
        matches!(result, Err(ImportError::Candidate(ref m)) if m.contains("terminal Comet hash differs from finalized landing")),
        "{result:?}"
    );
}

/// DATA-5.4-2: the frame's keys and powers must hash to the signed header's ValidatorsHash, so
/// real signatures cannot certify forged powers.
#[tokio::test]
async fn frame_validators_must_match_the_header_validators_hash() {
    let fx = std::sync::Arc::new(Fixture::new(6, 6));
    let package = import_package(&fx, 6).await;
    for height in [3usize, 6] {
        let mut input = frames(&fx, 6);
        let validators = &mut input[height - 1].as_mut().unwrap().validators;
        // Raise the first stock slot, which keeps it first, so the slot order still matches.
        let first = (0..validators.len())
            .min_by_key(|&i| (std::cmp::Reverse(validators[i].power), validators[i].key.address()))
            .unwrap();
        validators[first].power += 1;
        let result =
            authenticate_import(&package, input.into_iter(), &fx.params, &OwnL1(fx.clone())).await;
        assert!(
            matches!(result, Err(ImportError::Candidate(ref m)) if m.contains("validator set commitment")),
            "{height}: {result:?}"
        );
    }
}

/// DATA-5.4-2: each window block's ValidatorsHash must equal its predecessor's NextValidatorsHash
/// and its time must follow the predecessor's. A landed break halts; an unlanded one is refused.
#[tokio::test]
async fn window_validator_and_time_links_halt_only_when_the_landed_chain_contains_them() {
    for (case, landed) in
        ["validators", "time"].into_iter().flat_map(|case| [(case, true), (case, false)])
    {
        let mut fx = Fixture::new(6, 6);
        let package = import_package(&fx, 6).await;
        // Both cases break the link from block 2 to block 3 and leave each block's own
        // certificate valid.
        let from = if case == "validators" {
            fx.blocks.get_mut(&2).unwrap().block.header.next_validators_hash =
                tendermint::Hash::Sha256([5; 32]);
            2
        } else {
            let prior = fx.blocks[&2].block.header.time;
            fx.blocks.get_mut(&3).unwrap().block.header.time = prior;
            3
        };
        relink_after(&mut fx, from, if landed { 6 } else { 3 });
        let comet = B256::from_slice(fx.blocks[&6].block.header.hash().as_bytes());
        fx.import_landings(&[(6, fx.headers[&6].hash_slow(), comet)]);
        let fx = std::sync::Arc::new(fx);
        let result = authenticate_import(
            &package,
            frames(&fx, 6).into_iter(),
            &fx.params,
            &OwnL1(fx.clone()),
        )
        .await;
        if landed {
            assert!(
                matches!(result, Err(ImportError::Safety(ref m)) if m.contains("discontinuous native validator/time chain")),
                "{case}: {result:?}"
            );
        } else {
            assert!(
                matches!(result, Err(ImportError::Candidate(ref m)) if m.contains("not on the landed chain")),
                "{case}: {result:?}"
            );
        }
    }
}

/// DATA-5.4-4: the EL fence q the post-s anchor inherits must be one of the authenticated EL
/// headers the import retains. Own L1 here records another hash for checkpoint 6 at every anchor
/// above genesis, and the landed chain is built over those anchors, so every other check passes:
/// both inputs are authenticated, and the contradiction halts.
#[tokio::test]
async fn inherited_checkpoint_absent_from_the_authenticated_ancestry_halts() {
    let forged = B256::repeat_byte(0xee);
    let fx = std::sync::Arc::new(Fixture::with_inherited_checkpoint_hash(12, 12, forged));
    assert_eq!(fx.anchors[&12].inbox.last_checkpoint_height, 6);
    assert_eq!(fx.anchors[&12].inbox.last_checkpoint_hash, forged);
    assert_ne!(fx.headers[&6].hash_slow(), forged);
    let package = import_package(&fx, 12).await;
    let result =
        authenticate_import(&package, frames(&fx, 12).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await;
    assert!(
        matches!(result, Err(ImportError::Safety(ref m)) if m.contains("inherited anchor checkpoint")),
        "{result:?}"
    );
}

#[tokio::test]
async fn publisher_reader_cannot_inject_an_authenticated_safety_halt() {
    let fx = std::sync::Arc::new(Fixture::new(6, 6));
    let package = import_package(&fx, 6).await;
    let forged = std::iter::once(Err(ImportError::Safety("publisher says halt".into())));
    assert!(matches!(
        authenticate_import(&package, forged, &fx.params, &OwnL1(fx.clone())).await,
        Err(ImportError::Candidate(_))
    ));
}

#[tokio::test(flavor = "current_thread")]
async fn immediately_ready_l1_and_frame_cache_still_permit_cancellation() {
    use std::sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    };
    let fx = Arc::new(Fixture::new(6, 6));
    let package = import_package(&fx, 6).await;
    let own = OwnL1(fx.clone());
    let (tx, rx) = tokio::sync::oneshot::channel();
    let mut signal = Some(tx);
    let count = Arc::new(AtomicUsize::new(0));
    let observed = count.clone();
    let stream = frames(&fx, 6).into_iter().inspect(move |_| {
        observed.fetch_add(1, Ordering::SeqCst);
        if let Some(tx) = signal.take() {
            tx.send(()).unwrap();
        }
    });
    tokio::select! {
        biased;
        _ = rx => {},
        result = authenticate_import(&package, stream, &fx.params, &own) => panic!("stream exhausted without giving cancellation a turn: success={}", result.is_ok()),
    }
    assert_eq!(count.load(Ordering::SeqCst), 1);
}

#[tokio::test]
async fn same_generation_rollback_orphan_is_not_a_retained_settled_import_origin() {
    let mut fx = Fixture::with_progressing_epochs(12, 42);
    fx.advance_import_frontier(24, 12, 0);
    fx.advance_import_frontier(36, 24, 0);
    fx.advance_import_frontier(12, 0, 1);
    fx.advance_import_frontier(42, 12, 1);
    let fx = std::sync::Arc::new(fx);
    assert_eq!(fx.snapshot.generation, 0);
    let nonce = abci::l1::layout::inbox::slot(292);
    let proof = fx.import_witness(fx.params.inbox, &[nonce], fx.snapshot.l1_block_number);
    assert_eq!(
        abci::l1::mpt::verify_account_witness(fx.snapshot.l1_header.state_root(), &proof, &[nonce])
            .unwrap()
            .get(nonce),
        Some(U256::from(1))
    );
    // Both old records still have genuine proofs at the same final root and retain g=0.
    for height in [24, 36] {
        let slots = abci::l1::layout::inbox::landing_record_slots(height);
        let proof = fx.import_witness(fx.params.inbox, &slots, fx.snapshot.l1_block_number);
        let verified = abci::l1::mpt::verify_account_witness(
            fx.snapshot.l1_header.state_root(),
            &proof,
            &slots,
        )
        .unwrap();
        assert_eq!(B256::from(verified.get(slots[1]).unwrap()), fx.headers[&height].hash_slow());
        let package = import_package(&fx, height).await;
        let reads = std::cell::Cell::new(0usize);
        let stream = frames(&fx, height).into_iter().inspect(|_| reads.set(reads.get() + 1));
        let result = authenticate_import(&package, stream, &fx.params, &OwnL1(fx.clone())).await;
        assert_eq!(reads.get(), 0, "discarded landing must be rejected before window reads");
        assert!(
            matches!(result, Err(ImportError::Candidate(ref m)) if m.contains("selected settled history")),
            "orphan {height}: accepted={}",
            result.is_ok()
        );
    }
    let package = import_package(&fx, 12).await;
    let accepted =
        authenticate_import(&package, frames(&fx, 12).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await
            .unwrap();
    assert_eq!(accepted.landing().height, 12);
}

#[tokio::test]
async fn future_unfinalized_landing_waits_but_rolled_back_record_above_frontier_rejects() {
    let mut fx = Fixture::new(6, 12);
    let package = import_package(&fx, 12).await;
    let pending = std::sync::Arc::new(fx);
    let no_frames = || {
        std::iter::from_fn(|| -> Option<Result<WindowBlock, ImportError>> {
            panic!("post-frontier candidate consumed consensus history")
        })
    };
    assert!(matches!(
        authenticate_import(&package, no_frames(), &pending.params, &OwnL1(pending.clone())).await,
        Err(ImportError::Unavailable(_))
    ));
    fx = std::sync::Arc::try_unwrap(pending).ok().unwrap();
    fx.advance_import_frontier(12, 6, 0);
    fx.advance_import_frontier(6, 0, 1);
    let reverted = std::sync::Arc::new(fx);
    assert!(matches!(
        authenticate_import(&package, no_frames(), &reverted.params, &OwnL1(reverted.clone()))
            .await,
        Err(ImportError::Candidate(_))
    ));
}

#[tokio::test]
async fn review_substituted_recovery_sidecar_is_a_candidate_error() {
    use alloy_rlp::Decodable;
    let fx =
        std::sync::Arc::new(crate::test_utils::consensus_mpt::recovery::fixture(8, 12, 12).await);
    let mut package = recovery_package(&fx, 12).await;
    let bootstrap = package.recovery_bootstrap.as_ref().unwrap();
    let mut witness = bootstrap.verify(&fx.params).unwrap().witness;
    let mut header = Header::decode(&mut witness.recovery_header.raw().as_ref()).unwrap();
    header.parent_hash = B256::repeat_byte(0xaa);
    witness.recovery_header = RawL1Header::from(&header);
    witness.finalized_header = witness.recovery_header.clone();
    let mut json = serde_json::to_value(bootstrap).unwrap();
    json["witness"] = serde_json::json!(Bytes::from(alloy_rlp::encode(&witness)));
    let sidecar: abci::recovery::RecoveryBootstrap = serde_json::from_value(json).unwrap();
    assert!(sidecar.verify(&fx.params).is_ok());
    package.recovery_bootstrap = Some(sidecar);
    let err =
        authenticate_import(&package, frames(&fx, 12).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await
            .unwrap_err();
    assert!(matches!(err, ImportError::Candidate(_)), "{err}");
}

/// An own L1 whose finalized number recedes to `receded` once the recovery canonicality check
/// has read its Inbox proof, i.e. just before the historical recovery anchor is checked.
struct RecedesAfterRecoveryCheck {
    own: OwnL1,
    receded: u64,
    proof_read: std::sync::atomic::AtomicBool,
}
#[async_trait]
impl L1Source for RecedesAfterRecoveryCheck {
    async fn finalized_number(&self) -> Result<u64, L1Error> {
        if self.proof_read.load(std::sync::atomic::Ordering::SeqCst) {
            return Ok(self.receded);
        }
        self.own.finalized_number().await
    }
    async fn canonical_hash(&self, n: u64) -> Result<B256, L1Error> {
        self.own.canonical_hash(n).await
    }
    async fn header(&self, n: u64) -> Result<RawL1Header, L1Error> {
        self.own.header(n).await
    }
    async fn account_witness(
        &self,
        address: Address,
        slots: &[B256],
        n: u64,
    ) -> Result<AccountWitness, L1Error> {
        self.proof_read.store(true, std::sync::atomic::Ordering::SeqCst);
        self.own.account_witness(address, slots, n).await
    }
    async fn forced_transaction(&self, a: Address, i: u64, n: u64) -> Result<Bytes, L1Error> {
        self.own.forced_transaction(a, i, n).await
    }
    async fn storage_at(&self, a: Address, s: B256, n: u64) -> Result<U256, L1Error> {
        self.own.storage_at(a, s, n).await
    }
}

/// The historical recovery anchor is authenticated from the own finalized L1 (DATA-5.4-1): one
/// the own L1 has not finalized is missing material, not a bad candidate (DATA-5.4-5).
#[tokio::test]
async fn recovery_historical_anchor_not_final_in_own_l1_is_unavailable() {
    let fx =
        std::sync::Arc::new(crate::test_utils::consensus_mpt::recovery::fixture(6, 6, 6).await);
    let package = recovery_package(&fx, 6).await;
    let anchor = package.recovery_bootstrap.as_ref().unwrap().verify(&fx.params).unwrap().anchor;
    let own_l1 = RecedesAfterRecoveryCheck {
        own: OwnL1(fx.clone()),
        receded: anchor.number - 1,
        proof_read: Default::default(),
    };
    let err = authenticate_import(&package, frames(&fx, 6).into_iter(), &fx.params, &own_l1)
        .await
        .unwrap_err();
    assert!(
        matches!(&err, ImportError::Unavailable(m) if m.contains("historical anchor is not final")),
        "{err}"
    );
}

struct BeforeDeployment {
    own: OwnL1,
    header: RawL1Header,
    proof_reads: std::sync::atomic::AtomicUsize,
}
#[async_trait]
impl L1Source for BeforeDeployment {
    async fn finalized_number(&self) -> Result<u64, L1Error> {
        self.own.finalized_number().await
    }
    async fn canonical_hash(&self, n: u64) -> Result<B256, L1Error> {
        if n == 9 { Ok(self.header.hash()) } else { self.own.canonical_hash(n).await }
    }
    async fn header(&self, n: u64) -> Result<RawL1Header, L1Error> {
        if n == 9 { Ok(self.header.clone()) } else { self.own.header(n).await }
    }
    async fn account_witness(
        &self,
        address: Address,
        slots: &[B256],
        n: u64,
    ) -> Result<AccountWitness, L1Error> {
        if n != 9 {
            return self.own.account_witness(address, slots, n).await;
        }
        self.proof_reads.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
        Ok(AccountWitness {
            address,
            nonce: 0,
            balance: U256::ZERO,
            storage_root: alloy_consensus::EMPTY_ROOT_HASH,
            code_hash: alloy_primitives::KECCAK256_EMPTY,
            account_proof: vec![],
            storage: slots
                .iter()
                .map(|slot| abci::StorageProof { slot: *slot, value: U256::ZERO, proof: vec![] })
                .collect(),
        })
    }
    async fn forced_transaction(&self, a: Address, i: u64, n: u64) -> Result<Bytes, L1Error> {
        self.own.forced_transaction(a, i, n).await
    }
    async fn storage_at(&self, a: Address, s: B256, n: u64) -> Result<U256, L1Error> {
        self.own.storage_at(a, s, n).await
    }
}

#[tokio::test]
async fn review_self_signed_prefix_cannot_trigger_an_own_l1_exclusion_halt() {
    use crate::test_utils::consensus::{committee, resign};
    let mut fx = Fixture::new(6, 6);
    let package = import_package(&fx, 6).await;
    let first = fx.blocks.get_mut(&1).unwrap();
    let mut env = abci::EtnaEnvelope::decode(&first.block.data[0]).unwrap();
    env.anchor = None;
    env.block.header.extra_data = abci::rules::encode_extra_data(&abci::rules::ExtraData {
        basefee_sharing_pctg: abci::rules::BASEFEE_SHARING_PCTG,
        generation: 0,
        anchor: 9,
        miss_bitmap: 0,
    })
    .unwrap();
    first.block.data[0] = env.encode().to_vec();
    first.block.header.data_hash = Some(crate::validate::data_hash(&first.block.data));
    let (_, attacker, keys) = committee(&[7], 0);
    assert_ne!(attacker.validators.hash(), fx.committees[&0].validators.hash());
    first.block.header.validators_hash = attacker.validators.hash();
    first.block.header.proposer_address = attacker.validators.validators()[0].address;
    resign(first, &attacker, &keys);
    let fx = std::sync::Arc::new(fx);
    let source = BeforeDeployment {
        own: OwnL1(fx.clone()),
        header: RawL1Header::from(&Header {
            number: 9,
            state_root: alloy_consensus::EMPTY_ROOT_HASH,
            ..Default::default()
        }),
        proof_reads: Default::default(),
    };
    alloy_trie::proof::verify_proof(
        source.header.state_root(),
        alloy_trie::Nibbles::unpack(keccak256(fx.params.inbox)),
        None,
        std::iter::empty(),
    )
    .unwrap();
    let mut input = frames(&fx, 6);
    input[0].as_mut().unwrap().validators = attacker
        .state
        .members
        .iter()
        .map(|m| ImportValidator { key: m.pubkey, power: m.power })
        .collect();
    let err =
        authenticate_import(&package, input.into_iter(), &fx.params, &source).await.unwrap_err();
    assert!(matches!(err, ImportError::Candidate(_)), "{err}");
    assert_eq!(source.proof_reads.load(std::sync::atomic::Ordering::SeqCst), 0);
}

#[tokio::test]
async fn review_ancillary_terminal_bytes_cannot_hide_proven_contradictions() {
    for case in [
        "EL truncated commit",
        "EL oversized validators",
        "committed set truncated commit",
        "bad DataHash",
        "honest terminal malformed commit",
    ] {
        let mut fx = Fixture::new(6, 6);
        let mut package = import_package(&fx, 6).await;
        let comet = B256::from_slice(fx.blocks[&6].block.header.hash().as_bytes());
        let conflict = case.starts_with("EL");
        if case.starts_with("committed set") {
            // Header(6) commits a preimage whose set for 6 contradicts its validators_hash.
            let mut before = fx.val_states[&5].clone();
            before.current.entries[0].power += 1;
            package.validator_state = before.encode().into();
            commit_terminal(&mut fx, 6, &before, false);
        } else {
            let el = if conflict || case == "bad DataHash" {
                B256::repeat_byte(0xfe)
            } else {
                fx.headers[&6].hash_slow()
            };
            fx.import_landings(&[(6, el, comet)]);
        }
        let fx = std::sync::Arc::new(fx);
        let mut inputs = frames(&fx, 6);
        let frame = inputs.last_mut().unwrap().as_mut().unwrap();
        if case.ends_with("validators") {
            frame.validators.resize(fx.params.n_max + 1, frame.validators[0].clone());
        } else {
            frame.commit = Bytes::from_static(&[0xff]);
        }
        if case == "bad DataHash" {
            let mut raw = crate::native::RawBlock::decode(frame.block.as_ref()).unwrap();
            raw.data.as_mut().unwrap().txs[0].push(0);
            frame.block = raw.encode_to_vec().into();
        }
        let err = authenticate_import(&package, inputs.into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await
            .unwrap_err();
        match case {
            "bad DataHash" => assert!(
                matches!(err,ImportError::Candidate(ref e) if e.contains("DataHash")),
                "{case}: {err}"
            ),
            "honest terminal malformed commit" => {
                assert!(matches!(err, ImportError::Candidate(_)), "{case}: {err}")
            }
            _ => assert!(matches!(err, ImportError::Safety(_)), "{case}: {err}"),
        }
    }
}

#[tokio::test]
async fn review_trailing_reader_failure_cannot_hide_an_initial_set_contradiction() {
    let (fx, package) = contradicting_pending_set().await;
    let fx = std::sync::Arc::new(fx);
    let input = frames(&fx, 12)
        .into_iter()
        .chain(std::iter::once(Err(ImportError::Unavailable("trailing source fault".into()))));
    let err =
        authenticate_import(&package, input, &fx.params, &OwnL1(fx.clone())).await.unwrap_err();
    assert!(matches!(err,ImportError::Safety(ref m) if m.contains("initial set")), "{err}");
}

#[tokio::test]
async fn review_recovery_first_consensus_block_refuses_old_generation_commit() {
    use crate::test_utils::consensus::{SigningKey, resign};
    let mut fx = crate::test_utils::consensus_mpt::recovery::fixture(8, 12, 12).await;
    let old = Fixture::with_epoch(6, 6, 0, 8);
    let mut previous = old.blocks[&6].commit.clone();
    assert_eq!(
        B256::from_slice(previous.block_id.hash.as_bytes()),
        fx.snapshot.recovery.as_ref().unwrap().comet_hash
    );
    for h in 7..=12 {
        let pair = fx.blocks.get_mut(&h).unwrap();
        pair.block.header.last_block_id = Some(previous.block_id);
        pair.block.header.last_commit_hash = Some(crate::validate::commit_hash(&previous));
        pair.block.last_commit = Some(previous);
        resign(
            pair,
            &fx.committees[&0],
            &[SigningKey::from_slice(&[1; 32]).unwrap(), SigningKey::from_slice(&[2; 32]).unwrap()],
        );
        previous = pair.commit.clone();
    }
    fx.import_landings(&[(
        12,
        fx.headers[&12].hash_slow(),
        B256::from_slice(previous.block_id.hash.as_bytes()),
    )]);
    let fx = std::sync::Arc::new(fx);
    let package = recovery_package(&fx, 12).await;
    let result =
        authenticate_import(&package, frames(&fx, 12).into_iter(), &fx.params, &OwnL1(fx.clone()))
            .await;
    // L1 landed this chain, so its old-generation LastCommit is an authenticated contradiction.
    assert!(
        matches!(result, Err(ImportError::Safety(ref m)) if m.contains("previous block/commit")),
        "{result:?}"
    );
}
