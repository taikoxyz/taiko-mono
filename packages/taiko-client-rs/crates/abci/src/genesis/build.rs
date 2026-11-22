//! The `abci-genesis` builder: reads the Ethereum-final genesis record and generation 0's origin
//! fallback key list from the node's own L1, checks them as `InitChain` will, and assembles the
//! CometBFT genesis document.

use super::{GenesisDoc, GenesisError, GenesisWitness, verify_context};
use crate::{
    config::ChainParams,
    fallback::{FallbackFetchError, fetch_fallback_keys},
    l1::{
        L1Source, header_at,
        layout::{inbox, word_u8, word_u48},
    },
    rules::chain_id_for,
};

/// Builds the CometBFT genesis of the initialized Etna chain from the node's own L1.
///
/// In order: reads, unproven, the Inbox's `migrationState` and genesis word at the L1
/// `finalized` block and requires `ETNA_ACTIVE` ([`GenesisError::NotActive`]); requires the
/// initialization block `L1_0` to be at most that block ([`GenesisError::InitializationNotFinal`]);
/// takes the canonical header of `L1_0` and the Inbox proofs of `genesis_slots()` there, and
/// verifies them as `InitChain` will (the record must name the same `L1_0`, and the
/// configuration hash must be the built-in one); then obtains, at `L1_0`, the fallback key list
/// whose hash generation 0's origin record holds ([`fetch_fallback_keys`]: `getFallbackKeys()`
/// there, else the list's `FallbackKeysUpdated` log at or below `L1_0`). A list the own L1 cannot
/// give is [`GenesisError::FallbackKeysUnavailable`], a failed log query
/// [`GenesisError::L1`].
///
/// The document uses the 48-byte deployment-domain chain ID, `initial_height = S + 1`,
/// `genesis_time` = the `L1_0` timestamp, the list's keys in ascending order, each at voting
/// power 1, as validators and the genesis witness as `app_state`. Nothing in it is trusted:
/// `InitChain` re-verifies all of it against each node's own L1 and accepts the validators only
/// when their list hashes to the origin record's `fallbackKeysHash`.
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
    if l1_0 > finalized {
        return Err(GenesisError::InitializationNotFinal { l1_0, finalized });
    }

    let l1_header = header_at(l1, l1_0).await?;
    let inbox_witness = l1.account_witness(params.inbox, &inbox::genesis_slots(), l1_0).await?;
    let context = verify_context(&l1_header, &inbox_witness, params)?;
    let hash = context.fallback_keys_hash;
    let keys = fetch_fallback_keys(l1, params.inbox, hash, l1_header.hash(), l1_0, 0)
        .await
        .map_err(|error| match error {
            FallbackFetchError::L1(error) => GenesisError::L1(error),
            FallbackFetchError::Unavailable(reason) => {
                GenesisError::FallbackKeysUnavailable { hash, reason }
            }
        })?;
    let chain_id = chain_id_for(params, context.anchor.inbox.recovery_generation)
        .map_err(|e| GenesisError::UnsupportedRecovery(e.to_string()))?;
    GenesisDoc::assemble(
        &GenesisWitness { l1_header, inbox: inbox_witness },
        chain_id,
        &keys.validator_set(),
    )
}

#[cfg(test)]
mod tests {
    use crate::wire::{Request, Response, request::InitChain};
    use tendermint::block::Height;

    use super::*;
    use crate::{
        fallback::FALLBACK_KEYS_UPDATED,
        l1::{L1Error, layout::inbox},
        test_utils::{Fixture, GenesisSpec, L1Call, fallback_list, serve_fallback_keys},
    };

