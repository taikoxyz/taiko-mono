//! `FinalizeBlock` and `Commit`.
//!
//! `FinalizeBlock` is deterministic: it judges a decided block on its envelope, the committed
//! [`AppState`] and the EL, never a beacon (every L1 fact a block consumes travels in the block,
//! the forced transaction bytes included), so a node replaying after a crash or block-syncing
//! derives the same response and state as one that voted. The one L1 read is for a block this
//! node never judged whose envelope moves the anchor: its own L1 must have finalized that very
//! header ([`App::confirm_anchor`]), so a block-synced history cannot carry a forged L1 header and
//! with it a forged registry or Inbox checkpoint. A decided block that fails a deterministic check,
//! whose anchor is off the own L1 chain, that the EL rejects, or that contradicts a known committee
//! is a safety halt: the process exits and an operator must investigate. The derived state stays
//! pending until `Commit` persists it.

use std::{fmt, future::Future, time::Duration};

use alloy_primitives::{B256, Bytes};
use tendermint::{
    abci::{Code, request, response, types::ExecTxResult},
    block::Height,
    public_key::PublicKey,
    validator,
    vote::Power,
};

use tokio::time::Instant;

use super::{
    AbciError, App, FINALIZE_RETRY_ESCALATE, FINALIZE_RETRY_INITIAL, FINALIZE_RETRY_MAX, app_hash,
    deadline, unix_secs,
    validate::{Rejection, Validated, validate_block},
};
use crate::{
    committee,
    engine::{Engine, EngineError, PayloadVerdict},
    envelope::single_envelope,
    l1::{L1Source, RawL1Header},
    metrics::AbciMetrics,
    store::AppState,
    types::ParentInfo,
};

impl<L: L1Source, E: Engine> App<L, E> {
    /// Authenticates a decided envelope against the committed context and settles its payload.
    /// A cached verdict is reused only for identical certified proposer, envelope bytes, expected
    /// header, parent cursor and authenticated facts. Cold decisions confirm moved anchors and
    /// complete any canonical skip probe before deriving the next state. The candidate executes
    /// through `newPayload` and becomes the forkchoice head; singleton evidence never becomes
    /// the head. State stays pending until `Commit`. Invalid decisions halt; temporary EL
    /// failures retry.
    pub(super) async fn finalize_block(
        &mut self,
        req: request::FinalizeBlock,
    ) -> Result<response::FinalizeBlock, AbciError> {
        let _timer = AbciMetrics::finalize_seconds().start_timer();
        let height = req.height.value();
        let Some(state) = &self.state else {
            return Err(AbciError::Uninitialized("FinalizeBlock"));
        };
        let bft_secs = unix_secs(req.time);
        let txs: Vec<Bytes> = req.txs.iter().cloned().map(Bytes::from).collect();
        let env = single_envelope(&txs).map_err(|e| invalid_block(height, &Rejection::from(e)))?;
        let fresh =
            validate_block(state, &self.params, &env, height, bft_secs, req.proposer_address)
                .map_err(|e| invalid_block(height, &e))?;
        let cached = self.verdicts.remove(&req.hash).filter(|v| {
            v.proposer == fresh.proposer &&
                v.envelope_hash == fresh.envelope_hash &&
                v.parent_cursor == fresh.parent_cursor &&
                v.expected == fresh.expected &&
                v.anchor == fresh.anchor &&
                v.derived == fresh.derived &&
                v.decision == fresh.decision
        });
        let (mut validated, cold) = if let Some(cached) = cached {
            (cached, false)
        } else {
            if let Some(witness) = &env.anchor {
                self.confirm_anchor(height, &witness.l1_header).await?;
            }
            (fresh, true)
        };
        if cold {
            validated.forced = self.confirm_forced(state, height, &validated).await?;
        }
        let (next, updates) = next_state(state, &validated, height)?;
        let validator_updates = updates
            .into_iter()
            .map(|update| validator_update(height, update))
            .collect::<Result<Vec<_>, _>>()?;

        let hash = next.parent.hash;
        self.check_trust_candidate(height, hash)?;
        let finalized = next.anchor.inbox.last_checkpoint_hash;
        self.settle(height, &validated, finalized).await?;
        self.decided_live = !cold;

        tracing::debug!(
            height,
            %hash,
            anchor = next.anchor.number,
            forced = ?validated.forced,
            validator_updates = validator_updates.len(),
            "block finalized"
        );
        self.pending = Some(next);
        Ok(response::FinalizeBlock {
            events: vec![],
            tx_results: vec![ExecTxResult { code: Code::Ok, ..Default::default() }],
            validator_updates,
            consensus_param_updates: None,
            app_hash: app_hash(hash),
        })
    }

