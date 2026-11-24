//! `FinalizeBlock` and `Commit`.
//!
//! `FinalizeBlock` is deterministic: it judges a decided block on its envelope, the committed
//! [`AppState`] and the EL, never a beacon (every L1 fact a block consumes travels in the block,
//! the forced transaction bytes included), so a node replaying after a crash or block-syncing
//! derives the same response and state as one that voted. For a block this node never judged
//! whose envelope moves the anchor, its own L1 must have finalized that very header
//! ([`App::confirm_anchor`]), so a block-synced history cannot carry a forged L1 header and with
//! it a forged Inbox checkpoint, and that anchor's `lastCheckpoint` must name a block of the
//! local chain ([`App::confirm_checkpoint`]). A decided block that fails a deterministic check,
//! whose anchor is off the own L1 chain or settles another history, that the EL rejects, or whose
//! `next_validators_hash` contradicts the validator-state replica is a safety halt: the process
//! exits and an operator must investigate.
//!
//! Once the block has executed and is the EL's head, its post-state and anchor decide the set
//! that signs two heights later ([`App::decide_signers`]): the staking words are read at the
//! block's own hash, and the fallback key list comes from the committed state or from those
//! `ProcessProposal` fetched for the height ([`App::prefetch_fallback_keys`]); only a block
//! this node did not judge, or whose list it could not keep, takes it from its own L1 here,
//! under the hash the anchor proves. The response returns the updates that turn the set
//! signing the next height into the set the block decided. The derived state keeps the lists
//! the next decisions can need ([`kept_fallback_keys`]) and stays pending until `Commit`
//! persists it.

use crate::wire::{request, response};
use std::{collections::BTreeMap, fmt, future::Future, time::Duration};

use alloy_primitives::{B256, Bytes, U256};
use etna_core::staking::StakingWords;
use tendermint::{
    abci::{Code, types::ExecTxResult},
    block::Height,
    vote::Power,
};

use tokio::time::Instant;

use super::{
    AbciError, App, FINALIZE_RETRY_ESCALATE, FINALIZE_RETRY_INITIAL, FINALIZE_RETRY_MAX, app_hash,
    deadline, unix_secs,
    validate::{Rejection, Validated, validate_block},
};
use crate::{
    committee::{self, SignerSet, SignerSource},
    engine::{Engine, EngineError, PayloadVerdict, staking::staking_words},
    envelope::{EtnaEnvelope, single_envelope},
    fallback::{FallbackKeys, fetch_fallback_keys},
    l1::{L1Source, OwnFinality, RawL1Header, ReadBounded, own_finality},
    metrics::AbciMetrics,
    store::{AppState, SEGMENT_HEIGHTS, SignerStatus, Signers},
    types::{AnchorState, ParentInfo},
};

impl<L: L1Source, E: Engine> App<L, E> {
    /// Authenticates a decided envelope against the committed context and settles its payload.
    ///
    /// The `ProcessProposal` ACCEPT verdict cached under the decided Comet block hash is taken as
    /// it is, a live decision: the hash binds every input that verdict was judged on to the same
    /// committed state (see [`Verdicts`](super::Verdicts)). Without one (crash replay, block sync,
    /// an evicted verdict) the block is validated cold ([`App::validate_cold`]). The candidate
    /// executes through `newPayload` and becomes the forkchoice head; singleton evidence never
    /// becomes the head. Then, and only then, the block's post-state and anchor decide the set
    /// that signs `height + 2` ([`App::decide_signers`]), whose difference to the replica's next
    /// set the response returns; the replica advances with exactly those updates. State stays
    /// pending until `Commit`. Invalid decisions halt; temporary EL and L1 failures retry.
    ///
    /// An imported store's first request may be this one rather than `Info`: its startup
    /// reconciliation, with the execution floor check, then runs first
    /// ([`App::reconcile_el_once`]), so no block is judged or executed over an unchecked floor.
    pub(super) async fn finalize_block(
        &mut self,
        req: request::FinalizeBlock,
    ) -> Result<response::FinalizeBlock, AbciError> {
        let _timer = AbciMetrics::finalize_seconds().start_timer();
        let height = req.height.value();
        if self.state.as_ref().is_some_and(|state| state.execution_floor.is_some()) {
            self.reconcile_el_once("FinalizeBlock reconciliation").await?;
        }
        let Some(state) = &self.state else {
            return Err(AbciError::Uninitialized("FinalizeBlock"));
        };
        // At h the decided header commits the set signing h+1, before this response's
        // updates take effect at h+2. Its hash checks keys/powers, not proposer priorities.
        let next_validators_hash = state
            .val_state
            .next
            .validators_hash()
            .map_err(|error| safety_halt(height, "next_validators_hash", error))?;
        if req.next_validators_hash.as_bytes() != next_validators_hash.as_slice() {
            return Err(AbciError::SafetyHalt(format!(
                "height {height}: next_validators_hash contradicts the validator-state replica"
            )));
        }
        let (validated, cold) = match self.verdicts.remove(&req.hash) {
            Some(verdict) => (verdict, false),
            None => (self.validate_cold(state, &req, height).await?, true),
        };
        let mut next = next_state(state, &validated, height);
        next.last_comet_hash = match req.hash {
            tendermint::Hash::Sha256(hash) => B256::from(hash),
            tendermint::Hash::None => {
                return Err(AbciError::SafetyHalt("decided Comet hash is absent".into()))
            }
        };

        let hash = next.parent.hash;
        self.check_trust_candidate(height, hash, next.last_comet_hash)?;
        let finalized = next.anchor.inbox.last_checkpoint_hash;
        self.settle(height, &validated, finalized).await?;
        self.store.save_execution_block(&validated.block)?;

        // The block is the EL's head now: its post-state and anchor decide the set that signs
        // height + 2, and the response returns how it differs from the set that signs
        // height + 1, the replica's next set, as stock CometBFT applies the updates at
        // height + 2. CometBFT applies exactly the updates this response returns; a change set
        // it would refuse halts it, so the replica halts first.
        let (signers, decided, anchored) = self.decide_signers(&next, height).await?;
        next.fallback_keys = kept_fallback_keys(&next, anchored);
        let updates =
            committee::validator_updates(&state.val_state.next.members(), &signers.members);
        next.val_state = state
            .val_state
            .advance(&updates)
            .map_err(|error| safety_halt(height, "validator_state", error))?;
        next.signers = Signers { next: state.signers.after, after: decided };
        let validator_updates = updates
            .iter()
            .map(|&update| validator_update(height, update))
            .collect::<Result<Vec<_>, _>>()?;

        tracing::debug!(
            height,
            %hash,
            anchor = next.anchor.number,
            forced = ?validated.forced,
            cold,
            source = ?signers.source,
            validator_updates = validator_updates.len(),
            "block finalized"
        );
        // appHash(height): its EL hash and the validator state after it, this response's
        // updates applied (CONS-3.1-8).
        let app_hash = app_hash(&next);
        self.pending = Some(next);
        self.pending_val_updates = updates;
        Ok(response::FinalizeBlock {
            events: vec![],
            tx_results: vec![ExecTxResult { code: Code::Ok, ..Default::default() }],
            validator_updates,
            consensus_param_updates: None,
            app_hash,
        })
    }

