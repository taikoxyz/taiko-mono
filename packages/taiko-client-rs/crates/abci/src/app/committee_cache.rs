//! Durable, independently verified switch witnesses, separate from consensus state.

use alloy_primitives::{Address, B256, Bytes};
use serde::{Deserialize, Serialize};

use super::{App, Rejection};
use crate::{
    committee::{committee_config_hash, verify_committee_witness},
    config::ChainParams,
    engine::Engine,
    envelope::CommitteeWitness,
    l1::L1Source,
    store::{AppState, Store},
    types::GenesisRecord,
};

/// The complete context in which a runtime committee witness is valid.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
struct CacheKey {
    /// CometBFT chain identity, including its recovery generation.
    chain_id: String,
    /// Genesis identity and schedule used for eligibility derivation.
    genesis: GenesisRecord,
    /// Inbox contract opening used by this app.
    inbox: Address,
    /// The registry and derivation parameters authenticated by genesis.
    committee_config_hash: B256,
    /// Fixed committed parent anchor number, also the snapshot cutoff.
    parent_anchor: u64,
    /// Fixed committed parent anchor hash; prevents same-height identity reuse.
    parent_anchor_hash: B256,
    /// Fixed committed parent state root against which all registry proofs verify.
    parent_state_root: B256,
    /// Epoch whose incoming committee is derived.
    target_epoch: u64,
}

impl CacheKey {
    /// Binds the witness to every authenticated input of its derivation.
    fn new(state: &AppState, params: &ChainParams, target_epoch: u64) -> Self {
        Self {
            chain_id: state.chain_id.clone(),
            genesis: state.genesis.clone(),
            inbox: params.inbox,
            committee_config_hash: committee_config_hash(params),
            parent_anchor: state.anchor.number,
            parent_anchor_hash: state.anchor.hash,
            parent_state_root: state.anchor.state_root,
            target_epoch,
        }
    }
}

/// One verified witness held in memory after its durable sidecar is saved or reverified.
#[derive(Clone, Debug)]
pub(super) struct CachedCommittee {
    /// Authentication and derivation identity.
    key: CacheKey,
    /// Complete verified registry witness, including the snapshot entries.
    witness: CommitteeWitness,
}

/// The bounded sidecar representation; its RLP witness is always untrusted on load.
#[derive(Serialize, Deserialize)]
struct PersistedCommittee {
    /// Identity to compare before decoding and verifying the witness.
    key: CacheKey,
    /// Exact RLP witness bytes, decoded with trailing bytes forbidden.
    witness: Bytes,
}

/// Loads a sidecar only for the next switch height, verifies it without L1 I/O, and ignores a
/// corrupt, stale or mismatched sidecar so ordinary acquisition or archive fallback can recover.
pub(super) fn load_cached_committee(
    store: &Store,
    state: Option<&AppState>,
    params: &ChainParams,
) -> Option<CachedCommittee> {
    let bytes = match store.load_committee_witness() {
        Ok(bytes) => bytes?,
        Err(error) => {
            tracing::warn!(%error, "ignoring unreadable committee witness sidecar");
            return None;
        }
    };
    let state = state?;
    let target = state.schedule().switch_target(state.last_height + 1)?;
    let persisted: PersistedCommittee = match serde_json::from_slice(&bytes) {
        Ok(persisted) => persisted,
        Err(error) => {
            tracing::warn!(%error, "ignoring malformed committee witness sidecar");
            return None;
        }
    };
    if persisted.key != CacheKey::new(state, params, target) {
        tracing::debug!("ignoring committee witness sidecar for another context");
        return None;
    }
    let witness = match alloy_rlp::decode_exact::<CommitteeWitness>(&persisted.witness) {
        Ok(witness) => witness,
        Err(error) => {
            tracing::warn!(%error, "ignoring malformed cached committee witness");
            return None;
        }
    };
    if let Err(error) =
        verify_committee_witness(&state.anchor, &state.schedule(), params, &witness, target)
    {
        tracing::warn!(%error, "ignoring unverified cached committee witness");
        return None;
    }
    Some(CachedCommittee { key: persisted.key, witness })
}

impl<L: L1Source, E: Engine> App<L, E> {
    /// Returns a previously verified witness only for the same complete authenticated context.
    pub(super) fn cached_committee_witness(
        &self,
        state: &AppState,
        target_epoch: u64,
    ) -> Option<CommitteeWitness> {
        let key = CacheKey::new(state, &self.params, target_epoch);
        self.committee_cache()
            .as_ref()
            .and_then(|cached| (cached.key == key).then(|| cached.witness.clone()))
    }

    /// Verifies and durably saves a switch witness before retaining it for later proposal rounds.
    /// A write failure refuses this proposal with a node-local liveness error; no unverified or
    /// partially acquired reads enter the sidecar.
    pub(super) fn cache_committee_witness(
        &self,
        state: &AppState,
        target_epoch: u64,
        witness: &CommitteeWitness,
    ) -> Result<(), Rejection> {
        let key = CacheKey::new(state, &self.params, target_epoch);
        let mut cache = self.committee_cache();
        if cache.as_ref().is_some_and(|cached| cached.key == key && cached.witness == *witness) {
            return Ok(());
        }
        verify_committee_witness(
            &state.anchor,
            &state.schedule(),
            &self.params,
            witness,
            target_epoch,
        )?;
        let persisted =
            PersistedCommittee { key: key.clone(), witness: alloy_rlp::encode(witness).into() };
        let bytes = serde_json::to_vec(&persisted)
            .map_err(|error| Rejection::CommitteeCache(error.to_string()))?;
        self.store
            .save_committee_witness(&bytes)
            .map_err(|error| Rejection::CommitteeCache(error.to_string()))?;
        *cache = Some(CachedCommittee { key, witness: witness.clone() });
        Ok(())
    }
}
