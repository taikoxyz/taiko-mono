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
pub use genesis::build_recovery_genesis;
pub(crate) use genesis::{RecoveryBootstrap, recovery_bootstrap, recovery_parent};
pub use types::{RecoveryError, RecoveryOrigin, RecoveryWitness};
pub use verify::verify_recovery_witness;

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        l1::{RawL1Header, layout::inbox},
        test_utils::{EngineCall, l1_header, recovery_fixture as fixture},
    };
    use alloy_primitives::{B256, U256};

    #[test]
    fn recovery_witness_binds_fixed_origin_and_r_snapshot() {
        let (fx, _, _, witness) = fixture(1, 6, 1);
        let origin = verify_recovery_witness(&witness, &fx.params).unwrap();
        assert_eq!((origin.generation, origin.height, origin.l1_number), (1, 6, 100));
        assert_eq!(origin.forced_cursor, 3);
        assert_eq!(origin.committee.record.cutoff_l1_block, 100);
        assert_eq!(origin.committee.record.target_epoch, 0);
        assert_eq!(origin.state_root, B256::repeat_byte(0x55));
        assert_eq!(origin.comet_hash, B256::repeat_byte(0xcc));
    }

    #[test]
    fn recovery_rejects_each_tampered_proven_origin_or_landing_word() {
        let (fx, _, _, w) = fixture(1, 6, 1);
        for slot in inbox::origin_slots(1).into_iter().chain(inbox::landing_slots(6)) {
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
    fn recovery_rejects_headers_committee_config_and_domain_tampering() {
        let (fx, _, _, w) = fixture(1, 6, 1);
        let mut variants = vec![w.clone(); 8];
        variants[0].recovery_header = RawL1Header::from(&l1_header(100, 1));
        variants[1].committee.registry.storage_root = B256::ZERO;
        variants[2].committee.record.target_epoch = 1;
        variants[3].el_header.state_root = B256::ZERO;
        variants[4].parent_headers[0].timestamp += 1;
        variants[5].version = 2;
        variants[6].generation = 0;
        variants[7].parent_headers.clear();
        for bad in variants {
            assert!(verify_recovery_witness(&bad, &fx.params).is_err());
        }
        let mut params = fx.params.clone();
        params.l2_chain_id += 1;
        assert!(matches!(
            verify_recovery_witness(&w, &params),
            Err(RecoveryError::ConfigMismatch { .. })
        ));
        params = fx.params.clone();
        params.registry = alloy_primitives::Address::ZERO;
        assert!(verify_recovery_witness(&w, &params).is_err());
    }

    #[test]
    fn recovery_accepts_zero_and_repeated_generation_with_older_landing() {
        for (generation, c) in [(1, 0), (2, 6), (2, 24)] {
            let (fx, _, _, w) = fixture(generation, c, generation);
            let origin = verify_recovery_witness(&w, &fx.params).unwrap();
            assert_eq!(origin.height, c);
            assert_eq!(origin.committee.record.target_epoch, c / 20);
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

    #[tokio::test]
    async fn recovery_public_header_reader_matches_engine_and_checks_own_l1() {
        let (fx, l1, _, w) = fixture(2, 6, 2);
        let fetched = authenticate_recovery_with_headers(&l1, &fx.params, 2, |height| {
            let result = if height == 6 {
                Ok(w.el_header.clone())
            } else if height == 5 {
                Ok(w.parent_headers[0].clone())
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
                Ok(w.el_header.clone())
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
    fn recovery_rejects_proven_missing_origins_and_reserved_packed_widths() {
        use crate::test_utils::edit_l1_header;
        let (fx, _, _, w) = fixture(1, 0, 1);
        let origins = inbox::origin_slots(1);
        let cases = vec![
            origins.into_iter().map(|slot| (slot, U256::ZERO)).collect::<Vec<_>>(),
            vec![(origins[0], U256::from(1) << 48)],
            vec![(origins[1], U256::from(1) << 48)],
            vec![(origins[2], U256::from(1) << 48)],
            vec![(inbox::landing_slots(0)[0], U256::from(1) << 144)],
            vec![(inbox::landing_slots(0)[1], U256::ZERO)],
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
        engine.state().chain.remove(&6);
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
        w.committee.record.cutoff_l1_block = 64;
        w.committee.registry = state.witness(fx.params.registry, &registry_slots);
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
        let mut request = fx.request.clone();
        request.chain_id = doc.chain_id;
        request.time = doc.genesis_time.parse().unwrap();
        request.app_state_bytes = serde_json::to_vec(&doc.app_state).unwrap().into();
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

    #[test]
    fn recovery_initial_committee_applies_exclusions_at_end_of_r() {
        use crate::{
            committee::{Snapshot, derive},
            test_utils::{committee_witness, edit_l1_header},
        };
        let (mut fx, _, _, mut w) = fixture(1, 6, 1);
        let mut entries = fx.registry.checkpoints[0].1.clone();
        entries[0].exit_effective_l1 = 100;
        fx.registry.checkpoints.push((100, entries.clone()));
        let state = changed_state(&fx, &w, &[]);
        w.recovery_header =
            edit_l1_header(&w.recovery_header, |h| h.state_root = state.state_root());
        w.finalized_header =
            edit_l1_header(&w.finalized_header, |h| h.state_root = state.state_root());
        w.recovery_inbox = state.witness(fx.params.inbox, &inbox::recovery_slots(1, 6));
        w.finalized_inbox = w.recovery_inbox.clone();
        let (record, _) =
            derive(&Snapshot { checkpoint_index: 1, l1_block: 100, entries }, 100, 0, &fx.params)
                .unwrap();
        w.committee = committee_witness(&state, fx.params.registry, &fx.registry, 1, record);
        let origin = verify_recovery_witness(&w, &fx.params).unwrap();
        assert_eq!(origin.committee.members.len(), 1);
        assert_eq!(origin.committee.record.checkpoint_index, 1);
        assert_eq!(origin.committee.record.cutoff_l1_block, 100);
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
        let state =
            changed_state(&fx, &w, &[(inbox::landing_slots(0)[1], w.el_header.hash_slow().into())]);
        w.finalized_header =
            edit_l1_header(&w.finalized_header, |h| h.state_root = state.state_root());
        w.recovery_header =
            edit_l1_header(&w.recovery_header, |h| h.state_root = state.state_root());
        w.finalized_inbox = state.witness(fx.params.inbox, &inbox::recovery_slots(1, 0));
        w.recovery_inbox = w.finalized_inbox.clone();
        let slots: Vec<_> = w.committee.registry.storage.iter().map(|p| p.slot).collect();
        w.committee.registry = state.witness(fx.params.registry, &slots);
        assert!(matches!(verify_recovery_witness(&w, &fx.params), Err(RecoveryError::Invalid(_))));
    }
    #[test]
    fn recovery_rejects_changed_retained_landing_parent_or_generation() {
        use crate::test_utils::edit_l1_header;
        for (c, packed) in [
            (24, U256::from(6) | (U256::from(3) << 96)),
            (6, (U256::from(1) << 48) | (U256::from(3) << 96)),
        ] {
            let (fx, _, _, mut w) = fixture(2, c, 2);
            let state = changed_state(&fx, &w, &[(inbox::landing_slots(c)[0], packed)]);
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