    /// Validates the decided block of `req` at `height` on the committed `state` without a
    /// `ProcessProposal` verdict, as SYNC-9-1 requires of a block this node did not judge live:
    /// [`validate_block`] (waiting while this node lacks the block's ruleset), a moved anchor's
    /// own-L1 finality ([`App::confirm_anchor`]) and checkpoint ancestry
    /// ([`App::confirm_checkpoint`]), then the forced decision ([`App::confirm_forced`]).
    /// Transactions that are not exactly one envelope wait while their anchor header is not yet
    /// final or supported (RECOV-8-6). A failed check is a safety halt.
    async fn validate_cold(
        &self,
        state: &AppState,
        req: &request::FinalizeBlock,
        height: u64,
    ) -> Result<Validated, AbciError> {
        let bft_secs = unix_secs(req.time);
        let txs: Vec<Bytes> = req.txs.iter().cloned().map(Bytes::from).collect();
        let env = match single_envelope(&txs) {
            Ok(env) => env,
            Err(error) => {
                loop {
                    match self.check_header_format(&txs).await {
                        Ok(()) => break,
                        Err(reason) if reason.requires_dependency_repair() => {
                            return Err(AbciError::SafetyHalt(reason.to_string()));
                        }
                        Err(reason) => {
                            tracing::warn!(height, %reason, "waiting for L1 finality or header support");
                            tokio::time::sleep(FINALIZE_RETRY_MAX).await;
                        }
                    }
                }
                return Err(invalid_block(height, &Rejection::from(error)));
            }
        };
        let mut validated = loop {
            match validate_block(
                &state.chain_context(),
                &self.params,
                &env,
                height,
                bft_secs,
                req.proposer_address,
            ) {
                Ok(validated) => break validated,
                Err(Rejection::Rule(crate::rules::RuleViolation::UnsupportedRuleset { rules })) => {
                    self.confirm_unsupported_rules(state, height, bft_secs, &env).await?;
                    tracing::warn!(height, rules, "waiting for ruleset support; upgrade the node");
                    tokio::time::sleep(FINALIZE_RETRY_MAX).await;
                }
                Err(error) => return Err(invalid_block(height, &error)),
            }
        };
        if let Some(witness) = &env.anchor {
            self.confirm_anchor(height, &witness.l1_header).await?;
            self.confirm_checkpoint(state, height, &validated.anchor).await?;
        }
        validated.forced = self.confirm_forced(state, height, &validated).await?;
        Ok(validated)
    }

