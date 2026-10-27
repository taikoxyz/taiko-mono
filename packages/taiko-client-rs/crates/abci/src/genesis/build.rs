//! The `abci-genesis` builder: reads the Ethereum-final genesis record and the `e_0` committee
//! from the node's own L1, checks them as `InitChain` will, and assembles the CometBFT genesis
//! document.

use super::{GenesisDoc, GenesisError, GenesisWitness, verify_committee, verify_context};
use crate::{
    config::ChainParams,
    l1::{
        L1Source, build_committee_witness_at_cutoff, header_at,
        layout::{inbox, word_u8, word_u48},
    },
    rules::chain_id_for,
    schedule::Schedule,
};

/// Builds the CometBFT genesis of the initialized Etna chain from the node's own L1.
///
/// In order: reads, unproven, the Inbox's `migrationState` and genesis word at the L1
/// `finalized` block and requires `ETNA_ACTIVE` ([`GenesisError::NotActive`]); requires the
/// initialization block `L1_0` to be final with the chain's extra depth
/// ([`GenesisError::InitializationNotFinal`]); takes the canonical header of `L1_0` and the Inbox
/// proofs of `genesis_slots()` there, and verifies them as `InitChain` will (the record must
/// name the same `L1_0`, `genesisCutoff` must lie before it, the schedule must be valid); builds
/// the `e_0` committee witness with the explicit snapshot at `genesisCutoff` and its proofs
/// at `L1_0`, and requires the committee it proves to hash to
/// `genesisCommitteeRecordHash` ([`GenesisError::CommitteeRecordMismatch`]).
///
/// The registry entries of that snapshot are read at the newest block that still holds it, which
/// can be as old as `genesisCutoff`: the L1 node must serve that state (an archive node once it
/// leaves the node's state window).
///
/// The document uses the 48-byte deployment-domain chain ID,
/// `initial_height = 1`, `genesis_time` = the `L1_0` timestamp, the `e_0` members as
/// validators and the genesis witness as `app_state`. Nothing in it is trusted: `InitChain`
/// re-verifies all of it against each node's own L1.
pub async fn build_genesis<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
) -> Result<GenesisDoc, GenesisError> {
    let finalized = l1.finalized_number().await?;
    let inbox_word = |n: u64| l1.storage_at(params.inbox, inbox::slot(n), finalized);
    let status = word_u8(inbox_word(inbox::STATUS).await?, 0);
    if status != inbox::ETNA_ACTIVE {
        return Err(GenesisError::NotActive(status));
    }
    let l1_0 = word_u48(inbox_word(inbox::GENESIS_PACKED).await?, 48);
    let extra_depth = params.l1_finality_extra_depth;
    if l1_0.checked_add(extra_depth).is_none_or(|bound| bound > finalized) {
        return Err(GenesisError::InitializationNotFinal { l1_0, extra_depth, finalized });
    }

    let l1_header = header_at(l1, l1_0).await?;
    let inbox_witness = l1.account_witness(params.inbox, &inbox::genesis_slots(), l1_0).await?;
    let context = verify_context(&l1_header, &inbox_witness, params)?;
    let genesis_cutoff = context.genesis.genesis_cutoff;
    let committee =
        build_committee_witness_at_cutoff(l1, params, l1_0, genesis_cutoff, Schedule::E0).await?;
    let verified = verify_committee(&context, &committee, params)?;
    let chain_id = chain_id_for(params, context.anchor.inbox.recovery_generation)
        .map_err(|e| GenesisError::UnsupportedRecovery(e.to_string()))?;
    GenesisDoc::assemble(
        &GenesisWitness { l1_header, inbox: inbox_witness, committee },
        chain_id,
        &verified.members,
    )
}

#[cfg(test)]
mod tests {
    use crate::wire::{Request, Response, request::InitChain};
    use alloy_primitives::B256;
    use tendermint::block::Height;

    use super::*;
    use crate::{
        committee::{CommitteeError, record_hash},
        genesis::decode_app_state,
        l1::{FetchError, L1Error, WitnessError, layout::inbox},
        test_utils::{Fixture, GenesisSpec, L1Call},
    };

