//! Pure bootstrap verification shared by `InitChain` and offline checkpoint import.

use std::collections::BTreeMap;

use alloy_primitives::{Address, B256};
use tendermint::Time;

use super::{
    AppStateJson, BootstrapWitness, GenesisConsensusParams, GenesisDoc, GenesisError,
    GenesisValidator, decode_bootstrap_state, genesis_time, verify_committee, verify_context,
};
use crate::{
    AnchorState, ChainParams, CommitteeState, GenesisRecord, RawL1Header,
    fallback::FallbackKeys,
    key::ConsensusKey,
    recovery::{RecoveryError, RecoveryOrigin, VerifiedRecovery, recovery_anchor, verify_recovery},
    rules::chain_id_for,
    store::{AppState, STATE_SCHEMA_VERSION},
    types::{Member, ParentInfo},
    valstate::ValState,
};

/// Pure bootstrap facts; callers must independently check every retained header against own L1.
#[derive(Debug)]
pub struct VerifiedGenesis {
    /// Immutable deployment and epoch configuration.
    pub genesis: GenesisRecord,
    /// Initialization or recovery R anchor used as the new generation's floor.
    pub anchor: AnchorState,
    /// Generation zero's independently derived initial committee; `None` for a recovery
    /// generation, which starts on its origin's fallback keys.
    pub committee: Option<CommitteeState>,
    /// A recovery generation's origin fallback key list, the one whose hash the origin record
    /// holds: the evidence proves only that hash, so the list is `None` until
    /// [`VerifiedGenesis::with_fallback_keys`] supplies it. Always `None` at generation zero.
    pub fallback_keys: Option<FallbackKeys>,
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
    /// Generation zero's initial committee, exactly the genesis validators (keys and powers).
    /// `None` for a recovery generation: its genesis validators are the keys of the list whose
    /// hash the origin record holds, each at power 1, which only that list determines.
    pub validators: Option<Vec<Member>>,
}

/// Verifies bootstrap evidence once, without I/O: generation zero's Inbox witness, schedule and
/// committee 0 at `genesisCutoff`; or a recovery witness (fixed origin, R observation and the
/// deployment context, once) that embeds R as its finalized observation, with R's anchor as the
/// floor. Returns the verified facts and the genesis fields they determine.
///
/// This grants no finality: callers authenticate `l1_headers` against their own L1 and acquire
/// the origin's EL parent (and a recovery's historical anchor and origin fallback key list)
/// before [`VerifiedGenesis::origin_state`].
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
                validators: Some(committee.members.clone()),
            };
            let verified = VerifiedGenesis {
                genesis: context.genesis,
                anchor: context.anchor,
                committee: Some(committee),
                fallback_keys: None,
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
            let anchor = recovery_anchor(w, params)?;
            let expected = GenesisExpectation {
                chain_id: chain_id(origin.generation)?,
                initial_height: origin.height + 1,
                genesis_time: genesis_time(origin.l1_timestamp)?,
                validators: None,
            };
            let verified = VerifiedGenesis {
                genesis: context.genesis,
                anchor,
                committee: None,
                fallback_keys: None,
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

    /// The EL hash at the origin, which the genesis's `app_hash` commits with the genesis
    /// validator state (CONS-3.1-8): the start hash at generation zero, ELHash(c) for a recovery.
    pub fn origin_hash(&self) -> B256 {
        self.recovery.as_ref().map_or(self.genesis.genesis_hash, |origin| origin.el_hash)
    }

    /// A recovery generation's facts with its origin fallback key list `keys`, which must hash
    /// to the origin record's `fallbackKeysHash` ([`GenesisError::FallbackKeysMismatch`]).
    /// Generation zero takes no list here ([`GenesisError::UnsupportedRecovery`]).
    pub fn with_fallback_keys(mut self, keys: FallbackKeys) -> Result<Self, GenesisError> {
        let Some(origin) = &self.recovery else {
            return Err(GenesisError::UnsupportedRecovery(
                "generation zero starts on its committee, not on a fallback key list".into(),
            ));
        };
        if keys.hash() != origin.fallback_keys_hash {
            return Err(GenesisError::FallbackKeysMismatch {
                got: keys.hash(),
                expected: origin.fallback_keys_hash,
            });
        }
        self.fallback_keys = Some(keys);
        Ok(self)
    }

    /// The set that signs the generation's first two blocks, keys with their powers: generation
    /// zero's committee, or a recovery generation's origin fallback keys, each at power 1.
    /// [`GenesisError::FallbackKeysUnavailable`] for a recovery whose list has not been supplied
    /// ([`VerifiedGenesis::with_fallback_keys`]).
    pub fn initial_set(&self) -> Result<Vec<(ConsensusKey, u64)>, GenesisError> {
        match (&self.recovery, &self.fallback_keys, &self.committee) {
            (None, _, Some(committee)) => {
                Ok(committee.members.iter().map(|m| (m.pubkey, m.power)).collect())
            }
            (Some(_), Some(keys), _) => Ok(keys.validator_set()),
            (Some(origin), None, _) => {
                Err(GenesisError::FallbackKeysUnavailable(origin.fallback_keys_hash))
            }
            (None, _, None) => {
                Err(GenesisError::UnsupportedRecovery("generation zero has no committee".into()))
            }
        }
    }

    /// The `AppState` the generation starts from at its origin, for `InitChain` and import alike
    /// (START-10-22, RECOV-8.4-7..11, DATA-5.4-1): `parent` summarizes the origin EL block (the
    /// Etna start block or c), which the caller authenticated against
    /// [`VerifiedGenesis::origin_hash`]; `anchor` is the anchor that block inherited:
    /// [`VerifiedGenesis::anchor`] (`L1_0`) at generation zero, or a recovery's historical
    /// anchor from its verified bootstrap sidecar
    /// ([`VerifiedBootstrap::anchor`](crate::recovery::VerifiedBootstrap::anchor)), never R. The
    /// state holds the origin's forced inclusion cursor, CometBFT's genesis validator state of
    /// the initial set ([`VerifiedGenesis::initial_set`]) at the origin height, which fails
    /// exactly where CometBFT would refuse the set, and, for a recovery, the origin fallback key
    /// list in its cache of lists by hash.
    pub fn origin_state(
        &self,
        chain_id: String,
        parent: ParentInfo,
        anchor: AnchorState,
    ) -> Result<AppState, GenesisError> {
        let height = self.origin_height();
        let validators = self.initial_set()?;
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
            val_state: ValState::genesis(height, &validators)?,
            fallback_keys: self
                .fallback_keys
                .iter()
                .map(|keys| (keys.hash(), keys.clone()))
                .collect::<BTreeMap<_, _>>(),
            execution_floor: None,
        })
    }
}