    /// The set that signs `height + 2`, decided once the block at `height` is the EL's head,
    /// where it comes from, and the fallback key list whose hash the block's anchor proves, when
    /// this node holds it or had to fetch it.
    ///
    /// The candidate is the snapshot the block's block-start call stored, read from the
    /// block's post-state at its hash ([`App::decided_staking_words`]); it signs when it is
    /// usable under the minimum total stake the block's anchor proves
    /// ([`committee::candidate_members`]). Otherwise the fallback key list whose hash that anchor
    /// proves signs, each key at power 1: the one `next`, the state after the block, holds under
    /// that hash, else one a proposal of this height fetched
    /// ([`App::prefetched_fallback_keys`]), else the one the own L1 serves for it
    /// ([`App::decided_fallback_keys`]), which only a usable candidate spares. The words serve
    /// this decision alone: the empty records of a read that skipped them are never kept or
    /// shown as a seat table. The decided set is recorded with the candidate's stored total stake
    /// and the minimum it was held to, a usable candidate by its snapshot height, the fallback
    /// keys by their list's hash and the condition the candidate failed.
    async fn decide_signers(
        &self,
        next: &AppState,
        height: u64,
    ) -> Result<(SignerSet, SignerStatus, Option<FallbackKeys>), AbciError> {
        let facts = &next.anchor.inbox;
        let (hash, min_total_stake) = (facts.fallback_keys_hash, facts.min_total_stake);
        let held =
            next.fallback_keys.get(&hash).cloned().or_else(|| self.prefetched_fallback_keys(hash));
        let words = self.decided_staking_words(next.parent.hash, height, min_total_stake).await?;
        let cause = match committee::candidate_members(height, &words, min_total_stake) {
            Ok(members) => {
                let decided = SignerStatus::candidate(
                    height,
                    words.total_stake,
                    min_total_stake,
                    members.len(),
                );
                return Ok((SignerSet { source: SignerSource::Candidate, members }, decided, held));
            }
            Err(cause) => cause,
        };
        let keys = match held {
            Some(keys) => keys,
            None => self.decided_fallback_keys(height, &next.anchor).await,
        };
        Ok((
            SignerSet { source: SignerSource::Fallback, members: keys.validator_set() },
            SignerStatus::fallback(&keys, cause, words.total_stake, min_total_stake),
            Some(keys),
        ))
    }

    /// The candidate snapshot in the post-state of the block `hash` at `height`, whose anchor
    /// proves the minimum total stake `min_total_stake` ([`staking_words`]), read at that hash
    /// within the engine deadline, so a replay reads the same words wherever the EL head has
    /// moved. A retryable engine error or an elapsed deadline waits with the [`Backoff`]
    /// schedule, logging the failure; it never stands for a snapshot. Any other engine error,
    /// such as a malformed reply, is a safety halt.
    async fn decided_staking_words(
        &self,
        hash: B256,
        height: u64,
        min_total_stake: U256,
    ) -> Result<StakingWords, AbciError> {
        let limit = self.opts.engine_timeout;
        let mut backoff = Backoff::new(DECIDED_BLOCK, height);
        loop {
            let read =
                staking_words(self.engine(), self.params.staking, hash, height, min_total_stake);
            let reason = match tokio::time::timeout(limit, read).await {
                Ok(Ok(words)) => return Ok(words),
                Ok(Err(error)) if error.is_retryable() => error.to_string(),
                Ok(Err(error)) => {
                    return Err(safety_halt(
                        height,
                        "staking_words",
                        format!("the staking snapshot of block {hash} cannot be read: {error}"),
                    ));
                }
                Err(_) => format!("timed out after {limit:?}"),
            };
            backoff.wait(STAKING_WORD_READ, &reason).await;
        }
    }

    /// The fallback key list whose hash `anchor`, the anchor of the block at `height`, proves,
    /// from the own L1 ([`fetch_fallback_keys`]): `getFallbackKeys()` at the anchor's hash, else
    /// the Inbox's logs scanned down from the anchor, each L1 read within
    /// [`AppOptions::list_read_timeout`](super::AppOptions::list_read_timeout) and the scan as a
    /// whole unbounded. While the list cannot be obtained, for want of a matching list or
    /// through any L1 error, the block waits with the [`Backoff`] schedule, logging why: a
    /// node-local fault, never a halt and never another set.
    async fn decided_fallback_keys(&self, height: u64, anchor: &AnchorState) -> FallbackKeys {
        let hash = anchor.inbox.fallback_keys_hash;
        let l1 = ReadBounded { l1: self.l1.clone(), limit: self.opts.list_read_timeout() };
        let mut backoff = Backoff::new(DECIDED_BLOCK, height);
        loop {
            match fetch_fallback_keys(&l1, self.params.inbox, hash, anchor.hash, anchor.number, 0)
                .await
            {
                Ok(keys) => return keys,
                Err(error) => {
                    let reason = format!("fallback key list {hash}: {error}");
                    backoff.wait(FALLBACK_KEYS_FETCH, &reason).await;
                }
            }
        }
    }

    /// Authenticates the fixed-core facts before waiting for software support. A proof under
    /// a fabricated L1 header or a conflicting checkpoint is a safety halt, even when that
    /// header claims a newer ruleset. The core timestamp and freshness rules remain checkable.
    async fn confirm_unsupported_rules(
        &self,
        state: &AppState,
        height: u64,
        bft_secs: u64,
        env: &EtnaEnvelope,
    ) -> Result<(), AbciError> {
        let anchor = if let Some(witness) = &env.anchor {
            self.confirm_anchor(height, &witness.l1_header).await?;
            let anchor = crate::l1::verify_anchor_witness(witness, self.params.inbox)
                .map_err(|e| invalid_block(height, &Rejection::Witness(e)))?;
            self.confirm_checkpoint(state, height, &anchor).await?;
            anchor
        } else {
            state.anchor.clone()
        };
        let timestamp =
            crate::rules::block_timestamp(state.parent.timestamp, bft_secs, anchor.timestamp);
        if env.block.header.timestamp != timestamp {
            return Err(invalid_block(
                height,
                &Rejection::Rule(crate::rules::RuleViolation::header_field(
                    "timestamp",
                    &timestamp,
                    &env.block.header.timestamp,
                )),
            ));
        }
        crate::rules::check_anchor_freshness(
            timestamp,
            anchor.timestamp,
            state.genesis.max_anchor_age,
        )
        .map_err(|e| invalid_block(height, &Rejection::Rule(e)))
    }

