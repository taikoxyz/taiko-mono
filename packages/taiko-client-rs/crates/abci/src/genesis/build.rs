//! The `abci-genesis` builder: reads the Ethereum-final activation record and
//! the `e_0` committee from the node's own L1, checks them as `InitChain` will, and assembles the
//! CometBFT genesis document.

use super::{GenesisDoc, GenesisError, GenesisWitness};
use crate::{
    committee::{record_hash, verify_committee_witness},
    config::ChainParams,
    l1::{
        L1Source, build_committee_witness, header_at,
        layout::{inbox, word_u8, word_u64},
        verify_genesis_inbox,
    },
    rules::chain_id_for,
    schedule::Schedule,
    types::AnchorState,
};

/// Builds the CometBFT genesis of the activated Etna chain from the node's own L1.
///
/// In order: reads, unproven, the Inbox's `migrationState` and activation word at the L1
/// `finalized` block and requires `ETNA_ACTIVE` ([`GenesisError::NotActive`]); requires the
/// activation block `L1_0` to be final with the chain's extra depth
/// ([`GenesisError::ActivationNotFinal`]); takes the canonical header of `L1_0` and the Inbox
/// proofs of `genesis_slots(e_0)` there, and verifies them as `InitChain` will (the record must
/// name the same `L1_0`, the schedule must be valid); builds the `e_0` committee witness against
/// `L1_0` and requires the committee it proves to hash to `committee[e_0]`
/// ([`GenesisError::CommitteeRecordMismatch`]).
///
/// The document has `chain_id = taiko-etna-<l2ChainId>-g<recoveryGeneration>`,
/// `initial_height = B* + 1`, `genesis_time` = the `L1_0` timestamp, the `e_0` members as
/// validators and the genesis witness as `app_state`. Nothing in it is trusted: `InitChain`
/// re-verifies all of it against each node's own L1.
pub async fn build_genesis<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
) -> Result<GenesisDoc, GenesisError> {
    let finalized = l1.finalized_number().await?;
    let inbox_word = |n: u64| l1.storage_at(params.inbox, inbox::slot(n), finalized);
    let migration_state = word_u8(inbox_word(inbox::MIGRATION_STATE).await?, 0);
    if migration_state != inbox::ETNA_ACTIVE {
        return Err(GenesisError::NotActive(migration_state));
    }
    let l1_0 = word_u64(inbox_word(inbox::ACTIVATION_PACKED).await?, 64);
    let extra_depth = params.l1_finality_extra_depth;
    if l1_0.checked_add(extra_depth).is_none_or(|bound| bound > finalized) {
        return Err(GenesisError::ActivationNotFinal { l1_0, extra_depth, finalized });
    }

    let l1_header = header_at(l1, l1_0).await?;
    let inbox = l1.account_witness(params.inbox, &inbox::genesis_slots(Schedule::E0), l1_0).await?;
    let (activation, facts, committee_e0) =
        verify_genesis_inbox(l1_header.state_root(), &inbox, params.inbox)?;
    if activation.l1_0 != l1_0 {
        return Err(GenesisError::ActivationMismatch { l1_0, proven: activation.l1_0 });
    }
    Schedule::from_activation(&activation).validate(params.unsettled_cap())?;

    let anchor = AnchorState {
        number: l1_0,
        hash: l1_header.hash(),
        state_root: l1_header.state_root(),
        timestamp: l1_header.timestamp(),
        inbox: facts,
    };
    let committee = build_committee_witness(l1, params, l1_0, Schedule::E0).await?;
    let (record, members) = verify_committee_witness(&anchor, params, &committee, Schedule::E0)?;
    let derived = record_hash(params.l2_chain_id, &record);
    if derived != committee_e0 {
        return Err(GenesisError::CommitteeRecordMismatch { derived, recorded: committee_e0 });
    }

    let initial_height = activation
        .genesis_height
        .checked_add(1)
        .filter(|h| i64::try_from(*h).is_ok())
        .ok_or(GenesisError::InitialHeight(activation.genesis_height))?;
    let chain_id = chain_id_for(params.l2_chain_id, anchor.inbox.recovery_generation);
    GenesisDoc::assemble(
        &GenesisWitness { l1_header, inbox, committee },
        chain_id,
        initial_height,
        &members,
    )
}

#[cfg(test)]
mod tests {
    use alloy_primitives::B256;
    use tendermint::{
        Genesis,
        abci::request::InitChain,
        block::Height,
        v0_38::abci::{Request, Response},
        validator,
    };

    use super::*;
    use crate::{
        committee::record_hash,
        l1::{L1Error, layout::inbox},
        test_utils::{Fixture, GenesisSpec, L1Call},
    };

    /// The `InitChain` request CometBFT sends for `doc`: the document is parsed as a CometBFT
    /// genesis file (with tendermint-rs's own parser), the validators carry their Ed25519 keys
    /// and powers, and `app_state` is passed on as its raw JSON bytes.
    fn init_chain_from(doc: &GenesisDoc) -> InitChain {
        let genesis: Genesis<serde_json::Value> =
            serde_json::from_str(&doc.to_json_pretty()).expect("a CometBFT genesis file");
        InitChain {
            time: genesis.genesis_time,
            chain_id: genesis.chain_id.to_string(),
            consensus_params: genesis.consensus_params,
            validators: genesis
                .validators
                .iter()
                .map(|v| validator::Update { pub_key: v.pub_key, power: v.power })
                .collect(),
            app_state_bytes: serde_json::to_vec(&genesis.app_state).expect("JSON").into(),
            initial_height: Height::try_from(genesis.initial_height).expect("a CometBFT height"),
        }
    }

