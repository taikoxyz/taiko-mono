//! Independently verified switch witnesses, held in memory only and separate from consensus
//! state; a restart re-discovers them from the own L1 (SYNC-9-16).

use std::{sync::Arc, time::Duration};

use alloy_primitives::{Address, B256};
use tokio::{sync::watch, task::JoinHandle, time::Instant};

use super::{App, Rejection};
use crate::{
    committee::{committee_config_hash, verify_committee_witness_at_cutoff},
    config::ChainParams,
    engine::Engine,
    envelope::CommitteeWitness,
    l1::{DiscoveryProgress, L1Source, build_committee_witness_within, header_at},
    rules,
    store::AppState,
    types::{AnchorState, GenesisRecord},
};

/// The bound of one background switch-witness discovery; a failed or timed-out discovery is
/// restarted by a later round or `Commit` once its backoff ([`prefetch_backoff`]) has passed.
const COMMITTEE_PREFETCH_TIMEOUT: Duration = Duration::from_secs(300);

/// The pause before the first restart of a failed background switch-witness discovery.
const COMMITTEE_PREFETCH_BACKOFF: Duration = Duration::from_secs(2);

/// The longest pause between restarts of a failing background switch-witness discovery.
const COMMITTEE_PREFETCH_MAX_BACKOFF: Duration = Duration::from_secs(60);

/// The pause before restarting a discovery that failed after `failures` earlier failed attempts
/// for the same context: [`COMMITTEE_PREFETCH_BACKOFF`], doubling per failure up to
/// [`COMMITTEE_PREFETCH_MAX_BACKOFF`]. Every node runs the discovery, full nodes included, so an
/// L1 that cannot serve the anchor's state, or rate-limits it, sees one attempt per pause rather
/// than two per height.
fn prefetch_backoff(failures: u32) -> Duration {
    COMMITTEE_PREFETCH_BACKOFF
        .saturating_mul(2u32.saturating_pow(failures))
        .min(COMMITTEE_PREFETCH_MAX_BACKOFF)
}

/// The complete context in which a runtime committee witness is valid.
#[derive(Clone, Debug, PartialEq, Eq)]
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
    /// Candidate anchor identity under which the snapshot proof is authenticated.
    proof_anchor: (u64, B256, B256),
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
            proof_anchor: (state.anchor.number, state.anchor.hash, state.anchor.state_root),
        }
    }

    /// Whether `other` has the same derivation context, whatever anchor its proof used.
    fn same_context(&self, other: &Self) -> bool {
        let mut same = self.clone();
        same.proof_anchor = other.proof_anchor;
        same == *other
    }
}

/// One background discovery and verification of the switch witness for one context; dropping it
/// aborts the discovery.
#[derive(Debug)]
pub(super) struct CommitteePrefetch {
    /// The context the witness is discovered for.
    key: CacheKey,
    /// The verified witness, or when discovery failed (logged with why); `None` while it runs.
    result: watch::Receiver<Option<Result<PrefetchedCommittee, Instant>>>,
    /// The reads finished so far, kept when a discovery for the same context restarts after a
    /// failed read.
    progress: Arc<DiscoveryProgress>,
    /// The failed attempts for the same context before this one.
    failures: u32,
    /// The owned discovery.
    task: JoinHandle<()>,
}

/// A background discovery's verified witness and the L1 block its registry proofs verify under.
#[derive(Clone, Debug)]
pub(super) struct PrefetchedCommittee {
    /// The verified witness.
    pub(super) witness: CommitteeWitness,
    /// `(number, hash, stateRoot)` of the block whose root the proofs verify under: the parent
    /// anchor, or R before the first recovered commit ([`snapshot_block`]).
    pub(super) proof_anchor: (u64, B256, B256),
}

/// The L1 block a switch-witness discovery for `state` reads and proves at: the committed
/// parent anchor, or the generation origin R while that anchor still precedes it. Registry
/// checkpoints are append-only, so a snapshot proven at its own cutoff stays the same snapshot
/// under every later root.
fn snapshot_block(state: &AppState) -> u64 {
    state.anchor.number.max(state.anchor_floor())
}

impl Drop for CommitteePrefetch {
    /// Cancels a discovery for a context the committed state left.
    fn drop(&mut self) {
        self.task.abort();
    }
}