    /// Handles `Commit`: persists the state the last `FinalizeBlock` derived and makes it the
    /// committed state.
    ///
    /// Clears the `ProcessProposal` cache, the kept reads of an unfinished committee discovery,
    /// the proposal reads (but for the entry at the committed cursor, whose authenticated bytes
    /// remain reusable) and the halt reason, drops a cached committee witness the new committed
    /// state no longer needs, starts a live decision's switch-witness prefetch, publishes the
    /// new head's gauges, and answers `retain_height = 0` (no block pruning). Errors:
    /// [`AbciError::NothingToCommit`] without a pending state; [`AbciError::Store`] when it
    /// cannot be persisted (it then stays pending).
    pub(super) fn commit(&mut self) -> Result<response::Commit, AbciError> {
        let pending = self.pending.as_ref().ok_or(AbciError::NothingToCommit)?;
        self.store.save(pending)?;
        tracing::info!(
            height = pending.last_height,
            hash = %pending.parent.hash,
            "block committed"
        );
        self.state = self.pending.take();
        self.verdicts.clear();
        self.discovery.clear();
        let state = self.state.as_ref().expect("just committed");
        self.prepare_next_height(state);
        if self.decided_live {
            self.prefetch_committee_witness(state);
        } else {
            self.adopt_committee_prefetch(state);
        }
        self.clear_halt();
        self.publish_state_metrics();
        self.trust.committed(self.state.as_ref().expect("committed state"));
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
        let mut backoff = Backoff::new(height);
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
        if self.trust.snapshot().trust_ready { hash } else { B256::ZERO }
    }