/// The fallback key list a recovery genesis document names: the keys of its `validators`, in
/// ascending order. The document's exact form, each key once at power 1 in list order, is left
/// to the comparison with the document the list determines. `None` when the keys do not form a
/// list (none, more than 128, or one twice).
fn document_fallback_keys(validators: &[GenesisValidator]) -> Option<FallbackKeys> {
    let mut keys: Vec<_> = validators.iter().map(|validator| validator.pub_key.0).collect();
    keys.sort();
    FallbackKeys::new(keys).ok()
}

/// Reconstructs and compares the complete original stock genesis document from its witnesses:
/// [`verify_bootstrap`] and an exact comparison of every field with the expected document.
/// A recovery document's validators name its origin fallback key list, which is accepted only
/// when it hashes to the origin record's `fallbackKeysHash`
/// ([`VerifiedGenesis::with_fallback_keys`]); the returned facts carry it.
/// This performs no I/O and grants no finality or authority; callers authenticate `l1_headers`.
pub fn verify_original_genesis(
    doc: &GenesisDoc,
    params: &ChainParams,
) -> Result<VerifiedGenesis, GenesisError> {
    let encoded = serde_json::to_vec(&doc.app_state).expect("genesis app state serializes");
    let witness = decode_bootstrap_state(&encoded)?;
    let (mut verified, expected) = verify_bootstrap(&witness, params)?;
    if verified.recovery.is_some() {
        let keys = document_fallback_keys(&doc.validators).ok_or_else(|| {
            GenesisError::UnsupportedRecovery(
                "recovery genesis validators are not a fallback key list".into(),
            )
        })?;
        verified = verified.with_fallback_keys(keys)?;
    }
    let validators = verified.initial_set()?;
    let expected = GenesisDoc {
        genesis_time: expected.genesis_time.to_rfc3339(),
        chain_id: expected.chain_id,
        initial_height: expected.initial_height.to_string(),
        consensus_params: GenesisConsensusParams::etna(params.n_max),
        validators: validators
            .iter()
            .map(|(key, power)| GenesisValidator::new(*key, *power))
            .collect(),
        app_hash: super::genesis_app_hash(
            verified.origin_height(),
            verified.origin_hash(),
            &validators,
        )?,
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
            fx.params.n_max,
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
        let doc = GenesisDoc::assemble(
            &fx.witness,
            fx.request.chain_id.clone(),
            &fx.members,
            fx.params.n_max,
        )
        .unwrap();
        assert_eq!(init_chain_request(&doc), fx.request);
        let dir = tempfile::tempdir().unwrap();
        let mut app = fx.app(dir.path());
        app.handle(Request::InitChain(fx.request.clone())).await.unwrap();
        let fixed = verify_original_genesis(&doc, &fx.params).unwrap();
        // The import summarizes its origin header, the Etna start block, as the parent, with no
        // grandparent.
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