    /// The `InitChain` request CometBFT sends for `doc`: the document is parsed as a CometBFT
    /// genesis file (with tendermint-rs's own parser), the validators carry their Ed25519 keys
    /// and powers, and `app_state` is passed on as its raw JSON bytes. The request passes through
    /// the ABCI protobuf conversion, as the server's wire decoder does: JSON's explicit vote
    /// extension height zero becomes the typed request's disabled `None` value.
    fn init_chain_from(doc: &GenesisDoc) -> InitChain {
        let genesis: GenesisDoc = serde_json::from_str(&doc.to_json_pretty()).unwrap();
        InitChain {
            time: genesis.genesis_time.parse().unwrap(),
            chain_id: genesis.chain_id,
            consensus_params: crate::genesis::GenesisConsensusParams::abci(),
            validators: genesis
                .validators
                .iter()
                .map(|v| crate::wire::ValidatorUpdate {
                    pub_key: v.pub_key.0,
                    power: v.power.parse::<u64>().unwrap().try_into().unwrap(),
                })
                .collect(),
            app_state_bytes: serde_json::to_vec(&genesis.app_state).unwrap().into(),
            initial_height: Height::try_from(genesis.initial_height.parse::<u64>().unwrap())
                .unwrap(),
        }
    }

    /// The built genesis is the fixture's: same witness, validators, chain id and heights, and
    /// `InitChain` accepts it.
    #[tokio::test]
    async fn built_genesis_initializes_the_chain() {
        let fx = Fixture::genesis(3);
        let doc = build_genesis(&fx.l1(), &fx.params).await.expect("the fixture L1 is initialized");
        let req = init_chain_from(&doc);
        assert_eq!(req, fx.request);
        let params = &req.consensus_params;
        assert_eq!(params.block.as_ref().unwrap().max_bytes, 22_020_096);
        assert_eq!(params.block.as_ref().unwrap().max_gas, -1);
        assert_eq!(params.evidence, fx.request.consensus_params.evidence);
        assert_eq!(params.validator, fx.request.consensus_params.validator);

        let dir = tempfile::tempdir().unwrap();
        let mut app = fx.app(dir.path());
        let Response::InitChain(resp) =
            app.handle(Request::InitChain(req.clone())).await.expect("InitChain accepts it")
        else {
            panic!("InitChain answers InitChain");
        };
        assert!(resp.validators.is_empty());
        assert_eq!(app.state(), Some(&fx.expected_state()));
    }

    /// The witness is read at `L1_0` while the record is read at the finalized block.
    #[tokio::test]
    async fn reads_the_record_at_finalized_and_the_proofs_at_l1_0() {
        let mut spec = GenesisSpec::new(2);
        spec.params.l1_finality_extra_depth = 2;
        let fx = Fixture::build(spec);
        let l1 = fx.l1();
        let finalized = fx.genesis.l1_0 + 2;
        fx.plant_l1_block(&l1, finalized, &fx.inbox, &fx.registry);

        let doc = build_genesis(&l1, &fx.params).await.expect("final with the extra depth");
        assert_eq!(init_chain_from(&doc).app_state_bytes, fx.request.app_state_bytes);
        let calls = l1.calls();
        assert_eq!(calls[0], L1Call::Finalized);
        assert!(calls[1..3].iter().all(
            |c| matches!(c, L1Call::StorageAt { address, block, .. } if *address == fx.params.inbox && *block == finalized)
        ), "{calls:?}");
        assert_eq!(calls[3], L1Call::Header(fx.genesis.l1_0));
    }