    /// The `InitChain` request CometBFT sends for `doc`: the document is parsed as a CometBFT
    /// native genesis file (with the application parser), the validators carry their secp256k1eth
    /// keys and powers, and `app_state` is passed on as its raw JSON bytes. The request passes
    /// through the ABCI protobuf conversion, as the server's wire decoder does: JSON's explicit
    /// vote extension height zero becomes the typed request's disabled `None` value.
    fn init_chain_from(doc: &GenesisDoc) -> InitChain {
        let genesis: GenesisDoc = serde_json::from_str(&doc.to_json_pretty()).unwrap();
        InitChain {
            time: genesis.genesis_time.parse().unwrap(),
            chain_id: genesis.chain_id,
            consensus_params: crate::test_utils::abci_consensus_params(&genesis.consensus_params),
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
        assert_eq!(params.block.as_ref().unwrap().max_bytes, 2_097_152);
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

    /// The record is read at the finalized block, the witness and the origin list at `L1_0`.
    #[tokio::test]
    async fn reads_the_record_at_finalized_and_the_proofs_at_l1_0() {
        let fx = Fixture::build(GenesisSpec::new(2));
        let l1 = fx.l1();
        let finalized = fx.genesis.l1_0 + 2;
        fx.plant_l1_block(&l1, finalized, &fx.inbox);
        l1.set_finalized(finalized);

        let doc = build_genesis(&l1, &fx.params).await.expect("L1_0 is final");
        assert_eq!(init_chain_from(&doc).app_state_bytes, fx.request.app_state_bytes);
        let calls = l1.calls();
        assert_eq!(calls[0], L1Call::Finalized);
        assert!(calls[1..3].iter().all(
            |c| matches!(c, L1Call::StorageAt { address, block, .. } if *address == fx.params.inbox && *block == finalized)
        ), "{calls:?}");
        assert_eq!(calls[3], L1Call::Header(fx.genesis.l1_0));
        assert!(
            matches!(&calls[4], L1Call::AccountWitness { block, .. } if *block == fx.genesis.l1_0),
            "{calls:?}"
        );
        assert!(
            matches!(&calls[5], L1Call::CallAt { hash, .. } if *hash == fx.witness.l1_header.hash()),
            "{calls:?}"
        );
        assert_eq!(calls.len(), 6, "{calls:?}");
    }

    /// The validators are the keys of the list whose hash generation 0's origin record holds, in
    /// ascending order, each at power 1, even when the Inbox has since stored another list: that
    /// one is not the origin's, so the list comes from its `FallbackKeysUpdated` log at `L1_0`.
    #[tokio::test]
    async fn genesis_builder_emits_the_list_whose_hash_the_origin_holds() {
        let fx = Fixture::build(GenesisSpec::new(4));
        let doc = build_genesis(&fx.l1(), &fx.params).await.unwrap();
        let keys: Vec<_> = doc.validators.iter().map(|v| v.pub_key.0).collect();
        assert_eq!(keys, fx.fallback_keys.keys());
        assert!(keys.is_sorted(), "ascending");
        assert!(doc.validators.iter().all(|v| v.power == "1"));
        assert_eq!(init_chain_from(&doc), fx.request);

        let l1 = fx.l1();
        serve_fallback_keys(&l1, fx.params.inbox, &fallback_list(&[7, 8]));
        let origin = &fx.fallback_keys;
        l1.insert_log(
            fx.genesis.l1_0,
            fx.params.inbox,
            [FALLBACK_KEYS_UPDATED, origin.hash()],
            origin.abi_encode().into(),
        );
        assert_eq!(build_genesis(&l1, &fx.params).await.unwrap(), doc);
    }

    /// An own L1 that gives no list with the origin's hash leaves the origin list unavailable;
    /// a failed log query is an L1 error.
    #[tokio::test]
    async fn an_unobtainable_origin_list_is_unavailable() {
        let fx = Fixture::genesis(2);
        let l1 = fx.l1();
        serve_fallback_keys(&l1, fx.params.inbox, &fallback_list(&[7, 8]));
        let err = build_genesis(&l1, &fx.params).await.unwrap_err();
        assert!(
            matches!(&err, GenesisError::FallbackKeysUnavailable { hash, .. }
                if *hash == fx.fallback_keys.hash()),
            "{err:?}"
        );
        l1.state().log_fail = Some(L1Error::Rpc("down".into()));
        let err = build_genesis(&l1, &fx.params).await.unwrap_err();
        assert!(matches!(err, GenesisError::L1(L1Error::Rpc(_))), "{err:?}");
    }

    /// The Inbox's configuration hash must be the one of the built-in L2 chain id, staking proxy
    /// and U: another staking address does not open it.
    #[tokio::test]
    async fn another_staking_address_misses_the_configuration_hash() {
        let fx = Fixture::genesis(1);
        let params =
            ChainParams { staking: alloy_primitives::Address::repeat_byte(9), ..fx.params.clone() };
        let err = build_genesis(&fx.l1(), &params).await.unwrap_err();
        assert!(
            matches!(err, GenesisError::ConfigMismatch { local, proven }
                if local == params.config_hash() && proven == fx.genesis.config_hash),
            "{err:?}"
        );
    }

    #[tokio::test]
    async fn inactive_inbox_is_rejected() {
        let fx = Fixture::genesis(1);
        let l1 = fx.l1();
        let mut inbox = fx.inbox.clone();
        inbox.status = inbox::ETNA_ACTIVE - 1;
        fx.plant_l1_block(&l1, 70, &inbox);
        l1.set_finalized(70);
        let err = build_genesis(&l1, &fx.params).await.unwrap_err();
        assert!(matches!(err, GenesisError::NotActive(2)), "{err:?}");
    }

    #[tokio::test]
    async fn initialization_above_the_finalized_block_is_rejected() {
        let fx = Fixture::build(GenesisSpec::new(1));
        let l1 = fx.l1();
        let l1_0 = fx.genesis.l1_0;
        // An Inbox at the finalized block claiming a later initialization block.
        fx.plant_l1_block(&l1, l1_0 - 1, &fx.inbox);
        l1.set_finalized(l1_0 - 1);
        let err = build_genesis(&l1, &fx.params).await.unwrap_err();
        assert!(
            matches!(err, GenesisError::InitializationNotFinal { l1_0: n, finalized }
                if n == l1_0 && finalized == l1_0 - 1),
            "{err:?}"
        );
        assert!(!l1.calls().iter().any(|c| matches!(c, L1Call::Header(_))), "no proof read");
    }

    /// The finalized record names L1 block 66, but the record proven there names 64.
    #[tokio::test]
    async fn genesis_record_moved_since_l1_0_is_rejected() {
        let fx = Fixture::genesis(1);
        let l1 = fx.l1();
        fx.plant_l1_block(&l1, 66, &fx.inbox);
        let mut moved = fx.inbox.clone();
        moved.genesis.as_mut().expect("initialized").l1_0 = 66;
        fx.plant_l1_block(&l1, 70, &moved);
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