    /// Confirms, for the decided block at `height` this node never judged, that its anchor
    /// `header` is final and canonical in the own L1 view, the check `ProcessProposal` makes: the
    /// own L1 must have finalized the header's number plus the chain's extra finality depth, and
    /// hold this very header there.
    ///
    /// While the own L1 is unreachable or has not finalized that far, the block waits with the
    /// [`Backoff`] schedule and is neither finalized nor halted on. [`Rejection::AnchorOffChain`],
    /// a safety halt, needs consecutive off-chain reads spanning at least five seconds (so a
    /// briefly stale or sticky backend is given time to recover) showing the header cannot be on
    /// the own L1 chain: a different own-L1 block at its number, or a number beyond the own
    /// finalized block with a timestamp no block there can have ([`App::read_anchor`]). A
    /// number beyond any finality bound halts at once. The node is then being fed a history
    /// whose L1 facts its own L1 does not have.
    pub(super) async fn confirm_anchor(
        &self,
        height: u64,
        header: &RawL1Header,
    ) -> Result<(), AbciError> {
        let (number, hash) = (header.number(), header.hash());
        let off_chain = |detail: String| {
            invalid_block(height, &Rejection::AnchorOffChain { number, hash, detail })
        };
        let Some(bound) = number.checked_add(self.params.l1_finality_extra_depth) else {
            return Err(off_chain("its number is beyond any finality bound".into()));
        };
        let mut backoff = Backoff::new(height);
        let mut suspect_since = None;
        loop {
            let reason = match self.read_anchor(header, bound).await {
                AnchorRead::Confirmed => return Ok(()),
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

    /// One read of the own L1 about the anchor `header`, which must be final at `bound` (its
    /// number plus the extra finality depth). Above the own finalized block, L1 timestamps rising
    /// by at least a second per block bound how early a real block at the header's number can be:
    /// a header older than that is off the chain, a later one is waited for.
    async fn read_anchor(&self, header: &RawL1Header, bound: u64) -> AnchorRead {
        let (number, limit) = (header.number(), self.opts.l1_timeout);
        let finalized = match deadline("L1 finalized", limit, self.l1.finalized_number()).await {
            Ok(finalized) => finalized,
            Err(rejection) => return AnchorRead::Pending(rejection.to_string()),
        };
        if finalized >= bound {
            return match deadline("L1 canonical hash", limit, self.l1.canonical_hash(number)).await
            {
                Ok(own) if own == header.hash() => AnchorRead::Confirmed,
                Ok(own) => AnchorRead::OffChain(format!("the own L1 holds {own} at that number")),
                Err(rejection) => AnchorRead::Pending(rejection.to_string()),
            };
        }
        if number > finalized {
            let own = match deadline("L1 header", limit, self.l1.header(finalized)).await {
                Ok(own) => own,
                Err(rejection) => return AnchorRead::Pending(rejection.to_string()),
            };
            let earliest = own.timestamp().saturating_add(number - finalized);
            if header.timestamp() < earliest {
                return AnchorRead::OffChain(format!(
                    "its timestamp {} is below {earliest}, the earliest a block {number} can have \
                     after the own finalized block {finalized}",
                    header.timestamp()
                ));
            }
        }
        AnchorRead::Pending(format!("own L1 finalized {finalized}, anchor {number} needs {bound}"))
    }

    /// Completes a cold forced decision before deriving the next cursor. Included transactions,
    /// early peeks and invalid-byte skips need no singleton build. Canonical skips require the
    /// committed parent's historical state and an empty singleton result with matching headers.
    /// Retryable errors and timeouts wait; permanent availability errors halt under
    /// `forced_rebuild_unavailable`. Never submit or canonicalize the singleton result.
    /// Keep the pinned EL's `allow-unwind-canonical-header` disabled for historical probes.
    async fn confirm_forced(
        &self,
        state: &AppState,
        height: u64,
        v: &Validated,
    ) -> Result<Option<u64>, AbciError> {
        use crate::engine::forced::{ForcedBuildContext, ForcedBuildError, verify_forced};
        let limit = self.opts.engine_timeout;
        let mut backoff = Backoff::new(height);
        loop {
            let build = verify_forced(
                self.engine(),
                ForcedBuildContext { expected: &v.expected, anchor_hash: v.anchor.hash },
                &v.decision,
            );
            let reason = match tokio::time::timeout(limit, build).await {
                Ok(Ok(consumed)) => return Ok(consumed),
                Ok(Err(ForcedBuildError::Engine(e)))
                    if e.is_retryable() ||
                        matches!(
                            e,
                            EngineError::BuildNotStarted(_) |
                                EngineError::ErrorReply { code: -38001, .. }
                        ) =>
                {
                    e.to_string()
                }
                Ok(Err(ForcedBuildError::Engine(e))) => {
                    return Err(safety_halt(
                        height,
                        "forced_rebuild_unavailable",
                        format!(
                            "{}: {e}; restore historical parent state before replay",
                            cannot_build_on(&state.parent)
                        ),
                    ))
                }
                Ok(Err(e)) => return Err(invalid_block(height, &Rejection::ForcedBuild(e))),
                Err(_) => format!("timed out after {limit:?}"),
            };
            let diagnostic = format!("{}: {reason}", cannot_build_on(&state.parent));
            backoff.wait(FORCED_SKIP_CHECK, &diagnostic).await;
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

/// Minimum continuous suspicion interval before repeated L1 disagreements justify a halt.
const ANCHOR_OFF_CHAIN_WINDOW: Duration = Duration::from_secs(5);

/// Legacy diagnostic label retained for cold canonical-skip probes so recovery alerts remain
/// compatible. A probe builds only the singleton; it does not reconstruct the proposed block.
const FORCED_SKIP_CHECK: &str = "forced_rebuild_unavailable";

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
}

/// The pause schedule of one decided block's EL (or own-L1) retries in `FinalizeBlock`: the first
/// pause is [`FINALIZE_RETRY_INITIAL`], doubling up to [`FINALIZE_RETRY_MAX`]. Retries are logged
/// at WARN, and at ERROR once the block has been retried for [`FINALIZE_RETRY_ESCALATE`].
#[derive(Debug)]
pub(super) struct Backoff {
    /// The decided block's height, for the logs.
    height: u64,
    /// When the retries started.
    since: Instant,
    /// The next pause.
    pause: Duration,
}

impl Backoff {
    /// A fresh schedule for the decided block at `height`, starting now.
    pub(super) fn new(height: u64) -> Self {
        Self { height, since: Instant::now(), pause: FINALIZE_RETRY_INITIAL }
    }

    /// Whether the block has been retried for [`FINALIZE_RETRY_ESCALATE`] or longer.
    pub(super) fn escalated(&self) -> bool {
        self.since.elapsed() >= FINALIZE_RETRY_ESCALATE
    }

    /// Logs that the EL or L1 call `method` is retried because of `reason` (WARN, or ERROR once
    /// [`Backoff::escalated`]) and sleeps the current pause, doubling the next one up to the cap.
    pub(super) async fn wait(&mut self, method: &'static str, reason: &str) {
        let (height, retry_in, retrying_for) = (self.height, self.pause, self.since.elapsed());
        if self.escalated() {
            tracing::error!(
                height,
                method,
                %reason,
                ?retrying_for,
                ?retry_in,
                "the decided block still does not settle; retrying"
            );
        } else {
            tracing::warn!(height, method, %reason, ?retry_in, "retrying the decided block");
        }
        tokio::time::sleep(self.pause).await;
        self.pause = (self.pause * 2).min(FINALIZE_RETRY_MAX);
    }
}

/// The state after committing `v` at `height` on top of `state`, and the `(pubkey, power)`
/// validator updates the height emits.
///
/// The parent becomes the block's header summary (its grandparent timestamp the old parent's)
/// and the anchor the block's; the forced inclusion cursor advances by one when the block
/// consumes an entry ([`Validated::forced`]); the incoming committee derived at the switch is added
/// before validator updates, a different record already known for its epoch being a
/// [`AbciError::SafetyHalt`]. At the switch height to epoch `t`, `h_first(t) − 2` (CometBFT applies
/// updates two heights later), the updates are [`committee::validator_updates`] from set `t − 1` to
/// set `t`, and committees below `t − 1` are pruned; every other height emits none.
fn next_state(
    state: &AppState,
    v: &Validated,
    height: u64,
) -> Result<(AppState, Vec<(B256, u64)>), AbciError> {
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
    if let Some((epoch, derived)) = &v.derived {
        if let Some(known) = next.committees.get(epoch).filter(|known| *known != derived) {
            return Err(safety_halt(
                height,
                "committee_conflict",
                format!(
                    "derived committee record {:?} for epoch {epoch} differs from the known {:?}",
                    derived.record, known.record
                ),
            ));
        }
        next.committees.insert(*epoch, derived.clone());
    }

    let Some(t) = state.schedule().switch_target(height) else {
        return Ok((next, vec![]));
    };
    let set = |epoch: u64| {
        next.committees.get(&epoch).ok_or_else(|| {
            safety_halt(height, "committee_unknown", format!("no committee for epoch {epoch}"))
        })
    };
    // `switch_target` only yields epochs >= 1.
    let updates = committee::validator_updates(&set(t - 1)?.members, &set(t)?.members);
    next.prune_committees(t - 1);
    Ok((next, updates))
}

/// The CometBFT validator update setting `pubkey`'s power to `power` (0 removes it).
///
/// Committee derivation caps the total power far below CometBFT's `int64` range, so a power
/// outside it is a corrupt state: [`AbciError::SafetyHalt`].
fn validator_update(
    height: u64,
    (pubkey, power): (B256, u64),
) -> Result<validator::Update, AbciError> {
    let pub_key = PublicKey::from_raw_ed25519(pubkey.as_slice())
        .expect("any 32 bytes form a CometBFT Ed25519 public key");
    let power = Power::try_from(power).map_err(|e| {
        safety_halt(height, "validator_power", format!("validator {pubkey} power {power}: {e}"))
    })?;
    Ok(validator::Update { pub_key, power })
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