    /// Genesis derives at explicit snapshot 63; an earlier snapshot 59 has no active entries.
    #[tokio::test]
    async fn the_genesis_committee_is_derived_at_the_genesis_cutoff() {
        let fx = Fixture::build(GenesisSpec::eligible_at_explicit_genesis_snapshot(2));
        assert_eq!((fx.genesis.l1_0, fx.genesis.genesis_cutoff), (64, 63));
        // At explicit snapshot 59 no entry is active yet.
        let earlier =
            build_committee_witness_at_cutoff(&fx.l1(), &fx.params, 64, 59, Schedule::E0).await;
        assert_eq!(earlier, Err(FetchError::Committee(CommitteeError::Empty)));

        let l1 = fx.l1();
        let doc = build_genesis(&l1, &fx.params).await.expect("e_0 derives at the genesis cutoff");
        assert_eq!(doc.validators.len(), 2);
        let req = init_chain_from(&doc);
        assert_eq!(req.validators, fx.request.validators);
        assert_eq!(req.app_state_bytes, fx.request.app_state_bytes);
        let witness = decode_app_state(&req.app_state_bytes).expect("decodes");
        assert_eq!(witness.committee.record.cutoff_l1_block, 63);
        let registry_reads: Vec<u64> = l1
            .calls()
            .into_iter()
            .filter_map(|c| match c {
                L1Call::AccountWitness { address, block, .. } |
                L1Call::StorageAt { address, block, .. }
                    if address == fx.params.registry =>
                {
                    Some(block)
                }
                _ => None,
            })
            .collect();
        assert_eq!(registry_reads, [64; 4], "every registry read is at L1_0");
    }

    /// The Inbox's `genesisCutoff` must lie before `L1_0`; nothing of the registry is read.
    #[tokio::test]
    async fn a_genesis_cutoff_not_before_l1_0_is_rejected() {
        for genesis_cutoff in [64, 65] {
            let fx = Fixture::build(GenesisSpec { genesis_cutoff, ..GenesisSpec::new(2) });
            let l1 = fx.l1();
            let err = build_genesis(&l1, &fx.params).await.unwrap_err();
            assert!(
                matches!(&err, GenesisError::Witness(e) if **e
                    == WitnessError::GenesisCutoffNotBeforeInitialization { genesis_cutoff, l1_0: 64 }),
                "{err:?}"
            );
            assert!(
                !l1.calls().iter().any(|c| matches!(
                    c,
                    L1Call::AccountWitness { address, .. } | L1Call::StorageAt { address, .. }
                        if *address == fx.params.registry
                )),
                "{:?}",
                l1.calls()
            );
        }
    }

    #[tokio::test]
    async fn inactive_inbox_is_rejected() {
        let fx = Fixture::genesis(1);
        let l1 = fx.l1();
        let mut inbox = fx.inbox.clone();
        inbox.status = inbox::ETNA_ACTIVE - 1;
        fx.plant_l1_block(&l1, 70, &inbox, &fx.registry);
        l1.set_finalized(70);
        let err = build_genesis(&l1, &fx.params).await.unwrap_err();
        assert!(matches!(err, GenesisError::NotActive(2)), "{err:?}");
    }

    #[tokio::test]
    async fn initialization_not_final_with_the_extra_depth_is_rejected() {
        let mut spec = GenesisSpec::new(1);
        spec.params.l1_finality_extra_depth = 2;
        let fx = Fixture::build(spec);
        let l1 = fx.l1();
        let l1_0 = fx.genesis.l1_0;
        fx.plant_l1_block(&l1, l1_0 + 1, &fx.inbox, &fx.registry);
        l1.set_finalized(l1_0 + 1);
        let err = build_genesis(&l1, &fx.params).await.unwrap_err();
        assert!(
            matches!(err, GenesisError::InitializationNotFinal { l1_0: n, extra_depth: 2, finalized }
                if n == l1_0 && finalized == l1_0 + 1),
            "{err:?}"
        );
        assert!(!l1.calls().iter().any(|c| matches!(c, L1Call::Header(_))), "no proof read");
    }

    #[tokio::test]
    async fn committee_record_hash_mismatch_is_rejected() {
        let mut spec = GenesisSpec::new(2);
        spec.committee_e0 = Some(B256::repeat_byte(0xbd));
        let fx = Fixture::build(spec);
        let err = build_genesis(&fx.l1(), &fx.params).await.unwrap_err();
        let expected = record_hash(fx.params.l2_chain_id, &fx.record);
        assert!(
            matches!(err, GenesisError::CommitteeRecordMismatch { derived, recorded }
                if derived == expected && recorded == B256::repeat_byte(0xbd)),
            "{err:?}"
        );
    }