    /// Handles `Commit`: persists the state the last `FinalizeBlock` derived and makes it the
    /// committed state. Retires owned execution repair and returns any delivered failure before
    /// writing a new committed record or state.
    ///
    /// Clears the `ProcessProposal` cache, the proposal reads (but for the entry at the committed
    /// cursor, whose authenticated bytes remain reusable) and the halt reason, publishes the new
    /// head's gauges, and answers `retain_height = 0` (no block pruning).
    ///
    /// Before the state, in the same barrier, every height saves its Comet block ID
    /// and the validator updates `FinalizeBlock` returned, an empty list included, and a height
    /// divisible by [`SEGMENT_HEIGHTS`] also the full validator state, as immutable checksummed
    /// records (a corrupt record is superseded; a valid one holding something else fails the
    /// Commit). When the new state raises [`AppState::comet_history_floor`], the committed
    /// anchor's checkpoint s, the records below it are deleted after the state is durable, a
    /// segment at a time: the Comet block IDs and execution blocks below s, and the validator
    /// records below the newest snapshot under s, the base the state at s − 1 (the preimage an
    /// import package at s carries, 5.4) and later ones are recomputed from
    /// ([`Store::prune_val_records`](crate::store::Store::prune_val_records)). A failed deletion
    /// only logs, and the next raise retries it.
    /// Errors: [`AbciError::NothingToCommit`] without a pending state; [`AbciError::Store`]
    /// when it cannot be persisted (it then stays pending).
    pub(super) fn commit(&mut self) -> Result<response::Commit, AbciError> {
        self.clear_execution_repair().map_err(|error| {
            if !matches!(error, AbciError::SafetyHalt(_) | AbciError::Store(_)) &&
                super::classify(&error) == super::ErrorClass::Contradiction
            {
                super::contradiction_halt(error)
            } else {
                error
            }
        })?;
        let pending = self.pending.as_ref().ok_or(AbciError::NothingToCommit)?;
        self.store.save_comet_hash(pending.last_height, pending.last_comet_hash)?;
        if pending.last_height % SEGMENT_HEIGHTS == 0 {
            self.store.save_val_state(&pending.val_state)?;
        }
        self.store.save_val_updates(pending.last_height, &self.pending_val_updates)?;
        self.store.save(pending)?;
        let floor = pending.comet_history_floor();
        if self.state.as_ref().is_none_or(|state| state.comet_history_floor() < floor) {
            if let Err(error) = self.store.prune_comet_hashes(floor) {
                tracing::warn!(%error, floor, "could not prune committed Comet history");
            }
            if let Err(error) = self.store.prune_val_records(floor) {
                tracing::warn!(%error, floor, "could not prune committed validator records");
            }
            if let Err(error) = self.store.prune_execution_blocks(floor) {
                tracing::warn!(%error, floor, "could not prune committed execution blocks");
            }
        }
        let report = super::AppHashReport::of(pending);
        tracing::info!(
            height = report.height,
            hash = %report.el_hash,
            app_hash = %report.app_hash,
            val_state_hash = %report.val_state_hash,
            "block committed"
        );
        self.state = self.pending.take();
        self.pending_val_updates.clear();
        self.verdicts.clear();
        let state = self.state.as_ref().expect("just committed");
        self.prepare_next_height(state);
        self.clear_halt();
        self.publish_state_metrics();
        let state = self.state.as_ref().expect("committed state");
        self.trust.committed(state);
        // The committed anchor's checkpoint is authenticated in the own finalized L1 view: one
        // above the last matched checkpoint is pending until compared (SYNC-9-6a).
        self.observe_anchor_checkpoint(&state.anchor);
        Ok(response::Commit { data: Default::default(), retain_height: Height::from(0u32) })
    }

    /// Makes the EL execute the decided block of `v` at `height` (unless `v.executed`: the
    /// `ProcessProposal` verdict already did) and adopt it as head with the historical anchor's
    /// `finalized` fence. Safe equals head only for a ready trust session, otherwise unknown.
    /// It retries for as long as it takes: `FinalizeBlock` must not answer before the EL holds
    /// the block.
    ///
    /// Each call runs within the engine deadline ([`App::el_call`]). `SYNCING`/`ACCEPTED`, a
    /// retryable engine error ([`EngineError::is_retryable`]: a transport failure, an internal,
    /// server-range or unknown JSON-RPC error code) and an elapsed deadline are retried on one
    /// [`Backoff`] for the block. A forkchoice update answering `SYNCING` means the EL does not
    /// hold the block (e.g. it restarted since executing it), so the payload is re-sent before
    /// the next forkchoice attempt. A payload answered `SYNCING` means the EL lacks the block's
    /// ancestry (e.g. it lost its tail), which it only backfills once a forkchoice update points
    /// it at a head, so the block is sent as head right away (with trust-aware safe and the
    /// historical `finalized` fence) before
    /// the payload is retried; a `VALID` answer to that nudge settles the block, and a nudge that
    /// fails (a retryable error, its deadline) is logged with its own error. `INVALID` and
    /// every other engine error (an Engine API error code, a malformed call, a reply of the
    /// wrong shape) are the EL's deterministic answer: [`AbciError::SafetyHalt`].
    async fn settle(&self, height: u64, v: &Validated, finalized: B256) -> Result<(), AbciError> {
        let hash = v.block.header.hash_slow();
        let mut executed = v.executed;
        let mut backoff = Backoff::new(DECIDED_BLOCK, height);
        loop {
            let (method, reason) = if executed {
                let method = FCU;
                match self
                    .el_call(
                        height,
                        method,
                        self.engine.forkchoice(hash, self.trusted_safe(hash), finalized),
                    )
                    .await?
                {
                    Settled::Valid => return Ok(()),
                    Settled::Syncing => {
                        executed = false;
                        (method, "the execution engine lacks the block; re-sending it".to_string())
                    }
                    Settled::Retry(reason) => (method, reason),
                }
            } else {
                let method = "engine_newPayload";
                match self.el_call(height, method, self.engine.new_payload(&v.block)).await? {
                    Settled::Valid => {
                        executed = true;
                        continue;
                    }
                    Settled::Syncing => {
                        // An EL can lose the already committed suffix after ProcessProposal's
                        // ACCEPT. Re-feed that auxiliary archive before retrying the decided
                        // payload; older stores without it retain their peer-sync path.
                        if let Some(state) = &self.state &&
                            matches!(
                                self.store.load_execution_block(state.last_height)?,
                                crate::store::Record::Valid(_)
                            )
                        {
                            self.nudge_committed_head(height, state).await?;
                        }
                        let nudge =
                            self.engine.forkchoice(hash, self.trusted_safe(hash), finalized);
                        let reason = match self.el_call(height, FCU, nudge).await? {
                            Settled::Valid => return Ok(()),
                            Settled::Syncing => {
                                "the execution engine is syncing; pointed it at the block".into()
                            }
                            Settled::Retry(error) => format!(
                                "the execution engine is syncing; pointing it at the block failed: \
                                 {error}"
                            ),
                        };
                        (method, reason)
                    }
                    Settled::Retry(reason) => (method, reason),
                }
            };
            backoff.wait(method, &reason).await;
        }
    }

