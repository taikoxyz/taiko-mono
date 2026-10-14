//! Durable, independently verified switch witnesses, separate from consensus state.

use std::{sync::Arc, time::Duration};

use alloy_primitives::{Address, B256, Bytes};
use serde::{Deserialize, Serialize};
use tokio::{sync::watch, task::JoinHandle};

use super::{App, Rejection};
use crate::{
    committee::{committee_config_hash, verify_committee_witness},
    config::ChainParams,
    engine::Engine,
    envelope::CommitteeWitness,
    l1::{DiscoveryProgress, L1Source, build_committee_witness_within},
    rules,
    store::{AppState, Store},
    types::GenesisRecord,
};

/// The bound of one background switch-witness discovery; a failed or timed-out discovery is
/// restarted by the next round or `Commit`.
const COMMITTEE_PREFETCH_TIMEOUT: Duration = Duration::from_secs(300);

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

/// One background discovery and verification of the switch witness for one context; dropping it
/// aborts the discovery.
#[derive(Debug)]
pub(super) struct CommitteePrefetch {
    /// The context the witness is discovered for.
    key: CacheKey,
    /// The verified witness, or why discovery failed; `None` while it runs.
    result: watch::Receiver<Option<Result<CommitteeWitness, String>>>,
    /// The reads finished so far, kept when a timed-out discovery for the same context restarts.
    progress: Arc<DiscoveryProgress>,
    /// The owned discovery.
    task: JoinHandle<()>,
}

