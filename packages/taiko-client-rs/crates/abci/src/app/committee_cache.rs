//! Independently verified switch witnesses, held in memory only and separate from consensus
//! state, and the one background discovery that acquires them from the own L1; a restart
//! re-discovers them there (SYNC-9-16).

use std::{sync::Arc, time::Duration};

use alloy_primitives::{Address, B256};
use tokio::{sync::watch, task::JoinHandle, time::Instant};

use super::{App, Rejection, validate::snapshot_cutoff};
use crate::{
    committee::{CommitteeError, VerifiedWitness, committee_config_hash},
    config::ChainParams,
    engine::Engine,
    envelope::CommitteeWitness,
    l1::{FetchError, L1Error, L1Source, build_committee_witness_within, header_at},
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

/// Classifies a discovered witness that fails verification. The own L1 served both the proofs,
/// for the registry account and slots the discovery asked for (it already refuses another
/// address or slot), and the state root they are checked against. So a proof that does not
/// verify there is a malformed own-L1 reply, which halts (SYNC-9-7), unlike the same failure in
/// a peer's proposal, which only rejects it. Every other failure keeps its committee reason.
fn own_l1_proof_failure(error: CommitteeError) -> FetchError {
    match error {
        CommitteeError::Mpt(proof) => FetchError::L1(L1Error::MalformedResponse(format!(
            "own L1 registry proof does not verify under its own state root: {proof}"
        ))),
        other => other.into(),
    }
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
    /// The discovery's outcome; `None` while it runs.
    result: watch::Receiver<Outcome>,
    /// The failed attempts for the same context before this one.
    failures: u32,
    /// The owned discovery.
    task: JoinHandle<()>,
}

/// What a background discovery publishes once it ends: the verified witness, or its failure.
type Outcome = Option<Result<PrefetchedCommittee, FailedDiscovery>>;

/// A background discovery that ended without a verified witness.
#[derive(Clone, Debug)]
struct FailedDiscovery {
    /// When it failed; the backoff ([`prefetch_backoff`]) runs from here.
    at: Instant,
    /// Why, in the class a proposal maps it by ([`Rejection::from`]): an own-L1 read error,
    /// which may be malformed data (SYNC-9-7); a read or the whole discovery past its deadline;
    /// an unusable registry word; or a snapshot from which no committee derives or verifies.
    cause: FetchError,
}

/// A background discovery's verified witness and the L1 block its registry proofs verify under.
#[derive(Clone, Debug)]
pub(super) struct PrefetchedCommittee {
    /// The witness, verified under `proof_anchor`'s root at its [`snapshot_block`].
    pub(super) witness: VerifiedWitness,
    /// `(number, hash, stateRoot)` of the block whose root the proofs verify under: the parent
    /// anchor, or R before the first recovered commit ([`snapshot_block`]).
    pub(super) proof_anchor: (u64, B256, B256),
}

/// The L1 block whose registry snapshot the switch witness for `state` takes, and that the
/// discovery reads and proves at: the committed parent anchor (that of `D(t)` at `S(t)`), or the
/// generation origin R while that anchor still precedes it, i.e. their maximum (COMM-4.3-11). A
/// candidate's own anchor never selects it. Registry checkpoints are append-only, so a snapshot
/// proven at its own cutoff stays the same snapshot under every later root. It is the cutoff
/// block validation verifies a witness at ([`snapshot_cutoff`]), computed by that one formula.
pub(super) fn snapshot_block(state: &AppState) -> u64 {
    snapshot_cutoff(&state.chain_context())
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
    /// Complete registry witness, including the snapshot entries, verified under the root of
    /// `key`'s proof anchor at the snapshot block for `key`'s target epoch.
    witness: VerifiedWitness,
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
    /// Makes sure the committee witness of the upcoming switch `S(t)` gets discovered at its
    /// [`snapshot_block`] while that L1 state is recent, whenever the committed anchor may still
    /// be the parent anchor of `S(t)` ([`prefetch_target`]): unless a witness of that context is
    /// held, starts the background discovery (restarting a failed one after its backoff,
    /// [`prefetch_backoff`]), and adopts a finished one by caching the witness it verified in
    /// memory ([`App::cache_committee_witness_at_root`]). The witness is kept across commits while
    /// the committed anchor stays.
    ///
    /// Runs at a live `Commit`, at every `ProcessProposal`, which every node (full nodes
    /// included) handles in each round that delivers a proposal while it is not locked on a block,
    /// empty proposals included, and at every `PrepareProposal`. The live `Commit` of the block
    /// adopting an anchor discovers its witness right away, so an L1 finality stall that keeps
    /// that anchor until `D(t)` (and on until freshness stops proposals) or an outage resumes from
    /// the cached witness even once the L1 node pruned the anchor's state, provided that state
    /// was still served when the discovery ran. Nothing survives a restart: the restarted node
    /// discovers the witness again from its own L1, which must then still serve that state
    /// (SYNC-9-16). A replayed `Commit` only adopts a finished discovery
    /// ([`App::adopt_committee_prefetch`]). This discovery is the only one: a proposal that needs
    /// the witness joins it ([`App::discovered_committee_witness`]).
    pub(super) fn prefetch_committee_witness(&self, state: &AppState) {
        self.refresh_committee_prefetch(state, true);
    }

    /// [`App::prefetch_committee_witness`] without starting a discovery: adopts a finished one,
    /// and drops a witness or discovery the cache or the committed state made obsolete.
    pub(super) fn adopt_committee_prefetch(&self, state: &AppState) {
        self.refresh_committee_prefetch(state, false);
    }

    /// Adopts, drops or (when `start`) starts the switch-witness prefetch for `state`
    /// ([`App::committee_discovery`]).
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
        let finished =
            self.committee_discovery(key, state, target, start).and_then(|o| o.borrow().clone());
        if let Some(Ok(found)) = finished {
            match self.cache_committee_witness_at_root(
                state,
                found.proof_anchor,
                target,
                &found.witness,
            ) {
                Ok(()) => *self.committee_prefetch() = None,
                Err(error) => tracing::warn!(%error, "prefetched committee witness not retained"),
            }
        }
    }

    /// The outcome of the background discovery of `target`'s witness for `state` (`key` its
    /// context), if one is held. A discovery for another context, which the committed state
    /// left (another snapshot block or target), is dropped and so aborted first. When `start`, a
    /// missing discovery is started and a failed one restarted, from scratch, once its backoff
    /// has passed; a running one is never restarted.
    fn committee_discovery(
        &self,
        key: CacheKey,
        state: &AppState,
        target: u64,
        start: bool,
    ) -> Option<watch::Receiver<Outcome>> {
        let mut slot = self.committee_prefetch();
        if slot.as_ref().is_some_and(|discovery| discovery.key != key) {
            *slot = None;
        }
        let restart = match slot.as_ref() {
            None => Some(0),
            Some(discovery) => match &*discovery.result.borrow() {
                Some(Err(failed))
                    if failed.at.elapsed() >= prefetch_backoff(discovery.failures) =>
                {
                    Some(discovery.failures.saturating_add(1))
                }
                _ => None,
            },
        };
        if start && let Some(failures) = restart {
            *slot = Some(self.spawn_committee_prefetch(key, state, target, failures));
        }
        slot.as_ref().map(|discovery| discovery.result.clone())
    }

    /// The switch witness of `target` for `state` from the background discovery at
    /// [`snapshot_block`]: starts it when none is held for this context (restarting a failed one
    /// whose backoff has passed), or joins the running one, and waits for it. The wait holds no
    /// lock and is bounded only by the caller's deadline (`PrepareProposal`'s); the discovery
    /// goes on past it, so a later round finds it further along or done instead of starting over.
    ///
    /// A failed discovery answers with the rejection of its cause ([`Rejection::from`] its
    /// [`FetchError`]), in the round that sees it end and in every round of its backoff alike.
    /// An own L1 that is unreachable, lags, fails a read or times out leaves the witness
    /// unavailable: a liveness pause (RECOV-8-4, RECOV-8-5). Malformed or contradictory replies
    /// from it ([`L1Error::is_integrity_failure`](crate::l1::L1Error::is_integrity_failure)) halt
    /// the node for safety instead (SYNC-9-7), and the backoff never turns that into a pause.
    pub(super) async fn discovered_committee_witness(
        &self,
        state: &AppState,
        target: u64,
    ) -> Result<PrefetchedCommittee, Rejection> {
        let key = CacheKey::new(state, &self.params, target);
        let mut outcome = self
            .committee_discovery(key, state, target, true)
            .expect("a missing discovery was just started");
        loop {
            let finished = outcome.borrow_and_update().clone();
            if let Some(finished) = finished {
                return finished.map_err(|failed| failed.cause.into());
            }
            if outcome.changed().await.is_err() {
                return Err(Rejection::Registry(
                    "the switch witness discovery stopped without a result".into(),
                ));
            }
        }
    }

    /// Waits for the running or finished prefetch of `target`'s witness under `state`, if any,
    /// without starting one. `None` when there is none or it failed.
    #[cfg(test)]
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
    /// [`COMMITTEE_PREFETCH_TIMEOUT`], after `failures` failed attempts for the same context. The
    /// task owns everything it reads with (the L1 handle, the parameters and the anchor), so it
    /// takes no lock of the app and runs on whatever request the app handles meanwhile.
    ///
    /// At R the header comes from the own L1 like every other discovery read; a proposal still
    /// re-proves the witness under its own anchor, and every validator verifies it there.
    fn spawn_committee_prefetch(
        &self,
        key: CacheKey,
        state: &AppState,
        target: u64,
        failures: u32,
    ) -> CommitteePrefetch {
        let (l1, params, anchor) =
            (Arc::clone(&self.l1), self.params.clone(), state.anchor.clone());
        let block = snapshot_block(state);
        let read_timeout = self.opts.l1_timeout;
        let (sender, result) = watch::channel(None);
        let task = tokio::spawn(async move {
            let discovery = async {
                let proof_anchor = if block == anchor.number {
                    (anchor.number, anchor.hash, anchor.state_root)
                } else {
                    let header = tokio::time::timeout(read_timeout, header_at(&*l1, block))
                        .await
                        .map_err(|_| FetchError::Timeout("registry header read"))??;
                    (header.number(), header.hash(), header.state_root())
                };
                let witness =
                    build_committee_witness_within(&*l1, &params, block, target, read_timeout)
                        .await?;
                let witness =
                    VerifiedWitness::verify(proof_anchor.2, block, &params, witness, target)
                        .map_err(own_l1_proof_failure)?;
                Ok::<_, FetchError>(PrefetchedCommittee { witness, proof_anchor })
            };
            let outcome = match tokio::time::timeout(COMMITTEE_PREFETCH_TIMEOUT, discovery).await {
                Ok(outcome) => outcome,
                Err(_) => Err(FetchError::Timeout("switch witness discovery")),
            };
            let outcome = outcome.map_err(|cause| {
                tracing::warn!(
                    parent_anchor = anchor.number,
                    snapshot_block = block,
                    target_epoch = target,
                    failures = failures.saturating_add(1),
                    retry_in = ?prefetch_backoff(failures),
                    error = %cause,
                    "committee witness prefetch failed"
                );
                FailedDiscovery { at: Instant::now(), cause }
            });
            let _ = sender.send(Some(outcome));
        });
        CommitteePrefetch { key, result, failures, task }
    }

    /// Returns a previously verified witness only for the same complete authenticated context.
    #[cfg(test)]
    pub(super) fn cached_committee_witness(
        &self,
        state: &AppState,
        target_epoch: u64,
    ) -> Option<CommitteeWitness> {
        let key = CacheKey::new(state, &self.params, target_epoch);
        self.committee_cache()
            .as_ref()
            .and_then(|cached| (cached.key == key).then(|| cached.witness.witness().clone()))
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
        let anchor = &state.anchor;
        let verified = VerifiedWitness::verify(
            anchor.state_root,
            snapshot_block(state),
            &self.params,
            witness.clone(),
            target_epoch,
        )?;
        self.cache_candidate_committee_witness(state, anchor, target_epoch, &verified)
    }

    /// Returns a verified snapshot proof only when both the cutoff and candidate anchor match.
    pub(super) fn cached_candidate_committee_witness(
        &self,
        state: &AppState,
        anchor: &AnchorState,
        target_epoch: u64,
    ) -> Option<VerifiedWitness> {
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
            .map(|cached| cached.witness.witness().clone())
    }

    /// Retains a candidate's proof verified under its own root and the committed derivation
    /// cutoff.
    pub(super) fn cache_candidate_committee_witness(
        &self,
        state: &AppState,
        anchor: &AnchorState,
        target_epoch: u64,
        witness: &VerifiedWitness,
    ) -> Result<(), Rejection> {
        self.cache_committee_witness_at_root(
            state,
            (anchor.number, anchor.hash, anchor.state_root),
            target_epoch,
            witness,
        )
    }

    /// Retains in memory a witness verified at `state`'s [`snapshot_block`] under the root of the
    /// supplied L1 header identity for `target_epoch`; one verified for any other context is
    /// refused, never verified again. The background discovery's witness is retained under its
    /// snapshot block's root, a candidate's under the candidate anchor's.
    pub(super) fn cache_committee_witness_at_root(
        &self,
        state: &AppState,
        proof_anchor: (u64, B256, B256),
        target_epoch: u64,
        witness: &VerifiedWitness,
    ) -> Result<(), Rejection> {
        let (root, cutoff) = (proof_anchor.2, snapshot_block(state));
        if !witness.verified_under(root, cutoff, target_epoch) {
            return Err(CommitteeError::NotVerifiedUnder { root, cutoff, target_epoch }.into());
        }
        let mut key = CacheKey::new(state, &self.params, target_epoch);
        key.proof_anchor = proof_anchor;

        let mut cache = self.committee_cache();
        if cache.as_ref().is_some_and(|cached| cached.key == key && cached.witness == *witness) {
            return Ok(());
        }
        *cache = Some(CachedCommittee { key, witness: witness.clone() });
        Ok(())
    }

    /// Drops the retained `witness` of `state`'s derivation context once its snapshot failed
    /// under an authenticated candidate root: it is then no basis for a re-proof, and while it is
    /// held the prefetch would leave the discovery that replaces it cancelled.
    pub(super) fn forget_committee_witness(
        &self,
        state: &AppState,
        target_epoch: u64,
        witness: &CommitteeWitness,
    ) {
        let key = CacheKey::new(state, &self.params, target_epoch);
        let mut cache = self.committee_cache();
        if cache.as_ref().is_some_and(|cached| {
            key.same_context(&cached.key) && cached.witness.witness() == witness
        }) {
            *cache = None;
        }
    }
}