    /// Closed startup sessions never label an untrusted candidate safe. Zero means unknown;
    /// the historical anchor-derived finalized ancestry fence is passed independently.
    fn trusted_safe(&self, hash: B256) -> B256 {
        if self.trust.snapshot().is_ready() { hash } else { B256::ZERO }
    }

    /// Confirms, for the decided block at `height` this node never judged, that its anchor
    /// `header` is final and canonical in the own L1 view, the check `ProcessProposal` makes: the
    /// own L1 must have finalized the header's number and hold this very header there.
    ///
    /// While the own L1 is unreachable or has not finalized that far, the block waits with the
    /// [`Backoff`] schedule and is neither finalized nor halted on. [`Rejection::AnchorOffChain`],
    /// a safety halt, needs consecutive off-chain reads spanning at least five seconds (so a
    /// briefly stale or sticky backend is given time to recover) showing the header cannot be on
    /// the own L1 chain: a different own-L1 block at its number, or a number beyond the own
    /// finalized block with a timestamp no block there can have ([`App::read_anchor`]). The node
    /// is then being fed a history whose L1 facts its own L1 does not have.
    pub(super) async fn confirm_anchor(
        &self,
        height: u64,
        header: &RawL1Header,
    ) -> Result<(), AbciError> {
        let (number, hash) = (header.number(), header.hash());
        let off_chain = |detail: String| {
            invalid_block(height, &Rejection::AnchorOffChain { number, hash, detail })
        };
        let mut backoff = Backoff::new(DECIDED_BLOCK, height);
        let mut suspect_since = None;
        loop {
            let reason = match self.read_anchor(header).await {
                AnchorRead::Confirmed => return Ok(()),
                AnchorRead::Integrity(reason) => return Err(AbciError::SafetyHalt(reason)),
                AnchorRead::OffChain(detail) => {
                    let since = suspect_since.get_or_insert_with(Instant::now);
                    if since.elapsed() >= ANCHOR_OFF_CHAIN_WINDOW {
                        return Err(off_chain(detail));
                    }
                    format!("re-reading before a safety halt: {detail}")
                }
                AnchorRead::Pending(reason) => {
                    suspect_since = None;
                    reason
                }
            };
            backoff.wait("L1 anchor confirmation", &reason).await;
        }
    }

    /// Confirms, for the decided block at `height` this node never judged, that its anchor's
    /// proven `lastCheckpoint` names a block of the local chain, the check `ProcessProposal`
    /// makes ([`App::check_anchor_checkpoint`]).
    ///
    /// A conflict is a safety halt: the decided history's L1 facts settle another chain. While the
    /// EL lacks the block at that height, is unreachable or answers a retryable error, the block
    /// waits with the [`Backoff`] schedule; a malformed EL answer or any other engine error halts.
    /// An EL that lacks the block (e.g. it lost its tail below the checkpoint) only backfills once
    /// a forkchoice update names a head, which `settle` would send only after this check, so each
    /// wait for a missing block first points the EL at the committed parent
    /// ([`App::nudge_committed_head`]).
    async fn confirm_checkpoint(
        &self,
        state: &AppState,
        height: u64,
        anchor: &crate::types::AnchorState,
    ) -> Result<(), AbciError> {
        let mut backoff = Backoff::new(DECIDED_BLOCK, height);
        loop {
            let reason = match self.check_anchor_checkpoint(state, anchor).await {
                Ok(()) => return Ok(()),
                Err(conflict) if conflict.is_checkpoint_conflict() => {
                    return Err(invalid_block(height, &conflict));
                }
                Err(missing @ Rejection::LocalBlockMissing(_)) => {
                    let nudge = self.nudge_committed_head(height, state).await?;
                    format!("{missing}; {nudge}")
                }
                Err(wait) if wait.retryable_dependency() && !wait.requires_dependency_repair() => {
                    wait.to_string()
                }
                Err(error) => {
                    return Err(safety_halt(
                        height,
                        error.label(),
                        format!("checkpoint ancestry check failed: {error}"),
                    ));
                }
            };
            backoff.wait("checkpoint ancestry", &reason).await;
        }
    }