impl Drop for CommitteePrefetch {
    /// Cancels a discovery for a context the committed state left.
    fn drop(&mut self) {
        self.task.abort();
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

/// The epoch `t` whose switch witness `state`'s committed anchor may have to prove: that of the
/// first switch `S(t)` after the committed height, while its derivation parent `D(t)` can still
/// carry this anchor, i.e. pass back-pressure against the anchor's last checkpoint height and
/// anchor freshness (`maxAnchorAge`), every height adding at least a second to the block
/// timestamp ([`block_timestamp`](crate::rules::block_timestamp)). Otherwise the chain adopts a
/// newer anchor before `D(t)`, whose own commit then qualifies. `None` past that, or on
/// overflow; at `D(t)` itself, always `t`.
fn prefetch_target(state: &AppState, params: &ChainParams) -> Option<u64> {
    let schedule = state.schedule();
    let target = schedule.next_switch_target(state.last_height.checked_add(1)?)?;
    let parent = schedule.derivation_parent_height(target)?;
    let heights_left = parent.checked_sub(state.last_height)?;
    let anchor = &state.anchor;
    let earliest = state.parent.timestamp.saturating_add(heights_left);
    let reachable = rules::check_back_pressure(
        parent,
        anchor.inbox.last_checkpoint_height,
        params.unsettled_cap(),
    )
    .is_ok() &&
        rules::check_anchor_freshness(earliest, anchor.timestamp, state.genesis.max_anchor_age)
            .is_ok();
    (heights_left == 0 || reachable).then_some(target)
}

/// Loads a sidecar only for the upcoming switch's context ([`prefetch_target`]), verifies it
/// without L1 I/O, and ignores a corrupt, stale or mismatched sidecar so ordinary acquisition or
/// archive fallback can recover.
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
    let target = prefetch_target(state, params)?;
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
    /// Makes sure the committee witness of the upcoming switch `S(t)` gets discovered under the
    /// committed anchor while that L1 state is recent, whenever that anchor may still be the
    /// parent anchor of `S(t)` ([`prefetch_target`]): unless the witness is cached, starts a
    /// background discovery (restarting a failed one), and adopts a finished one by verifying,
    /// persisting and caching it ([`App::cache_committee_witness`]). The witness is kept across
    /// commits while the committed anchor stays.
    ///
    /// Runs at a live `Commit` and at every `ProcessProposal`, which every node (full nodes
    /// included) handles in each round that delivers a proposal while it is not locked on a block,
    /// empty proposals included. The live `Commit` of the block adopting an anchor discovers its
    /// witness right away, so an L1 finality stall that keeps that anchor until `D(t)` (and on
    /// until freshness stops proposals), an outage or a restart at `D(t)` resumes from the
    /// durable witness even once the L1 node pruned the anchor's state, without an archive,
    /// provided that state was still served when the discovery ran. The sidecar is written on
    /// the handler only, so it has a single writer. `PrepareProposal` and a replayed `Commit` only
    /// adopt a finished discovery ([`App::adopt_committee_prefetch`]); a proposal waits for a
    /// running one.
    pub(super) fn prefetch_committee_witness(&self, state: &AppState) {
        self.refresh_committee_prefetch(state, true);
    }

    /// [`App::prefetch_committee_witness`] without starting a discovery: adopts a finished one,
    /// and drops a witness or discovery the cache or the committed state made obsolete.
    pub(super) fn adopt_committee_prefetch(&self, state: &AppState) {
        self.refresh_committee_prefetch(state, false);
    }

    /// Adopts, drops or (when `start`) starts the switch-witness prefetch for `state`; a timed-out
    /// discovery for the same context restarts from the reads it finished.
    fn refresh_committee_prefetch(&self, state: &AppState, start: bool) {
        let Some(target) = prefetch_target(state, &self.params) else {
            *self.committee_cache() = None;
            *self.committee_prefetch() = None;
            return;
        };
        let key = CacheKey::new(state, &self.params, target);
        {
            let mut cache = self.committee_cache();
            if cache.as_ref().is_some_and(|cached| cached.key == key) {
                drop(cache);
                *self.committee_prefetch() = None;
                return;
            }
            // Committed anchors and switches only move forward: no later state uses it.
            *cache = None;
        }
        let finished = {
            let mut slot = self.committee_prefetch();
            if slot.as_ref().is_some_and(|prefetch| prefetch.key != key) {
                *slot = None;
            }
            match slot.as_ref() {
                Some(prefetch) => prefetch.result.borrow().clone(),
                None => Some(Err("not started".into())),
            }
        };
        match finished {
            // Still running.
            None => {}
            Some(Ok(witness)) => match self.cache_committee_witness(state, target, &witness) {
                Ok(()) => *self.committee_prefetch() = None,
                Err(error) => tracing::warn!(%error, "prefetched committee witness not retained"),
            },
            Some(Err(_)) if start => {
                let mut slot = self.committee_prefetch();
                let progress = slot.take().map(|prefetch| Arc::clone(&prefetch.progress));
                *slot = Some(self.spawn_committee_prefetch(
                    key,
                    state,
                    target,
                    progress.unwrap_or_default(),
                ));
            }
            Some(Err(_)) => {}
        }
    }

    /// Waits for the running or finished prefetch of `target`'s witness under `state`, if any:
    /// a proposal then shares the background discovery instead of repeating its reads. `None`
    /// when there is none or it failed; the proposal then discovers on its own.
    pub(super) async fn prefetched_committee_witness(
        &self,
        state: &AppState,
        target: u64,
    ) -> Option<CommitteeWitness> {
        let key = CacheKey::new(state, &self.params, target);
        let mut result = {
            let slot = self.committee_prefetch();
            slot.as_ref().filter(|prefetch| prefetch.key == key)?.result.clone()
        };
        loop {
            let finished = result.borrow().clone();
            if let Some(finished) = finished {
                return finished.ok();
            }
            result.changed().await.ok()?;
        }
    }

    /// Discovers and verifies the committee witness of `target` under `state`'s parent anchor in
    /// the background, each read within the L1 deadline and all of it within
    /// [`COMMITTEE_PREFETCH_TIMEOUT`].
    fn spawn_committee_prefetch(
        &self,
        key: CacheKey,
        state: &AppState,
        target: u64,
        progress: Arc<DiscoveryProgress>,
    ) -> CommitteePrefetch {
        let (l1, params, schedule, anchor) =
            (Arc::clone(&self.l1), self.params.clone(), state.schedule(), state.anchor.clone());
        let read_timeout = self.opts.l1_timeout;
        let (sender, result) = watch::channel(None);
        let reads = Arc::clone(&progress);
        let task = tokio::spawn(async move {
            let discovery = build_committee_witness_within(
                &*l1,
                &params,
                &schedule,
                anchor.number,
                target,
                read_timeout,
                &reads,
            );
            let outcome = match tokio::time::timeout(COMMITTEE_PREFETCH_TIMEOUT, discovery).await {
                Ok(Ok(witness)) => {
                    verify_committee_witness(&anchor, &schedule, &params, &witness, target)
                        .map(|_| witness)
                        .map_err(|error| error.to_string())
                }
                Ok(Err(error)) => Err(error.to_string()),
                Err(_) => Err("timed out".into()),
            };
            if let Err(error) = &outcome {
                tracing::warn!(
                    parent_anchor = anchor.number,
                    target_epoch = target,
                    %error,
                    "committee witness prefetch failed"
                );
            }
            let _ = sender.send(Some(outcome));
        });
        CommitteePrefetch { key, result, progress, task }
    }

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
