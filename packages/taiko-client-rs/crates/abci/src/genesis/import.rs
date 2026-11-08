//! Pure bootstrap verification shared by `InitChain` and offline checkpoint import.

use std::collections::BTreeMap;

use alloy_primitives::{Address, B256};
use tendermint::Time;

use super::{
    AppStateJson, BootstrapWitness, GenesisConsensusParams, GenesisDoc, GenesisError,
    GenesisValidator, decode_bootstrap_state, genesis_time, verify_committee, verify_context,
};
use crate::{
    AccountWitness, AnchorState, AnchorWitness, ChainParams, CommitteeState, GenesisRecord,
    RawL1Header,
    l1::{layout::inbox, verify_anchor_witness},
    recovery::{RecoveryError, RecoveryOrigin, VerifiedRecovery, verify_recovery},
    rules::chain_id_for,
    store::{AppState, STATE_SCHEMA_VERSION},
    types::{Member, ParentInfo},
    valstate::{ValState, ValStateError},
};

/// Pure bootstrap facts; callers must independently check every retained header against own L1.
#[derive(Debug)]
pub struct VerifiedGenesis {
    /// Immutable deployment and epoch configuration.
    pub genesis: GenesisRecord,
    /// Initialization or recovery R anchor used as the new generation's floor.
    pub anchor: AnchorState,
    /// Independently derived initial committee.
    pub committee: CommitteeState,
    /// Fixed recovery origin; never a moving latest checkpoint.
    pub recovery: Option<RecoveryOrigin>,
    /// The Inbox proxy the witness proves (`params.inbox`).
    pub inbox: Address,
    /// Headers whose own-L1 canonicality/finality must be checked before installing state.
    pub l1_headers: Vec<RawL1Header>,
}

/// The CometBFT genesis fields the bootstrap evidence determines (START-10-20, RECOV-8.4-7/9):
/// `InitChain` compares its request with them, and import the whole original document.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GenesisExpectation {
    /// The 48-byte chain id of the generation (appendix A).
    pub chain_id: String,
    /// The first consensus height: the generation's origin height (S or c) plus one.
    pub initial_height: u64,
    /// The timestamp of `L1_0`, or of R for a recovery generation.
    pub genesis_time: Time,
    /// The initial committee, exactly the genesis validators (keys and powers).
    pub validators: Vec<Member>,
}

/// Verifies bootstrap evidence once, without I/O: generation zero's Inbox witness, schedule and
/// committee 0 at `genesisCutoff`; or a recovery witness (fixed origin, R observation, R's
/// committee and the deployment context, once) that embeds R as its finalized observation, with
/// R's anchor as the floor. Returns the verified facts and the genesis fields they determine.
///
/// This grants no finality: callers authenticate `l1_headers` against their own L1 and acquire
/// the origin's EL parent (and a recovery's historical anchor) before
/// [`VerifiedGenesis::origin_state`].
pub fn verify_bootstrap(
    witness: &BootstrapWitness,
    params: &ChainParams,
) -> Result<(VerifiedGenesis, GenesisExpectation), GenesisError> {
    let chain_id = |generation| {
        chain_id_for(params, generation)
            .map_err(|e| GenesisError::UnsupportedRecovery(e.to_string()))
    };
    match witness {
        BootstrapWitness::Initial(w) => {
            let context = verify_context(&w.l1_header, &w.inbox, params)?;
            let committee = verify_committee(&context, &w.committee, params)?;
            let expected = GenesisExpectation {
                chain_id: chain_id(0)?,
                initial_height: context.genesis.genesis_height + 1,
                genesis_time: genesis_time(w.l1_header.timestamp())?,
                validators: committee.members.clone(),
            };
            let verified = VerifiedGenesis {
                genesis: context.genesis,
                anchor: context.anchor,
                committee,
                recovery: None,
                inbox: params.inbox,
                l1_headers: vec![w.l1_header.clone()],
            };
            Ok((verified, expected))
        }
        BootstrapWitness::Recovery(w) => {
            let VerifiedRecovery { origin, context, .. } = verify_recovery(w, params)?;
            if w.finalized_header != w.recovery_header || w.finalized_inbox != w.recovery_inbox {
                return Err(RecoveryError::Invalid(
                    "recovery genesis must embed the canonical R observation".into(),
                )
                .into());
            }
            let anchor_slots = inbox::anchor_slots();
            let anchor = verify_anchor_witness(
                &AnchorWitness {
                    l1_header: w.recovery_header.clone(),
                    inbox: AccountWitness {
                        storage: w
                            .recovery_inbox
                            .storage
                            .iter()
                            .filter(|p| anchor_slots.contains(&p.slot))
                            .cloned()
                            .collect(),
                        ..w.recovery_inbox.clone()
                    },
                },
                params.inbox,
            )?;
            let expected = GenesisExpectation {
                chain_id: chain_id(origin.generation)?,
                initial_height: origin.height + 1,
                genesis_time: genesis_time(origin.l1_timestamp)?,
                validators: origin.committee.members.clone(),
            };
            let verified = VerifiedGenesis {
                genesis: context.genesis,
                anchor,
                committee: origin.committee.clone(),
                recovery: Some(origin),
                inbox: params.inbox,
                l1_headers: vec![w.genesis.l1_header.clone(), w.recovery_header.clone()],
            };
            Ok((verified, expected))
        }
    }
}

