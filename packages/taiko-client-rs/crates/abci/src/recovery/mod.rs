//! Proof-checked fixed recovery origins and nonmutating own-L1 authentication.

/// Nonmutating discovery and own-L1 reauthentication.
mod fetch;
/// Deterministic recovery genesis and historical bootstrap provenance.
mod genesis;
/// Versioned evidence and authenticated result types.
mod types;
/// Pure proof verification.
mod verify;

pub use fetch::{
    authenticate_recovery, authenticate_recovery_with_headers, check_recovery_canonicality,
};
pub use genesis::{
    RECOVERY_BOOTSTRAP_VERSION, RecoveryBootstrap, VerifiedBootstrap, build_recovery_genesis,
    recovery_parent,
};
pub(crate) use genesis::{
    bootstrap_from, historical_anchor, origin_fallback_keys, recovery_anchor,
};
pub use types::{RECOVERY_WITNESS_VERSION, RecoveryError, RecoveryOrigin, RecoveryWitness};
pub(crate) use verify::{VerifiedRecovery, verify_recovery};
pub use verify::{verify_recovery_deployment, verify_recovery_witness};

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        l1::{RawL1Header, layout::inbox},
        test_utils::{
            EngineCall, L1Call, l1_header, recovery_fallback_keys, recovery_fixture as fixture,
        },
    };
    use alloy_primitives::{B256, U256};

    #[test]
    fn recovery_witness_binds_fixed_origin_and_its_fallback_keys_hash() {
        let (fx, _, _, witness) = fixture(1, 6, 1);
        let origin = verify_recovery_witness(&witness, &fx.params).unwrap();
        assert_eq!((origin.generation, origin.height, origin.l1_number), (1, 6, 100));
        assert_eq!(origin.forced_cursor, 3);
        assert_eq!(origin.fallback_keys_hash, recovery_fallback_keys().hash());
        assert_eq!(origin.state_root, B256::repeat_byte(0x55));
        assert_eq!(origin.comet_hash, B256::repeat_byte(0xcc));
    }

    /// Only the current witness version verifies or decodes from a genesis `app_state`; a
    /// version-1 witness, which carried R's registry committee, is refused.
    #[test]
    fn recovery_witness_version_1_is_refused() {
        let (fx, _, _, mut w) = fixture(1, 6, 1);
        assert_eq!(w.version, RECOVERY_WITNESS_VERSION);
        assert_eq!(RECOVERY_WITNESS_VERSION, 2);
        w.version = 1;
        assert!(matches!(
            verify_recovery_witness(&w, &fx.params),
            Err(RecoveryError::Invalid(message)) if message.contains("version")
        ));
        let app_state = serde_json::to_vec(&crate::AppStateJson::from(&w)).unwrap();
        assert!(matches!(
            crate::decode_bootstrap_state(&app_state),
            Err(crate::GenesisError::UnsupportedRecovery(_))
        ));
    }

    /// RECOV-8.1-6: expectedC is the c that landers settled, and a landing may end at any
    /// height, so the fixed origin need not lie on any grid.
    #[test]
    fn recovery_accepts_a_retained_landing_at_any_height() {
        let (fx, _, _, witness) = fixture(1, 7, 1);
        let origin = verify_recovery_witness(&witness, &fx.params).unwrap();
        assert_eq!((origin.generation, origin.height, origin.l1_number), (1, 7, 100));
        assert_eq!(origin.el_hash, witness.el_header.hash_slow());
    }

    #[test]
    fn recovery_rejects_each_tampered_proven_origin_or_landing_word() {
        let (fx, _, _, w) = fixture(1, 6, 1);
        for slot in inbox::origin_slots(1).into_iter().chain(inbox::landing_record_slots(6)) {
            for finalized in [false, true] {
                let mut bad = w.clone();
                let proof =
                    if finalized { &mut bad.finalized_inbox } else { &mut bad.recovery_inbox };
                proof.storage.iter_mut().find(|p| p.slot == slot).unwrap().value ^= U256::from(1);
                assert!(verify_recovery_witness(&bad, &fx.params).is_err(), "{slot}");
            }
        }
    }

    #[test]
    fn recovery_rejects_headers_config_and_domain_tampering() {
        let (fx, _, _, w) = fixture(1, 6, 1);
        let mut variants = vec![w.clone(); 6];
        variants[0].recovery_header = RawL1Header::from(&l1_header(100, 1));
        variants[1].el_header.state_root = B256::ZERO;
        variants[2].parent_headers[0].timestamp += 1;
        variants[3].version = RECOVERY_WITNESS_VERSION + 1;
        variants[4].generation = 0;
        variants[5].parent_headers.clear();
        for bad in variants {
            assert!(verify_recovery_witness(&bad, &fx.params).is_err());
        }
        let mut params = fx.params.clone();
        params.l2_chain_id += 1;
        assert!(matches!(
            verify_recovery_witness(&w, &params),
            Err(RecoveryError::ConfigMismatch { .. })
        ));
    }

    #[test]
    fn recovery_accepts_zero_and_repeated_generation_with_older_landing() {
        for (generation, c) in [(1, 0), (2, 6), (2, 24)] {
            let (fx, _, _, w) = fixture(generation, c, generation);
            let origin = verify_recovery_witness(&w, &fx.params).unwrap();
            assert_eq!(origin.height, c);
            assert_eq!(origin.fallback_keys_hash, recovery_fallback_keys().hash());
        }
    }

    #[test]
    fn recovery_requires_current_generation_at_end_of_same_block() {
        let (fx, _, _, w) = fixture(1, 6, 2);
        assert!(matches!(
            verify_recovery_witness(&w, &fx.params),
            Err(RecoveryError::Superseded { requested: 1, current: 2 })
        ));
    }

    #[tokio::test]
    async fn recovery_fetch_checks_finality_and_never_builds_or_moves_forkchoice() {
        let (fx, l1, engine, w) = fixture(1, 6, 1);
        let fetched = authenticate_recovery(&l1, &engine, &fx.params, 1).await.unwrap();
        assert_eq!(fetched, w);
        assert!(engine.calls().iter().all(|c| matches!(c, EngineCall::HeaderByNumber(_))));
        check_recovery_canonicality(&l1, &fx.params, &w).await.unwrap();
        l1.set_finalized(99);
        assert!(matches!(
            check_recovery_canonicality(&l1, &fx.params, &w).await,
            Err(RecoveryError::Unavailable(_))
        ));
    }

    /// One finalized read bounds the retained headers and the current observation alike, so a
    /// receding own-L1 answer is missing data (SYNC-9-7): a later answer below R is never read,
    /// where proving the pre-recovery Inbox there would look like an invalid origin; and an
    /// answer below R itself leaves R not final.
    #[tokio::test]
    async fn recovery_recheck_reads_finality_once_and_receding_below_r_is_unavailable() {
        let (fx, l1, _, w) = fixture(1, 6, 1);
        let below_r = fx.genesis.l1_0;
        assert!(below_r < w.recovery_header.number());
        // Three answers at the finalized head, then one that recedes below R.
        l1.state().finalized_script.extend([Ok(110), Ok(110), Ok(110), Ok(below_r)]);
        check_recovery_canonicality(&l1, &fx.params, &w).await.unwrap();
        let reads = l1.calls().iter().filter(|c| matches!(c, L1Call::Finalized)).count();
        assert_eq!(reads, 1, "one finalized read per recheck");

        l1.state().finalized_script.clear();
        l1.set_finalized(below_r);
        assert!(matches!(
            check_recovery_canonicality(&l1, &fx.params, &w).await,
            Err(RecoveryError::Unavailable(_))
        ));
    }

    #[tokio::test]
    async fn recovery_public_header_reader_matches_engine_and_checks_own_l1() {
        let (fx, l1, _, w) = fixture(2, 6, 2);
        let fetched = authenticate_recovery_with_headers(&l1, &fx.params, 2, |height| {
            let result = if height == 6 {
                Ok(Some(w.el_header.clone()))
            } else if height == 5 {
                Ok(Some(w.parent_headers[0].clone()))
            } else {
                Err(RecoveryError::Unavailable("missing header".into()))
            };
            async move { result }
        })
        .await
        .unwrap();
        assert_eq!(fetched, w);
        let error = authenticate_recovery_with_headers(&l1, &fx.params, 2, |_| async {
            Err(RecoveryError::Unavailable("missing EL state".into()))
        })
        .await
        .unwrap_err();
        assert!(matches!(error, RecoveryError::Unavailable(_)));
        l1.set_finalized(99);
        assert!(
            authenticate_recovery_with_headers(&l1, &fx.params, 2, |_| async {
                Ok(Some(w.el_header.clone()))
            })
            .await
            .is_err()
        );
    }

    #[tokio::test]
    async fn recovery_recheck_preserves_fixed_origin_and_rejects_supersession() {
        let (fx, l1, _, w) = fixture(2, 6, 2);
        check_recovery_canonicality(&l1, &fx.params, &w).await.unwrap();
        // Missing mapping is not a legitimate origin at zero.
        assert!(authenticate_recovery(&l1, &fx.engine(), &fx.params, 3).await.is_err());
        let mut storage = fx.inbox_with(18);
        storage.recovery_generation = 3;
        fx.advance_l1(&l1, 120, &storage, &fx.registry);
        assert!(matches!(
            check_recovery_canonicality(&l1, &fx.params, &w).await,
            Err(RecoveryError::Superseded { requested: 2, current: 3 })
        ));
    }
    /// Rebuilds real proofs after changing storage, so semantic checks cannot hide behind MPT
    /// failure.
    fn changed_state(
        fx: &crate::test_utils::Fixture,
        w: &RecoveryWitness,
        changes: &[(B256, U256)],
    ) -> crate::test_utils::TestState {
        use crate::test_utils::{TestState, filler_accounts, registry_account};
        let mut words: Vec<_> =
            w.finalized_inbox.storage.iter().map(|p| (p.slot, p.value)).collect();
        words.extend_from_slice(changes);
        let mut accounts = filler_accounts();
        accounts.push((fx.params.inbox, 1, U256::ZERO, B256::repeat_byte(1), words));
        accounts.push(registry_account(fx.params.registry, &fx.registry));
        TestState::new(accounts)
    }

    #[test]
    fn recovery_refuses_unsupported_rules_at_r_without_invalidating_fixed_origin() {
        use crate::test_utils::edit_l1_header;
        let (fx, _, _, mut w) = fixture(1, 0, 1);
        let state = changed_state(&fx, &w, &[(inbox::slot(293), U256::from(1) << 48)]);
        w.recovery_header =
            edit_l1_header(&w.recovery_header, |h| h.state_root = state.state_root());
        w.recovery_inbox = state.witness(fx.params.inbox, &inbox::recovery_slots(1, 0));
        assert!(matches!(
            verify_recovery_witness(&w, &fx.params),
            Err(RecoveryError::Unavailable(message)) if message.contains("ruleset 1")
        ));
    }

    #[test]
    fn later_rules_schedule_writes_preserve_the_fixed_recovery_origin() {
        use crate::test_utils::edit_l1_header;
        let (fx, _, _, mut w) = fixture(1, 0, 1);
        let original = verify_recovery_witness(&w, &fx.params).unwrap();
        let state = changed_state(&fx, &w, &[(inbox::slot(293), U256::from(1) << 48)]);
        w.finalized_header =
            edit_l1_header(&w.finalized_header, |h| h.state_root = state.state_root());
        w.finalized_inbox = state.witness(fx.params.inbox, &inbox::recovery_slots(1, 0));
        assert_eq!(verify_recovery_witness(&w, &fx.params).unwrap(), original);
    }

    #[test]
    fn recovery_rejects_proven_missing_origins_and_reserved_packed_widths() {
        use crate::test_utils::edit_l1_header;
        let (fx, _, _, w) = fixture(1, 0, 1);
        let origins = inbox::origin_slots(1);
        let cases = vec![
            origins.into_iter().map(|slot| (slot, U256::ZERO)).collect::<Vec<_>>(),
            vec![(origins[0], U256::from(1) << 48)],
            vec![(origins[1], U256::from(1) << 48)],
            vec![(origins[2], U256::from(1) << 48)],
            vec![(inbox::landing_record_slots(0)[0], U256::from(1) << 144)],
            vec![(inbox::landing_record_slots(0)[1], U256::ZERO)],
        ];
        for changes in cases {
            let state = changed_state(&fx, &w, &changes);
            let mut bad = w.clone();
            bad.finalized_header =
                edit_l1_header(&w.finalized_header, |h| h.state_root = state.state_root());
            bad.finalized_inbox = state.witness(fx.params.inbox, &inbox::recovery_slots(1, 0));
            assert!(matches!(
                verify_recovery_witness(&bad, &fx.params),
                Err(RecoveryError::Invalid(_))
            ));
        }
    }

    /// Replaces the state of both of `w`'s observations, R and the finalized one, with
    /// `state`, proving the recovery slots again.
    fn observe_both(
        fx: &crate::test_utils::Fixture,
        w: &mut RecoveryWitness,
        state: &crate::test_utils::TestState,
    ) {
        use crate::test_utils::edit_l1_header;
        let slots = inbox::recovery_slots(w.generation, w.el_header.number);
        for (header, proof) in [
            (&mut w.recovery_header, &mut w.recovery_inbox),
            (&mut w.finalized_header, &mut w.finalized_inbox),
        ] {
            *header = edit_l1_header(header, |h| h.state_root = state.state_root());
            *proof = state.witness(fx.params.inbox, &slots);
        }
    }

    /// The origin record's fourth word is the `fallbackKeysHash` whose list signs c + 1 and
    /// c + 2. It is read from the same proof as the rest of the record, at R and at the
    /// finalized observation alike, so the two must agree; a zero word is a missing record, as
    /// `recover` writes the hash of a list of at least one key.
    #[test]
    fn origin_word_4_is_read_from_the_same_proof_and_must_be_nonzero() {
        use crate::test_utils::edit_l1_header;
        let (fx, _, _, w) = fixture(1, 6, 1);
        let word = inbox::origin_slots(1)[3];
        let proven = w.recovery_inbox.storage.iter().find(|p| p.slot == word).unwrap().value;
        let origin = verify_recovery_witness(&w, &fx.params).unwrap();
        assert_eq!(origin.fallback_keys_hash, B256::from(proven));
        assert_ne!(origin.fallback_keys_hash, B256::ZERO);

        let other = changed_state(&fx, &w, &[(word, U256::from(7))]);
        let mut bad = w.clone();
        bad.finalized_header =
            edit_l1_header(&w.finalized_header, |h| h.state_root = other.state_root());
        bad.finalized_inbox = other.witness(fx.params.inbox, &inbox::recovery_slots(1, 6));
        assert!(matches!(
            verify_recovery_witness(&bad, &fx.params),
            Err(RecoveryError::Invalid(message)) if message.contains("does not bind")
        ));

        let mut bad = w.clone();
        observe_both(&fx, &mut bad, &changed_state(&fx, &w, &[(word, U256::ZERO)]));
        assert!(matches!(
            verify_recovery_witness(&bad, &fx.params),
            Err(RecoveryError::Invalid(message)) if message.contains("missing or inconsistent")
        ));
    }

    /// `setFallbackKeys` and `setMinTotalStake` replace slots 278 and 279 at any time, so they
    /// are not deployment facts: a recovery whose observations show other words there than the
    /// proof at `L1_0` still verifies, its origin keeps the hash the origin record holds, and
    /// R's anchor reports the words R holds.
    #[test]
    fn fallback_keys_and_min_total_stake_changed_after_initialization_keep_the_recovery() {
        let (fx, _, _, mut w) = fixture(1, 6, 1);
        let original = verify_recovery_witness(&w, &fx.params).unwrap();
        let replaced = B256::repeat_byte(0x78);
        let state = changed_state(
            &fx,
            &w,
            &[
                (inbox::slot(inbox::FALLBACK_KEYS_HASH), replaced.into()),
                (inbox::slot(inbox::MIN_TOTAL_STAKE), U256::MAX),
            ],
        );
        observe_both(&fx, &mut w, &state);
        assert_eq!(verify_recovery_witness(&w, &fx.params).unwrap(), original);
        let anchor = recovery_anchor(&w, &fx.params).unwrap();
        assert_eq!(anchor.inbox.fallback_keys_hash, replaced);
        assert_eq!(anchor.inbox.min_total_stake, U256::MAX);
    }

    #[test]
    fn recovery_rejects_wrong_slot_sets_and_round_trips_versioned_evidence() {
        use alloy_rlp::Decodable;
        let (fx, _, _, w) = fixture(1, 6, 1);
        let bytes = alloy_rlp::encode(&w);
        let decoded = RecoveryWitness::decode(&mut bytes.as_slice()).unwrap();
        assert_eq!(decoded, w);
        let origin = verify_recovery_witness(&decoded, &fx.params).unwrap();
        let encoded = serde_json::to_vec(&origin).unwrap();
        assert_eq!(serde_json::from_slice::<RecoveryOrigin>(&encoded).unwrap(), origin);
        let mut missing = w.clone();
        missing.finalized_inbox.storage.pop();
        assert!(verify_recovery_witness(&missing, &fx.params).is_err());
        let mut swapped = w;
        swapped.recovery_inbox.storage.swap(0, 1);
        assert!(verify_recovery_witness(&swapped, &fx.params).is_err());
    }

    #[tokio::test]
    async fn recovery_current_checkpoint_advance_keeps_c_and_original_cursor() {
        let (fx, l1, _, w) = fixture(1, 6, 1);
        let state = changed_state(
            &fx,
            &w,
            &[
                (inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(18)),
                (inbox::slot(inbox::LAST_CHECKPOINT_HASH), B256::repeat_byte(0x18).into()),
                (
                    inbox::slot(inbox::FORCED_INCLUSION_HEAD_TAIL),
                    U256::from(9) | (U256::from(10) << 48),
                ),
            ],
        );
        l1.insert_block(l1_header(120, crate::test_utils::Fixture::l1_timestamp(120)), state);
        l1.set_finalized(120);
        check_recovery_canonicality(&l1, &fx.params, &w).await.unwrap();
        let origin = verify_recovery_witness(&w, &fx.params).unwrap();
        assert_eq!((origin.height, origin.forced_cursor), (6, 3));
    }

    #[tokio::test]
    async fn recovery_distinguishes_unavailable_inputs_from_contradictory_evidence() {
        let (fx, l1, engine, w) = fixture(1, 6, 1);
        engine.state().chain.remove(&5);
        assert!(matches!(
            authenticate_recovery(&l1, &engine, &fx.params, 1).await,
            Err(RecoveryError::Unavailable(_))
        ));
        l1.state().headers.insert(100, RawL1Header::from(&l1_header(100, 123)));
        assert!(matches!(
            check_recovery_canonicality(&l1, &fx.params, &w).await,
            Err(RecoveryError::Invalid(_))
        ));
        l1.state().fail = Some(crate::L1Error::Rpc("unavailable".into()));
        assert!(matches!(
            check_recovery_canonicality(&l1, &fx.params, &w).await,
            Err(RecoveryError::Unavailable(_))
        ));
    }

    /// RECOV-8.1-7/8.1-8: an own EL that holds another block at c (vector 7.l) or none (7.i)
    /// has not yet taken the settled block there. That is missing data, not a contradiction of
    /// the authenticated landing; a witness whose header at c does not hash to it stays invalid.
    #[tokio::test]
    async fn recovery_fetch_reports_another_or_no_block_at_c_as_not_held() {
        let (fx, l1, engine, w) = fixture(1, 6, 1);
        let settled = w.el_header.hash_slow();
        let own =
            alloy_consensus::Header { timestamp: w.el_header.timestamp + 1, ..w.el_header.clone() };
        for held in [Some(own.clone()), None] {
            match held {
                Some(header) => engine.state().chain.insert(6, header),
                None => engine.state().chain.remove(&6),
            };
            assert!(matches!(
                authenticate_recovery(&l1, &engine, &fx.params, 1).await,
                Err(RecoveryError::OriginNotHeld { height: 6, el_hash }) if el_hash == settled
            ));
        }
        let mut forged = w;
        forged.el_header = own;
        assert!(matches!(
            verify_recovery_witness(&forged, &fx.params),
            Err(RecoveryError::Invalid(_))
        ));
    }

    #[tokio::test]
    async fn recovery_accepts_init_and_recovery_in_same_l1_block_without_relaxing_fresh_genesis() {
        use crate::test_utils::{Fixture, edit_l1_header};
        let (fx, l1, engine, mut w) = fixture(1, 0, 1);
        let origins = inbox::origin_slots(1);
        let state = changed_state(
            &fx,
            &w,
            &[(origins[1], U256::from(64)), (origins[2], U256::from(Fixture::l1_timestamp(64)))],
        );
        w.genesis.l1_header =
            l1.insert_block(l1_header(64, Fixture::l1_timestamp(64)), state.clone());
        w.genesis.inbox = state.witness(fx.params.inbox, &inbox::genesis_slots());
        let registry_slots: Vec<_> =
            w.genesis.committee.registry.storage.iter().map(|p| p.slot).collect();
        w.genesis.committee.registry = state.witness(fx.params.registry, &registry_slots);
        w.recovery_header = w.genesis.l1_header.clone();
        w.recovery_inbox = state.witness(fx.params.inbox, &inbox::recovery_slots(1, 0));
        w.finalized_header =
            edit_l1_header(&w.finalized_header, |h| h.state_root = state.state_root());
        l1.insert_header(w.finalized_header.clone());
        l1.state().states.insert(110, state.clone());
        w.finalized_inbox = state.witness(fx.params.inbox, &inbox::recovery_slots(1, 0));
        let origin = verify_recovery_witness(&w, &fx.params).unwrap();
        assert_eq!((origin.height, origin.l1_number), (0, 64));
        assert!(matches!(
            crate::genesis::verify_context(&w.genesis.l1_header, &w.genesis.inbox, &fx.params),
            Err(crate::GenesisError::UnsupportedRecovery(_))
        ));
        let fetched = authenticate_recovery(&l1, &engine, &fx.params, 1).await.unwrap();
        assert_eq!(verify_recovery_witness(&fetched, &fx.params).unwrap(), origin);
        let doc = build_recovery_genesis(&l1, &engine, &fx.params, 1).await.unwrap();
        let request = crate::test_utils::init_chain_request(&doc);
        let dir = tempfile::tempdir().unwrap();
        let mut app = crate::App::new(
            l1,
            engine,
            fx.params,
            crate::Store::new(dir.path().into()),
            crate::AppOptions::default(),
        )
        .unwrap();
        app.handle(crate::wire::Request::InitChain(request)).await.unwrap();
        assert_eq!(app.state().unwrap().origin_height(), 0);
        assert_eq!(app.state().unwrap().anchor.number, 64);
        assert_eq!(app.state().unwrap().generation, 1);
    }

    #[tokio::test]
    async fn recovery_fetch_reports_supersession_before_unavailable_genesis_history() {
        let (fx, l1, engine, _) = fixture(2, 6, 2);
        l1.state().states.remove(&64);
        assert!(matches!(
            authenticate_recovery(&l1, &engine, &fx.params, 1).await,
            Err(RecoveryError::Superseded { requested: 1, current: 2 })
        ));
        assert!(engine.calls().is_empty());
    }

    #[test]
    fn recovery_at_zero_requires_original_genesis_hash_not_just_state_root() {
        use crate::test_utils::edit_l1_header;
        let (fx, _, _, mut w) = fixture(1, 0, 1);
        w.el_header.extra_data = alloy_primitives::Bytes::from_static(b"changed genesis");
        let state = changed_state(
            &fx,
            &w,
            &[(inbox::landing_record_slots(0)[1], w.el_header.hash_slow().into())],
        );
        w.finalized_header =
            edit_l1_header(&w.finalized_header, |h| h.state_root = state.state_root());
        w.recovery_header =
            edit_l1_header(&w.recovery_header, |h| h.state_root = state.state_root());
        w.finalized_inbox = state.witness(fx.params.inbox, &inbox::recovery_slots(1, 0));
        w.recovery_inbox = w.finalized_inbox.clone();
        assert!(matches!(verify_recovery_witness(&w, &fx.params), Err(RecoveryError::Invalid(_))));
    }

    /// STOR-B-9: the retained record is three words. Recovery proves and reads no word after
    /// them, so a finalized observation that differs from R's only in the word an older
    /// four-word record held still binds the same origin.
    #[test]
    fn recovery_reads_no_word_after_the_three_word_record() {
        use crate::test_utils::edit_l1_header;
        let (fx, _, _, mut w) = fixture(1, 6, 1);
        let original = verify_recovery_witness(&w, &fx.params).unwrap();
        let [first, ..] = inbox::landing_record_slots(6);
        let after = B256::from(U256::from_be_bytes(first.0).wrapping_add(U256::from(3)));
        assert!(!inbox::recovery_slots(1, 6).contains(&after));
        let state = changed_state(&fx, &w, &[(after, U256::from(1))]);
        w.finalized_header =
            edit_l1_header(&w.finalized_header, |h| h.state_root = state.state_root());
        w.finalized_inbox = state.witness(fx.params.inbox, &inbox::recovery_slots(1, 6));
        assert_eq!(verify_recovery_witness(&w, &fx.params).unwrap(), original);
    }

    #[test]
    fn recovery_rejects_changed_retained_landing_parent_or_generation() {
        use crate::test_utils::edit_l1_header;
        for (c, packed) in [
            (24, U256::from(6) | (U256::from(3) << 96)),
            (6, (U256::from(1) << 48) | (U256::from(3) << 96)),
        ] {
            let (fx, _, _, mut w) = fixture(2, c, 2);
            let state = changed_state(&fx, &w, &[(inbox::landing_record_slots(c)[0], packed)]);
            w.finalized_header =
                edit_l1_header(&w.finalized_header, |h| h.state_root = state.state_root());
            w.finalized_inbox = state.witness(fx.params.inbox, &inbox::recovery_slots(2, c));
            assert!(matches!(
                verify_recovery_witness(&w, &fx.params),
                Err(RecoveryError::Invalid(_))
            ));
        }
    }
}