    /// Points the EL at the committed parent with unknown safe and finalized, the sync nudge the
    /// trust session sends for a missing committed head, and describes the answer. Whatever it
    /// answers, the caller re-reads the local chain on its next attempt. `INVALID` and a
    /// non-retryable engine error halt ([`App::el_call`]); a retryable failure or an elapsed
    /// deadline is part of the description.
    pub(super) async fn nudge_committed_head(
        &self,
        height: u64,
        state: &AppState,
    ) -> Result<String, AbciError> {
        match self.restore_committed_execution(state).await {
            Ok(_) => {}
            Err(error) if super::classify(&error) == super::ErrorClass::MissingData => {
                tracing::warn!(height, %error, "committed execution recovery waiting for EL");
            }
            Err(error) if super::classify(&error) == super::ErrorClass::Contradiction => {
                return Err(super::contradiction_halt(error));
            }
            Err(error) => return Err(error),
        }
        self.point_committed_head(height, state).await
    }

    /// Sends only the trusted committed-head FCU after synchronous or owned payload repair.
    /// Prepare waiters call this themselves so no background task can race a later decided head.
    pub(super) async fn point_committed_head(
        &self,
        height: u64,
        state: &AppState,
    ) -> Result<String, AbciError> {
        let nudge = self.engine.forkchoice(state.parent.hash, B256::ZERO, B256::ZERO);
        Ok(match self.el_call(height, FCU, nudge).await? {
            Settled::Valid => "pointed the execution engine at the committed head".into(),
            Settled::Syncing => {
                "the execution engine is syncing to the committed head it was pointed at".into()
            }
            Settled::Retry(error) => {
                format!("pointing the execution engine at the committed head failed: {error}")
            }
        })
    }

    /// One read of the own L1 about the anchor `header`, which must be final. Above the own
    /// finalized block, L1 timestamps rising by at least a second per block bound how early a
    /// real block at the header's number can be: a header older than that is off the chain, a
    /// later one is waited for.
    async fn read_anchor(&self, header: &RawL1Header) -> AnchorRead {
        let (number, limit) = (header.number(), self.opts.l1_timeout);
        let finality = own_finality(self.l1(), number, header.hash());
        let finalized = match deadline("L1 finality", limit, finality).await {
            Ok(OwnFinality::NotFinal { finalized }) => finalized,
            Ok(OwnFinality::Canonical) => return AnchorRead::Confirmed,
            Ok(OwnFinality::OffChain { own }) => {
                return AnchorRead::OffChain(format!("the own L1 holds {own} at that number"));
            }
            Err(rejection) => return AnchorRead::failed(rejection),
        };
        let own = match deadline("L1 header", limit, self.l1.header(finalized)).await {
            Ok(own) => own,
            Err(rejection) => return AnchorRead::failed(rejection),
        };
        let earliest = own.timestamp().saturating_add(number - finalized);
        if header.timestamp() < earliest {
            return AnchorRead::OffChain(format!(
                "its timestamp {} is below {earliest}, the earliest a block {number} can have \
                 after the own finalized block {finalized}",
                header.timestamp()
            ));
        }
        AnchorRead::Pending(format!("own L1 finalized {finalized}, below the anchor {number}"))
    }

    /// Completes a cold forced decision before deriving the next cursor. Included transactions,
    /// early peeks and ineligible-byte skips need no singleton build. A canonical skip builds the
    /// singleton on the committed parent's historical state and needs an empty result with
    /// matching headers. Retryable Engine errors and timeouts wait and retry; any other Engine
    /// error (usually the parent's state is gone) is a safety halt with reason
    /// [`FORCED_SKIP_PROBE`] (RECOV-8-13), and a build that contradicts the skip rejects the
    /// decided block, also a safety halt. Never submit or canonicalize the singleton result.
    /// Keep the pinned EL's `allow-unwind-canonical-header` disabled for historical probes.
    async fn confirm_forced(
        &self,
        state: &AppState,
        height: u64,
        v: &Validated,
    ) -> Result<Option<u64>, AbciError> {
        use crate::engine::forced::{ForcedBuildContext, ForcedBuildError, verify_forced};
        let limit = self.opts.engine_timeout;
        let mut backoff = Backoff::new(DECIDED_BLOCK, height);
        loop {
            let build = verify_forced(
                self.engine(),
                ForcedBuildContext { expected: &v.expected, anchor_hash: v.anchor.hash },
                &v.decision,
            );
            let reason = match tokio::time::timeout(limit, build).await {
                Ok(Ok(consumed)) => return Ok(consumed),
                Ok(Err(ForcedBuildError::Engine(e))) if e.is_retryable_build() => e.to_string(),
                Ok(Err(ForcedBuildError::Engine(e))) => {
                    return Err(safety_halt(
                        height,
                        FORCED_SKIP_PROBE,
                        format!(
                            "{}: {e}; restore historical parent state before replay",
                            cannot_build_on(&state.parent)
                        ),
                    ))
                }
                Ok(Err(e)) => return Err(invalid_block(height, &Rejection::ForcedBuild(e))),
                Err(_) => format!("timed out after {limit:?}"),
            };
            let ready = self.execution_parent_ready(state).await?;
            let diagnostic = format!(
                "{}: {reason}; committed execution parent available: {ready}",
                cannot_build_on(&state.parent)
            );
            backoff.wait(FORCED_SKIP_PROBE, &diagnostic).await;
        }
    }