impl VerifiedGenesis {
    /// The generation's origin height: S at generation zero, c for a recovery.
    pub fn origin_height(&self) -> u64 {
        self.recovery.as_ref().map_or(self.genesis.genesis_height, |origin| origin.height)
    }

    /// The EL hash at the origin, the genesis's `app_hash`: H* at generation zero, ELHash(c)
    /// for a recovery (CONS-3.1-8).
    pub fn origin_hash(&self) -> B256 {
        self.recovery.as_ref().map_or(self.genesis.genesis_hash, |origin| origin.el_hash)
    }

    /// The `AppState` the generation starts from at its origin, for `InitChain` and import alike
    /// (START-10-22, RECOV-8.4-7..11, DATA-5.4-1): `parent` summarizes the origin EL block (B*
    /// or c), which the caller authenticated against [`VerifiedGenesis::origin_hash`]; `anchor`
    /// is the anchor that block inherited: [`VerifiedGenesis::anchor`] (`L1_0`) at generation
    /// zero, or a recovery's historical anchor from its verified bootstrap sidecar
    /// ([`VerifiedBootstrap::anchor`](crate::recovery::VerifiedBootstrap::anchor)), never R. The
    /// state holds the initial committee, the origin's forced inclusion cursor and CometBFT's
    /// genesis validator state of that committee at the origin height, which fails exactly
    /// where CometBFT would refuse the set.
    pub fn origin_state(
        &self,
        chain_id: String,
        parent: ParentInfo,
        anchor: AnchorState,
    ) -> Result<AppState, ValStateError> {
        let height = self.origin_height();
        let validators: Vec<_> =
            self.committee.members.iter().map(|m| (m.pubkey, m.power)).collect();
        Ok(AppState {
            schema_version: STATE_SCHEMA_VERSION,
            app_version: crate::app::APP_VERSION,
            chain_id,
            generation: self.recovery.as_ref().map_or(0, |origin| origin.generation),
            recovery: self.recovery.clone(),
            inbox: self.inbox,
            genesis: self.genesis.clone(),
            last_height: height,
            last_comet_hash: B256::ZERO,
            parent,
            anchor,
            forced_cursor: self.recovery.as_ref().map_or(0, |origin| origin.forced_cursor),
            committees: BTreeMap::from([(
                self.committee.record.target_epoch,
                self.committee.clone(),
            )]),
            val_state: ValState::genesis(height, &validators)?,
        })
    }
}