/// One verified witness held in memory; nothing of it is written to disk.
#[derive(Clone, Debug)]
pub(super) struct CachedCommittee {
    /// Authentication and derivation identity.
    key: CacheKey,
    /// Complete verified registry witness, including the snapshot entries.
    witness: CommitteeWitness,
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

impl<L: L1Source, E: Engine> App<L, E> {
    /// Makes sure the committee witness of the upcoming switch `S(t)` gets discovered under the
    /// committed anchor while that L1 state is recent, whenever that anchor may still be the
    /// parent anchor of `S(t)` ([`prefetch_target`]): unless the witness is cached, starts a
    /// background discovery (restarting a failed one after its backoff, [`prefetch_backoff`]),
    /// and adopts a finished one by verifying and caching it in memory
    /// ([`App::cache_committee_witness_at_root`]). The witness is kept across
    /// commits while the committed anchor stays.
    ///
    /// Runs at a live `Commit` and at every `ProcessProposal`, which every node (full nodes
    /// included) handles in each round that delivers a proposal while it is not locked on a block,
    /// empty proposals included. The live `Commit` of the block adopting an anchor discovers its
    /// witness right away, so an L1 finality stall that keeps that anchor until `D(t)` (and on
    /// until freshness stops proposals) or an outage resumes from the cached witness even once
    /// the L1 node pruned the anchor's state, provided that state was still served when the
    /// discovery ran. Nothing survives a restart: the restarted node discovers the witness again
    /// from its own L1, which must then still serve that state (SYNC-9-16). `PrepareProposal`
    /// and a replayed `Commit` only adopt a finished discovery
    /// ([`App::adopt_committee_prefetch`]); a proposal waits for a running one.
    pub(super) fn prefetch_committee_witness(&self, state: &AppState) {
        self.refresh_committee_prefetch(state, true);
    }

    /// [`App::prefetch_committee_witness`] without starting a discovery: adopts a finished one,
    /// and drops a witness or discovery the cache or the committed state made obsolete.
    pub(super) fn adopt_committee_prefetch(&self, state: &AppState) {
        self.refresh_committee_prefetch(state, false);
    }