    /// Runs the EL call `call` (named `method`) for the decided block at `height` within the
    /// engine deadline and sorts its answer (see [`App::settle`]).
    async fn el_call(
        &self,
        height: u64,
        method: &'static str,
        call: impl Future<Output = Result<PayloadVerdict, EngineError>>,
    ) -> Result<Settled, AbciError> {
        let limit = self.opts.engine_timeout;
        match tokio::time::timeout(limit, call).await {
            Ok(Ok(PayloadVerdict::Valid)) => Ok(Settled::Valid),
            Ok(Ok(PayloadVerdict::Syncing)) => Ok(Settled::Syncing),
            Ok(Ok(PayloadVerdict::Invalid(reason))) => Err(safety_halt(
                height,
                "payload_invalid",
                format!("{method} answered INVALID: {reason}"),
            )),
            Ok(Err(e)) if e.is_retryable() => Ok(Settled::Retry(e.to_string())),
            Ok(Err(e)) => Err(safety_halt(height, "engine_error", format!("{method} failed: {e}"))),
            Err(_) => Ok(Settled::Retry(format!("timed out after {limit:?}"))),
        }
    }
}

/// The Engine API method name of a forkchoice update, for logs and safety-halt messages.
const FCU: &str = "engine_forkchoiceUpdated";

/// What `FinalizeBlock`'s [`Backoff`] retries, for its logs.
pub(super) const DECIDED_BLOCK: &str = "the decided block";

/// What [`App::decided_staking_words`] retries, for its logs.
const STAKING_WORD_READ: &str = "staking word read";

/// What [`App::decided_fallback_keys`] retries, for its logs.
const FALLBACK_KEYS_FETCH: &str = "fallback key list fetch";

/// Minimum continuous suspicion interval before repeated L1 disagreements justify a halt.
const ANCHOR_OFF_CHAIN_WINDOW: Duration = Duration::from_secs(5);

/// Diagnostic label for cold canonical-skip probes, used as the retry `method` and the
/// safety-halt `reason`. A probe builds only the singleton; it does not reconstruct the proposed
/// block.
const FORCED_SKIP_PROBE: &str = "forced_skip_probe";

/// Why the EL may not probe a forced transaction on `parent`: it lacks the parent block, or
/// the parent's state (pruned, or skipped by a snapshot restore).
fn cannot_build_on(parent: &ParentInfo) -> String {
    format!(
        "the EL cannot build on parent {} ({}); it may lack that block, or its historical state if \
         it prunes state history or was restored from a later snapshot",
        parent.number, parent.hash
    )
}

/// What one EL call of `FinalizeBlock` came to, short of a safety halt.
#[derive(Debug)]
enum Settled {
    /// `VALID`.
    Valid,
    /// `SYNCING`/`ACCEPTED`: the EL cannot execute (or does not hold) the block yet.
    Syncing,
    /// A retryable engine error ([`EngineError::is_retryable`]) or an elapsed deadline,
    /// rendered: the call is retried.
    Retry(String),
}

/// What one read of the own L1 says about a decided block's anchor header
/// ([`App::read_anchor`]).
#[derive(Debug)]
enum AnchorRead {
    /// The own L1 finalized this very header.
    Confirmed,
    /// The header cannot be on the own L1 chain, for the given reason.
    OffChain(String),
    /// The own L1 is unreachable or has not finalized the header yet, for the given reason.
    Pending(String),
    /// The own L1 supplied malformed or contradictory data requiring operator repair.
    Integrity(String),
}

impl AnchorRead {
    /// Classifies own-node errors without treating malformed replies as temporary lag.
    fn failed(error: Rejection) -> Self {
        if error.requires_dependency_repair() {
            Self::Integrity(error.to_string())
        } else {
            Self::Pending(error.to_string())
        }
    }
}

/// The pause schedule of one request's retries on missing data (SYNC-9-7): a decided block's EL
/// (or own-L1) calls in `FinalizeBlock` ([`Backoff::new`]), or the authenticated inputs
/// `InitChain` and the startup `Info` wait for ([`Backoff::startup`]). The first pause is
/// [`FINALIZE_RETRY_INITIAL`], doubling up to [`FINALIZE_RETRY_MAX`]. Retries are logged at WARN;
/// `FinalizeBlock`'s switch to ERROR once the block has been retried for
/// [`FINALIZE_RETRY_ESCALATE`].
#[derive(Debug)]
pub(super) struct Backoff {
    /// What is retried, for the logs, e.g. "the decided block".
    what: &'static str,
    /// The height the retried request is about, for the logs.
    height: u64,
    /// When the retries started.
    since: Instant,
    /// The next pause.
    pause: Duration,
    /// Whether retries escalate to ERROR after [`FINALIZE_RETRY_ESCALATE`].
    escalates: bool,
}

impl Backoff {
    /// `FinalizeBlock`'s schedule for `what` at `height`, starting now: a decided block that
    /// does not settle within [`FINALIZE_RETRY_ESCALATE`] is logged at ERROR.
    pub(super) fn new(what: &'static str, height: u64) -> Self {
        Self { what, height, since: Instant::now(), pause: FINALIZE_RETRY_INITIAL, escalates: true }
    }