/// Reconstructs and compares the complete original stock genesis document from its witnesses:
/// [`verify_bootstrap`] and an exact comparison of every field with the expected document.
/// This performs no I/O and grants no finality or authority; callers authenticate `l1_headers`.
pub fn verify_original_genesis(
    doc: &GenesisDoc,
    params: &ChainParams,
) -> Result<VerifiedGenesis, GenesisError> {
    let encoded = serde_json::to_vec(&doc.app_state).expect("genesis app state serializes");
    let witness = decode_bootstrap_state(&encoded)?;
    let (verified, expected) = verify_bootstrap(&witness, params)?;
    let expected = GenesisDoc {
        genesis_time: expected.genesis_time.to_rfc3339(),
        chain_id: expected.chain_id,
        initial_height: expected.initial_height.to_string(),
        consensus_params: GenesisConsensusParams::etna(),
        validators: expected.validators.iter().map(GenesisValidator::from_member).collect(),
        app_hash: alloy_primitives::hex::encode_upper(verified.origin_hash()),
        app_state: match &witness {
            BootstrapWitness::Initial(w) => AppStateJson::from(w),
            BootstrapWitness::Recovery(w) => AppStateJson::from(w),
        },
    };
    if *doc != expected {
        return Err(GenesisError::UnsupportedRecovery(
            "genesis document differs from authenticated original identity".into(),
        ));
    }
    Ok(verified)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn original_identity_cannot_be_rebased_to_checkpoint() {
        let fx = crate::test_utils::Fixture::genesis(1);
        let mut doc = super::super::GenesisDoc::assemble(
            &fx.witness,
            fx.request.chain_id.clone(),
            &fx.members,
        )
        .unwrap();
        doc.initial_height = "7".into();
        assert!(verify_original_genesis(&doc, &fx.params).is_err());
    }

    /// The import's origin `AppState` (`VerifiedGenesis::origin_state` over its verified
    /// original genesis) is exactly the state `InitChain` persists for the same genesis: at
    /// generation zero, and at a recovery origin c (c = 0 and c > 0), whose anchor is the
    /// historical one of its verified bootstrap sidecar, not R (DATA-5.4-1, RECOV-8.4-7).
    #[tokio::test]
    async fn init_chain_and_import_build_the_same_origin_state() {
        use crate::{
            app::{App, AppOptions},
            recovery::recovery_parent,
            store::Store,
            test_utils::{init_chain_request, recovery_fixture},
            types::ParentInfo,
            wire::Request,
        };
        let fx = crate::test_utils::Fixture::genesis(3);
        let doc =
            GenesisDoc::assemble(&fx.witness, fx.request.chain_id.clone(), &fx.members).unwrap();
        assert_eq!(init_chain_request(&doc), fx.request);
        let dir = tempfile::tempdir().unwrap();
        let mut app = fx.app(dir.path());
        app.handle(Request::InitChain(fx.request.clone())).await.unwrap();
        let fixed = verify_original_genesis(&doc, &fx.params).unwrap();
        // The import summarizes its origin header B* as the parent, with no grandparent.
        let b_star = &fx.el_chain[0];
        let parent = ParentInfo {
            number: b_star.number,
            hash: b_star.hash_slow(),
            timestamp: b_star.timestamp,
            gas_limit: b_star.gas_limit,
            gas_used: b_star.gas_used,
            base_fee: b_star.base_fee_per_gas.unwrap(),
            difficulty: b_star.difficulty,
            grandparent_timestamp: 0,
        };
        let state = fixed.origin_state(doc.chain_id.clone(), parent, fixed.anchor.clone()).unwrap();
        assert_eq!(app.state(), Some(&state));
        assert_eq!(state, fx.expected_state());

        for c in [0, 6] {
            let (fx, l1, engine, _) = recovery_fixture(1, c, 1);
            let doc = crate::build_recovery_genesis(&l1, &engine, &fx.params, 1).await.unwrap();
            let dir = tempfile::tempdir().unwrap();
            let store = Store::volatile(dir.path().to_path_buf());
            let mut app =
                App::new(l1, engine, fx.params.clone(), store.clone(), AppOptions::default())
                    .unwrap();
            app.handle(Request::InitChain(init_chain_request(&doc))).await.unwrap();
            let fixed = verify_original_genesis(&doc, &fx.params).unwrap();
            let history =
                store.load_recovery_bootstrap().unwrap().unwrap().verify(&fx.params).unwrap();
            assert_ne!(history.anchor, fixed.anchor, "c = {c}: the historical anchor is not R");
            let state = fixed
                .origin_state(
                    doc.chain_id.clone(),
                    recovery_parent(&history.witness),
                    history.anchor,
                )
                .unwrap();
            assert_eq!(app.state(), Some(&state), "c = {c}");
            assert_eq!(state.last_height, c);
        }
    }
}