    /// Adopts, drops or (when `start`) starts the switch-witness prefetch for `state`; a failed
    /// discovery for the same context restarts once its backoff has passed since it failed, and
    /// resumes from the reads it finished.
    fn refresh_committee_prefetch(&self, state: &AppState, start: bool) {
        // Before the first recovered commit the retained anchor of c precedes the generation
        // origin R. Only c + 1 can then be a switch whose snapshot this state fixes, and that
        // snapshot is R's (COMM-4.3-11), so the discovery runs at R ([`snapshot_block`]).
        let target = if state.anchor.number < state.anchor_floor() {
            state.last_height.checked_add(1).and_then(|next| state.schedule().switch_target(next))
        } else {
            prefetch_target(state, &self.params)
        };
        let Some(target) = target else {
            *self.committee_cache() = None;
            *self.committee_prefetch() = None;
            return;
        };
        let key = CacheKey::new(state, &self.params, target);
        {
            let mut cache = self.committee_cache();
            if cache.as_ref().is_some_and(|cached| key.same_context(&cached.key)) {
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
            slot.as_ref().map(|prefetch| (prefetch.result.borrow().clone(), prefetch.failures))
        };
        match finished {
            // Still running.
            Some((None, _)) => {}
            Some((Some(Ok(found)), _)) => {
                match self.cache_committee_witness_at_root(
                    state,
                    found.proof_anchor,
                    target,
                    &found.witness,
                ) {
                    Ok(()) => *self.committee_prefetch() = None,
                    Err(error) => {
                        tracing::warn!(%error, "prefetched committee witness not retained");
                    }
                }
            }
            Some((Some(Err(failed_at)), failures))
                if start && failed_at.elapsed() >= prefetch_backoff(failures) =>
            {
                let mut slot = self.committee_prefetch();
                let progress = slot.take().map(|failed| Arc::clone(&failed.progress));
                *slot = Some(self.spawn_committee_prefetch(
                    key,
                    state,
                    target,
                    progress.unwrap_or_default(),
                    failures.saturating_add(1),
                ));
            }
            None if start => {
                *self.committee_prefetch() =
                    Some(self.spawn_committee_prefetch(key, state, target, Arc::default(), 0));
            }
            Some((Some(Err(_)), _)) | None => {}
        }
    }

    /// Waits for the running or finished prefetch of `target`'s witness under `state`, if any:
    /// a proposal then shares the background discovery instead of repeating its reads. `None`
    /// when there is none or it failed; the proposal then discovers on its own.
    pub(super) async fn prefetched_committee_witness(
        &self,
        state: &AppState,
        target: u64,
    ) -> Option<PrefetchedCommittee> {
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

    /// Discovers and verifies the committee witness of `target` for `state` in the background at
    /// its [`snapshot_block`], each read within the L1 deadline and all of it within
    /// [`COMMITTEE_PREFETCH_TIMEOUT`], after `failures` failed attempts for the same context.
    ///
    /// At R the header comes from the own L1 like every other discovery read; a proposal still
    /// re-proves the witness under its own anchor, and every validator verifies it there.
    fn spawn_committee_prefetch(
        &self,
        key: CacheKey,
        state: &AppState,
        target: u64,
        progress: Arc<DiscoveryProgress>,
        failures: u32,
    ) -> CommitteePrefetch {
        let (l1, params, anchor) =
            (Arc::clone(&self.l1), self.params.clone(), state.anchor.clone());
        let block = snapshot_block(state);
        let read_timeout = self.opts.l1_timeout;
        let (sender, result) = watch::channel(None);
        let reads = Arc::clone(&progress);
        let task = tokio::spawn(async move {
            let discovery = async {
                let proof_anchor = if block == anchor.number {
                    (anchor.number, anchor.hash, anchor.state_root)
                } else {
                    let header = tokio::time::timeout(read_timeout, header_at(&*l1, block))
                        .await
                        .map_err(|_| "registry header read timed out".to_string())?
                        .map_err(|error| error.to_string())?;
                    (header.number(), header.hash(), header.state_root())
                };
                let witness = build_committee_witness_within(
                    &*l1,
                    &params,
                    block,
                    target,
                    read_timeout,
                    &reads,
                )
                .await
                .map_err(|error| error.to_string())?;
                verify_committee_witness_at_cutoff(
                    proof_anchor.2,
                    block,
                    &params,
                    &witness,
                    target,
                )
                .map_err(|error| error.to_string())?;
                Ok(PrefetchedCommittee { witness, proof_anchor })
            };
            let outcome = match tokio::time::timeout(COMMITTEE_PREFETCH_TIMEOUT, discovery).await {
                Ok(outcome) => outcome,
                Err(_) => Err("timed out".into()),
            };
            let outcome = outcome.map_err(|error: String| {
                tracing::warn!(
                    parent_anchor = anchor.number,
                    snapshot_block = block,
                    target_epoch = target,
                    failures = failures.saturating_add(1),
                    retry_in = ?prefetch_backoff(failures),
                    %error,
                    "committee witness prefetch failed"
                );
                Instant::now()
            });
            let _ = sender.send(Some(outcome));
        });
        CommitteePrefetch { key, result, progress, failures, task }
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

    /// Verifies a switch witness proven under the committed parent anchor and retains it in
    /// memory for later proposal rounds; no unverified or partially acquired reads enter the
    /// cache.
    #[cfg(test)]
    pub(super) fn cache_committee_witness(
        &self,
        state: &AppState,
        target_epoch: u64,
        witness: &CommitteeWitness,
    ) -> Result<(), Rejection> {
        self.cache_candidate_committee_witness(state, &state.anchor, target_epoch, witness)
    }

    /// Returns a snapshot proof only when both the cutoff and candidate anchor match.
    pub(super) fn cached_candidate_committee_witness(
        &self,
        state: &AppState,
        anchor: &AnchorState,
        target_epoch: u64,
    ) -> Option<CommitteeWitness> {
        let mut key = CacheKey::new(state, &self.params, target_epoch);
        key.proof_anchor = (anchor.number, anchor.hash, anchor.state_root);
        self.committee_cache()
            .as_ref()
            .filter(|cached| cached.key == key)
            .map(|cached| cached.witness.clone())
    }

    /// The witness retained for `state`'s derivation context under any proof anchor. It was
    /// verified only under its own proof root, so it is a basis to re-prove under another root
    /// and is never served as-is.
    pub(super) fn context_committee_witness(
        &self,
        state: &AppState,
        target_epoch: u64,
    ) -> Option<CommitteeWitness> {
        let key = CacheKey::new(state, &self.params, target_epoch);
        self.committee_cache()
            .as_ref()
            .filter(|cached| key.same_context(&cached.key))
            .map(|cached| cached.witness.clone())
    }

    /// Verifies and retains a candidate's proof under its own root and the committed derivation
    /// cutoff.
    pub(super) fn cache_candidate_committee_witness(
        &self,
        state: &AppState,
        anchor: &AnchorState,
        target_epoch: u64,
        witness: &CommitteeWitness,
    ) -> Result<(), Rejection> {
        self.cache_committee_witness_at_root(
            state,
            (anchor.number, anchor.hash, anchor.state_root),
            target_epoch,
            witness,
        )
    }

    /// Verifies and retains a witness in memory under the supplied L1 header identity. Recovery
    /// discovery uses R's root before re-proving the same snapshot under a candidate anchor.
    pub(super) fn cache_committee_witness_at_root(
        &self,
        state: &AppState,
        proof_anchor: (u64, B256, B256),
        target_epoch: u64,
        witness: &CommitteeWitness,
    ) -> Result<(), Rejection> {
        let mut key = CacheKey::new(state, &self.params, target_epoch);
        key.proof_anchor = proof_anchor;

        let mut cache = self.committee_cache();
        if cache.as_ref().is_some_and(|cached| cached.key == key && cached.witness == *witness) {
            return Ok(());
        }
        verify_committee_witness_at_cutoff(
            proof_anchor.2,
            state.anchor.number.max(state.anchor_floor()),
            &self.params,
            witness,
            target_epoch,
        )?;
        *cache = Some(CachedCommittee { key, witness: witness.clone() });
        Ok(())
    }
}