    /// A startup schedule (`InitChain`, the startup `Info`) for `what` at `height`, starting now:
    /// the same pauses, but every retry stays at WARN, as normal startup waits (genesis finality,
    /// about 13 minutes on Ethereum, recovery acquisition, the first EL sync) last far longer
    /// than [`FINALIZE_RETRY_ESCALATE`].
    pub(super) fn startup(what: &'static str, height: u64) -> Self {
        Self { escalates: false, ..Self::new(what, height) }
    }

    /// Whether the schedule escalates and the request has been retried for
    /// [`FINALIZE_RETRY_ESCALATE`] or longer.
    pub(super) fn escalated(&self) -> bool {
        self.escalates && self.since.elapsed() >= FINALIZE_RETRY_ESCALATE
    }

    /// Logs that the call or check `method` is retried because of `reason` (WARN, or ERROR once
    /// [`Backoff::escalated`]) and sleeps the current pause, doubling the next one up to the cap.
    pub(super) async fn wait(&mut self, method: &'static str, reason: &str) {
        let (what, height) = (self.what, self.height);
        let (retry_in, retrying_for) = (self.pause, self.since.elapsed());
        if self.escalated() {
            tracing::error!(
                height,
                method,
                %reason,
                ?retrying_for,
                ?retry_in,
                "{what} still does not settle; retrying"
            );
        } else {
            tracing::warn!(height, method, %reason, ?retry_in, "retrying {what}");
        }
        tokio::time::sleep(self.pause).await;
        self.pause = self.pause.saturating_mul(2).min(FINALIZE_RETRY_MAX);
    }
}

/// The state after committing `v` at `height` on top of `state`, before the set that signs
/// `height + 2` is decided and its validator state advances.
///
/// The parent becomes the block's header summary (its grandparent timestamp the old parent's)
/// and the anchor the block's; the forced inclusion cursor advances by one when the block
/// consumes an entry ([`Validated::forced`]).
fn next_state(state: &AppState, v: &Validated, height: u64) -> AppState {
    let header = &v.block.header;
    let mut next = state.clone();
    next.last_height = height;
    next.parent = ParentInfo {
        number: header.number,
        hash: header.hash_slow(),
        timestamp: header.timestamp,
        gas_limit: header.gas_limit,
        gas_used: header.gas_used,
        base_fee: header
            .base_fee_per_gas
            .expect("a validated header carries the derived base fee (rules::check_header)"),
        difficulty: header.difficulty,
        grandparent_timestamp: state.parent.timestamp,
    };
    next.anchor = v.anchor.clone();
    if v.forced.is_some() {
        // `forced::check` consumed exactly entry `state.forced_cursor`, which is below the
        // anchor's `uint48` tail, so this cannot overflow.
        next.forced_cursor = state.forced_cursor + 1;
    }
    next
}

/// The fallback key lists the state `next` after a decided block keeps, given `anchored`, the
/// list its anchor proves when this node holds it: that list, and the recovery origin record's,
/// which a restart requires ([`App::new`](super::App::new)); every other is dropped. So the
/// state holds at most two lists, and every decision the next block can make finds its list in
/// it or brings an anchor of its own, whose list `ProcessProposal` fetches. Generation 0's state
/// records no origin hash: its origin keys sign only its first two blocks, from the validator
/// state, so its origin list stays only while an anchor proves it. The lists are node-local
/// caches, outside the app hash.
fn kept_fallback_keys(
    next: &AppState,
    anchored: Option<FallbackKeys>,
) -> BTreeMap<B256, FallbackKeys> {
    let origin = next.recovery.as_ref().map(|origin| origin.fallback_keys_hash);
    let mut kept: BTreeMap<_, _> = next
        .fallback_keys
        .iter()
        .filter(|&(hash, _)| Some(*hash) == origin)
        .map(|(hash, keys)| (*hash, keys.clone()))
        .collect();
    if let Some(keys) = anchored {
        kept.insert(keys.hash(), keys);
    }
    kept
}

/// The CometBFT validator update setting `pubkey`'s power to `power` (0 removes it).
///
/// Every signing set caps the total power far below CometBFT's `int64` range, so a power
/// outside it is a corrupt state: [`AbciError::SafetyHalt`].
fn validator_update(
    height: u64,
    (pubkey, power): (crate::key::ConsensusKey, u64),
) -> Result<crate::wire::ValidatorUpdate, AbciError> {
    let pub_key = pubkey;
    let power = Power::try_from(power).map_err(|e| {
        safety_halt(height, "validator_power", format!("validator {pubkey} power {power}: {e}"))
    })?;
    Ok(crate::wire::ValidatorUpdate { pub_key, power })
}

/// The safety halt of the decided block at `height` that fails `rejection` ([`safety_halt`] with
/// the rejection's label).
fn invalid_block(height: u64, rejection: &Rejection) -> AbciError {
    safety_halt(height, rejection.label(), format!("invalid block: {rejection}"))
}

/// Logs a safety halt of the decided block at `height` (ERROR, with its `reason` label) and
/// returns it as [`AbciError::SafetyHalt`].
fn safety_halt(height: u64, reason: &'static str, detail: impl fmt::Display) -> AbciError {
    tracing::error!(height, reason, error = %detail, "safety halt in FinalizeBlock");
    AbciError::SafetyHalt(format!("decided block {height}: {detail}"))
}