    /// Eleven-word openings under the older domains, with a heartbeat lookahead word of 2, do not
    /// open the current ten-word configuration.
    #[tokio::test]
    async fn legacy_committee_config_domains_are_rejected_at_genesis() {
        use alloy_primitives::U256;
        for (domain, encoding_version) in [
            (b"ETNA_PARENT_ANCHOR_V2", 1u64),
            (b"ETNA_PARENT_ANCHOR_V3", 2u64),
            (b"ETNA_PARENT_ANCHOR_V4", 2u64),
        ] {
            let fx = Fixture::genesis(1);
            let l1 = fx.l1();
            let p = &fx.params;
            let word = |value: U256| alloy_primitives::B256::from(value);
            let mut tag = [0u8; 32];
            tag[..domain.len()].copy_from_slice(domain);
            let legacy = alloy_primitives::keccak256(
                [
                    alloy_primitives::B256::from(tag),
                    word(U256::from(p.l2_chain_id)),
                    word(U256::from_be_slice(p.registry.as_slice())),
                    word(p.vp_unit),
                    word(p.s_min),
                    word(U256::from(p.n_max)),
                    word(U256::from(123u64)),
                    word(U256::from(2u64)),
                    word(U256::from(encoding_version)),
                    word(U256::from(12u64)),
                    word(U256::from(2u64)),
                ]
                .concat(),
            );
            let mut inbox = fx.inbox.clone();
            inbox.genesis.as_mut().unwrap().committee_config_hash = legacy;
            fx.plant_l1_block(&l1, fx.genesis.l1_0, &inbox, &fx.registry);
            let result = build_genesis(&l1, p).await;
            assert!(
                matches!(result, Err(GenesisError::ConfigMismatch { proven, .. }) if proven == legacy)
            );
        }
    }

    /// The finalized record names L1 block 66, but the record proven there names 64.
    #[tokio::test]
    async fn genesis_record_moved_since_l1_0_is_rejected() {
        let fx = Fixture::genesis(1);
        let l1 = fx.l1();
        fx.plant_l1_block(&l1, 66, &fx.inbox, &fx.registry);
        let mut moved = fx.inbox.clone();
        moved.genesis.as_mut().expect("initialized").l1_0 = 66;
        fx.plant_l1_block(&l1, 70, &moved, &fx.registry);
        l1.set_finalized(70);
        let err = build_genesis(&l1, &fx.params).await.unwrap_err();
        assert!(
            matches!(err, GenesisError::InitializationMismatch { l1_0: 66, proven: 64 }),
            "{err:?}"
        );
    }

    /// An own L1 node answering the header request for `L1_0` with another block's header.
    #[tokio::test]
    async fn a_header_of_another_l1_block_is_rejected() {
        let fx = Fixture::genesis(1);
        let l1 = fx.l1();
        let l1_0 = fx.genesis.l1_0;
        let other = crate::test_utils::edit_l1_header(&fx.witness.l1_header, |h| h.number += 1);
        l1.state().headers.insert(l1_0, other);
        let err = build_genesis(&l1, &fx.params).await.unwrap_err();
        assert!(
            matches!(err, GenesisError::L1(L1Error::HeaderNumberMismatch { requested, got })
                if requested == l1_0 && got == l1_0 + 1),
            "{err:?}"
        );
    }

    #[tokio::test]
    async fn l1_failures_are_errors() {
        let fx = Fixture::genesis(1);
        let l1 = fx.l1();
        l1.state().fail = Some(L1Error::Rpc("down".into()));
        let err = build_genesis(&l1, &fx.params).await.unwrap_err();
        assert!(matches!(err, GenesisError::L1(L1Error::Rpc(_))), "{err:?}");
    }

    /// A generation-1 Inbox yields a `-g1` chain id, which `InitChain` accepts.
    #[tokio::test]
    async fn recovery_generation_cannot_build_fresh_genesis() {
        let fx = Fixture::build(GenesisSpec { recovery_generation: 1, ..GenesisSpec::new(1) });
        assert!(matches!(
            build_genesis(&fx.l1(), &fx.params).await,
            Err(GenesisError::UnsupportedRecovery(_))
        ));
    }
}