    /// The built genesis is the fixture's: same witness, validators, chain id and heights, and
    /// `InitChain` accepts it.
    #[tokio::test]
    async fn built_genesis_initializes_the_chain() {
        let fx = Fixture::genesis(3);
        let doc = build_genesis(&fx.l1(), &fx.params).await.expect("the fixture L1 is activated");
        let req = init_chain_from(&doc);
        assert_eq!(
            InitChain { consensus_params: fx.request.consensus_params.clone(), ..req.clone() },
            fx.request
        );
        let params = &req.consensus_params;
        assert_eq!(params.block.max_bytes, 22_020_096);
        assert_eq!(params.block.max_gas, -1);
        assert_eq!(params.evidence, fx.request.consensus_params.evidence);
        assert_eq!(params.validator, fx.request.consensus_params.validator);

        let dir = tempfile::tempdir().unwrap();
        let mut app = fx.app(dir.path());
        let Response::InitChain(resp) =
            app.handle(Request::InitChain(req.clone())).await.expect("InitChain accepts it")
        else {
            panic!("InitChain answers InitChain");
        };
        assert_eq!(resp.validators, req.validators);
        assert_eq!(app.state(), Some(&fx.expected_state()));
    }

    /// The witness is read at `L1_0` while the record is read at the finalized block.
    #[tokio::test]
    async fn reads_the_record_at_finalized_and_the_proofs_at_l1_0() {
        let mut spec = GenesisSpec::new(2);
        spec.params.l1_finality_extra_depth = 2;
        let fx = Fixture::build(spec);
        let l1 = fx.l1();
        let finalized = fx.activation.l1_0 + 2;
        fx.plant_l1_block(&l1, finalized, &fx.inbox, &fx.registry);

        let doc = build_genesis(&l1, &fx.params).await.expect("final with the extra depth");
        assert_eq!(init_chain_from(&doc).app_state_bytes, fx.request.app_state_bytes);
        let calls = l1.calls();
        assert_eq!(calls[0], L1Call::Finalized);
        assert!(calls[1..3].iter().all(
            |c| matches!(c, L1Call::StorageAt { address, block, .. } if *address == fx.params.inbox && *block == finalized)
        ), "{calls:?}");
        assert_eq!(calls[3], L1Call::Header(fx.activation.l1_0));
    }

    #[tokio::test]
    async fn inactive_inbox_is_rejected() {
        let fx = Fixture::genesis(1);
        let l1 = fx.l1();
        let mut inbox = fx.inbox.clone();
        inbox.migration_state = inbox::ETNA_ACTIVE - 1;
        fx.plant_l1_block(&l1, 70, &inbox, &fx.registry);
        l1.set_finalized(70);
        let err = build_genesis(&l1, &fx.params).await.unwrap_err();
        assert!(matches!(err, GenesisError::NotActive(2)), "{err:?}");
    }

    #[tokio::test]
    async fn activation_not_final_with_the_extra_depth_is_rejected() {
        let mut spec = GenesisSpec::new(1);
        spec.params.l1_finality_extra_depth = 2;
        let fx = Fixture::build(spec);
        let l1 = fx.l1();
        let l1_0 = fx.activation.l1_0;
        fx.plant_l1_block(&l1, l1_0 + 1, &fx.inbox, &fx.registry);
        l1.set_finalized(l1_0 + 1);
        let err = build_genesis(&l1, &fx.params).await.unwrap_err();
        assert!(
            matches!(err, GenesisError::ActivationNotFinal { l1_0: n, extra_depth: 2, finalized }
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

    /// The finalized record names L1 block 66, but the record proven there names 64.
    #[tokio::test]
    async fn activation_record_moved_since_l1_0_is_rejected() {
        let fx = Fixture::genesis(1);
        let l1 = fx.l1();
        fx.plant_l1_block(&l1, 66, &fx.inbox, &fx.registry);
        let mut moved = fx.inbox.clone();
        moved.activation.as_mut().expect("activated").l1_0 = 66;
        fx.plant_l1_block(&l1, 70, &moved, &fx.registry);
        l1.set_finalized(70);
        let err = build_genesis(&l1, &fx.params).await.unwrap_err();
        assert!(
            matches!(err, GenesisError::ActivationMismatch { l1_0: 66, proven: 64 }),
            "{err:?}"
        );
    }

    /// An own L1 node answering the header request for `L1_0` with another block's header.
    #[tokio::test]
    async fn a_header_of_another_l1_block_is_rejected() {
        let fx = Fixture::genesis(1);
        let l1 = fx.l1();
        let l1_0 = fx.activation.l1_0;
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
    async fn chain_id_carries_the_recovery_generation() {
        let mut spec = GenesisSpec::new(1);
        spec.recovery_generation = 1;
        let fx = Fixture::build(spec);
        let doc = build_genesis(&fx.l1(), &fx.params).await.expect("builds");
        assert!(doc.chain_id.ends_with("-g1"), "{}", doc.chain_id);
        assert_eq!(doc.chain_id, fx.request.chain_id);
    }
}
