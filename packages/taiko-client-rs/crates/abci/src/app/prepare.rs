//! `PrepareProposal`: authenticate the L1 witnesses, build a valid minimum proposal, then try
//! to include optional transactions within the remaining time and size limits.

use std::future::Future;

use crate::wire::{request, response};
use alloy_consensus::Transaction;
use alloy_primitives::Bytes;

use super::{
    AbciError, App, deadline,
    last_commit::extended_committed_flags,
    unix_secs,
    validate::{
        Candidate, Rejection, check_candidate_anchor, check_execution_size, expected_header,
    },
};
use crate::{
    engine::Engine,
    envelope::{AnchorWitness, EtnaEnvelope, ForcedWitness},
    forced::{self, ForcedContext, ForcedDecision, ForcedEntry},
    l1::{L1Error, L1Source, header_at, layout::inbox, verify_anchor_witness},
    metrics::{AbciMetrics, set_u64},
    rules,
    store::AppState,
    types::AnchorState,
};

/// Maximum encoded transaction bytes selected for a forced-first mixed candidate. This
/// proposer policy preserves the existing 128 KiB budget; the block size bound is checked
/// separately.
const MIXED_TX_SELECTION_BYTES: u64 = 128 * 1024;

/// Leave time to return the encoded fallback before the enclosing preparation deadline.
const PROPOSAL_RETURN_MARGIN: std::time::Duration = std::time::Duration::from_millis(10);

impl<L: L1Source, E: Engine> App<L, E> {
    /// Handles `PrepareProposal`: one envelope, or a placeholder proposal with no transactions
    /// when the node cannot or must not propose (liveness only, RECOV-8-10).
    ///
    /// The whole build runs within [`AppOptions::prepare_timeout`](super::AppOptions) (each
    /// external call also keeps its own deadline), so the proposer answers before CometBFT's
    /// `timeout_propose` even when every call is slow but in time; a request queued behind it
    /// waits no longer. A failed mandatory build (I/O error, timeout, a failing pre-check,
    /// unavailable forced admission bytes, a fallback key list for the chosen anchor that the
    /// own L1 cannot give yet, key-to-seat words the own EL cannot serve yet, an envelope above
    /// `max_tx_bytes` or one landing) is recorded as the halt reason and logged, and answers
    /// empty `txs`: a liveness pause, after which a later round proposes once the cause clears.
    /// A list fetch that outlasts the budget keeps running for a later round. The errors are a
    /// request before `InitChain` and a failure that needs its dependency repaired
    /// ([`Rejection::requires_dependency_repair`]: malformed own-L1 or EL replies, or execution
    /// state the EL does not know), a safety halt.
    pub(super) async fn prepare_proposal(
        &mut self,
        req: request::PrepareProposal,
    ) -> Result<response::PrepareProposal, AbciError> {
        let prepare_deadline = tokio::time::Instant::now() + self.opts.prepare_timeout;
        let height = req.height.value();
        let built = match &self.state {
            None => return Err(AbciError::Uninitialized("PrepareProposal")),
            Some(state) => {
                let preparation = async {
                    if self.preparation_execution_parent_ready(state).await? {
                        Ok(self.propose(state, &req, prepare_deadline).await)
                    } else {
                        Ok::<_, AbciError>(Err(Rejection::LocalBlockMissing(state.last_height)))
                    }
                };
                match tokio::time::timeout_at(prepare_deadline, preparation).await {
                    Ok(result) => result?,
                    Err(_) => Err(Rejection::Timeout("PrepareProposal")),
                }
            }
        };
        let txs = match built {
            Ok(envelope) => {
                tracing::debug!(height, bytes = envelope.len(), "proposal built");
                AbciMetrics::proposals_built().inc();
                self.clear_halt();
                vec![envelope.0]
            }
            Err(rejection) => {
                if rejection.requires_dependency_repair() {
                    return Err(AbciError::SafetyHalt(rejection.to_string()));
                }
                AbciMetrics::proposals_placeholder().inc();
                self.note_rejection("PrepareProposal", height, &rejection);
                vec![]
            }
        };
        Ok(response::PrepareProposal { txs })
    }

    /// Builds the encoded envelope of the block at `req.height` on top of `state`.
    ///
    /// The request's `local_last_commit`, the LastCommit CometBFT puts in the block, must list
    /// the replica's set that signs the parent ([`extended_committed_flags`]; otherwise
    /// [`Rejection::LastCommit`], a safety halt); its `missBitmap` comes from the key-to-seat
    /// words of its missing validators in the committed parent's post-state
    /// ([`App::miss_bitmap`]), and an unavailable EL proposes nothing. Precommits that reach
    /// this node after CometBFT built that LastCommit change nothing.
    /// Keeps the parent's anchor or moves it to the own finalized block by the proposer's rule
    /// ([`App::anchor_to_propose`]), authenticates a changed anchor or the forced H0 anchor,
    /// checks progress, generation, back-pressure and checkpoint ancestry (proposing nothing
    /// when a moved anchor's checkpoint conflicts, see [`App::choose_anchor`]), and reads the
    /// queue entry proof under the anchor; a kept anchor under which the own L1 cannot serve
    /// that proof, such as one whose state it has pruned, moves to the own finalized block
    /// (CONS-3.3-4, FI-7.2-2). It makes sure the node holds the fallback key list the anchor
    /// proves, which every validator needs before the block is decided
    /// ([`App::prefetch_fallback_keys`]; proposing nothing while the own L1 cannot give it),
    /// derives the header and checks that its timestamp keeps the anchor fresh (an anchor older
    /// than `maxAnchorAge` proposes nothing until L1 finalizes a newer block). Then collects any
    /// due admission bytes, and encodes a mandatory-only block with any singleton skip evidence.
    /// It then tries to include optional transactions within the remaining budget. Both
    /// envelopes must fit the execution block bound and CometBFT's transaction limit.
    async fn propose(
        &self,
        state: &AppState,
        req: &request::PrepareProposal,
        prepare_deadline: tokio::time::Instant,
    ) -> Result<Bytes, Rejection> {
        let votes = req.local_last_commit.as_ref().map_or(&[][..], |commit| &commit.votes);
        let committed = extended_committed_flags(&state.parent_signers, votes)?;
        if self.superseded {
            return Err(Rejection::ChainSuperseded);
        }
        let params = &self.params;
        let height = req.height.value();

        let finalized = self.l1_read("L1 finalized read", self.l1.finalized_number()).await?;
        set_u64(AbciMetrics::l1_finality_lag(), finalized.saturating_sub(state.anchor.number));
        let n = self.anchor_to_propose(state, height, finalized, unix_secs(req.time)).await?;
        let (mut anchor, mut anchor_state) = self.choose_anchor(state, height, n).await?;
        let index = state.forced_cursor;
        let entry = if index < anchor_state.inbox.forced_inclusion_tail {
            match self.forced_entry(&anchor_state, index).await {
                Ok(entry) => Some(entry),
                // A kept anchor stops serving the block when the own L1 cannot give the forced
                // witness under it (CONS-3.3-4, FI-7.2-2): a read that fails or times out, for
                // example once the node pruned that block's state. Moving to the own finalized
                // block is always valid; a witness that fails to verify does not move it.
                Err(error @ (Rejection::L1(_) | Rejection::Timeout(_)))
                    if anchor.is_none() &&
                        finalized > state.anchor.number &&
                        !error.requires_dependency_repair() =>
                {
                    tracing::info!(
                        height,
                        parent_anchor = state.anchor.number,
                        finalized,
                        %error,
                        "no forced witness under the parent's anchor; moving the anchor"
                    );
                    (anchor, anchor_state) = self.choose_anchor(state, height, finalized).await?;
                    Some(self.forced_entry(&anchor_state, index).await?)
                }
                Err(error) => return Err(error),
            }
        } else {
            None
        };
        rules::check_rules_schedule(
            anchor_state.inbox.rules_schedule,
            &state.parent,
            rules::block_timestamp(
                state.parent.timestamp,
                unix_secs(req.time),
                anchor_state.timestamp,
            ),
        )?;
        self.prefetch_fallback_keys(state, &anchor_state).await?;
        let miss_bitmap = self.miss_bitmap(state, &committed).await?;
        let expected = expected_header(
            &state.chain_context(),
            params,
            height,
            &anchor_state,
            unix_secs(req.time),
            req.proposer_address,
            miss_bitmap,
        )?;
        rules::check_anchor_freshness(
            expected.timestamp,
            anchor_state.timestamp,
            state.genesis.max_anchor_age,
        )?;
        let due = entry.as_ref().is_some_and(|entry| {
            forced::is_due(
                entry.proven.timestamp,
                state.genesis.forced_inclusion_delay,
                anchor_state.timestamp,
            )
        });
        let pre_due = entry.as_ref().filter(|_| !due).map(|entry| entry.proven);
        let forced = if let Some(entry) = entry {
            let tx = if due { self.forced_transaction(entry.proven).await? } else { Bytes::new() };
            Some(ForcedWitness { index, entry: entry.witness, tx })
        } else {
            None
        };
        let context = ForcedContext {
            cursor: state.forced_cursor,
            anchor: &anchor_state,
            delay: state.genesis.forced_inclusion_delay,
            inbox: params.inbox,
            l2_chain_id: params.l2_chain_id,
            block_gas_limit: params.block_gas_limit,
        };
        let canonical = forced.as_ref().and_then(|w| {
            forced::decode_eligible(&w.tx, params.l2_chain_id, params.block_gas_limit)
        });
        // Complete the mandatory work before attempting early inclusion or pool transactions.
        // A cancelled optional EL RPC may leave its build running.
        let minimum_list =
            protocol::shasta::encode_transactions(&canonical.iter().cloned().collect::<Vec<_>>());
        let minimum = deadline(
            "mandatory block build",
            self.opts.engine_timeout,
            self.engine.build_block(
                expected.parent_hash,
                rules::payload_attributes(&expected, anchor_state.hash, Some(minimum_list)),
            ),
        )
        .await?;
        rules::check_header(&minimum.header, &expected).map_err(Rejection::BuiltHeader)?;
        let minimum_decision = forced::check(
            context,
            forced.as_ref(),
            minimum.transactions.first().map(|tx| tx.as_ref()),
        )?;
        // This exact parent/header was built with only the canonical forced transaction. Its
        // empty result is the singleton evidence; never execute the same probe a second time.
        if matches!(minimum_decision, ForcedDecision::NeedsSkip { .. }) &&
            !minimum.transactions.is_empty()
        {
            return Err(crate::engine::forced::ForcedBuildError::Retained.into());
        }
        let minimum = encode_proposal(
            EtnaEnvelope { block: minimum, anchor: anchor.clone(), forced: forced.clone() },
            &minimum_decision,
            req.max_tx_bytes,
        )?;
        let canonical = if matches!(minimum_decision, ForcedDecision::NeedsSkip { .. }) {
            None
        } else {
            canonical.map(|tx| (tx, forced.as_ref().expect("pending witness").tx.len()))
        };
        let optional_deadline = prepare_deadline - PROPOSAL_RETURN_MARGIN;
        let optional = async {
            let canonical = if let Some(entry) = pre_due {
                let budget =
                    optional_deadline.saturating_duration_since(tokio::time::Instant::now()) / 4;
                let early = self.pre_due_admission(entry, budget).await;
                forced::decode_eligible(&early, params.l2_chain_id, params.block_gas_limit)
                    .map(|tx| (tx, early.len()))
            } else {
                canonical
            };
            let tx_list = if let Some((transaction, tx_bytes)) = canonical {
                let gas_limit = expected.gas_limit.saturating_sub(transaction.gas_limit());
                let max_bytes = MIXED_TX_SELECTION_BYTES.saturating_sub(tx_bytes as u64);
                let tail = if gas_limit == 0 || max_bytes == 0 {
                    Vec::new()
                } else {
                    let selected = deadline(
                        "pool selection",
                        self.opts.engine_timeout,
                        self.engine.pool_transactions(crate::engine::PoolSelection {
                            beneficiary: expected.beneficiary,
                            base_fee: expected.base_fee,
                            gas_limit,
                            max_bytes,
                            min_tip: 0,
                        }),
                    )
                    .await;
                    // Pool candidates never reach consensus on their own: the EL executes whatever
                    // list is built, and validators judge only the block. A failed or malformed
                    // selection therefore costs the tail, never the forced transaction or the node.
                    selected.unwrap_or_else(|error| {
                        tracing::warn!(
                            height,
                            reason = error.label(),
                            %error,
                            "pool selection failed; proposing the forced transaction alone"
                        );
                        AbciMetrics::proposal_fallbacks()
                            .with_label_values(&["pool_selection"])
                            .inc();
                        Vec::new()
                    })
                };
                Some(protocol::shasta::encode_transactions(
                    &std::iter::once(transaction).chain(tail).collect::<Vec<_>>(),
                ))
            } else {
                None
            };
            let block = deadline(
                "engine block build",
                self.opts.engine_timeout,
                self.engine.build_block(
                    state.parent.hash,
                    rules::payload_attributes(&expected, anchor_state.hash, tx_list),
                ),
            )
            .await?;
            rules::check_header(&block.header, &expected).map_err(Rejection::BuiltHeader)?;
            let decision = forced::check(
                context,
                forced.as_ref(),
                block.transactions.first().map(|tx| tx.as_ref()),
            )?;
            if matches!(decision, ForcedDecision::NeedsSkip { .. }) && decision != minimum_decision
            {
                // The mandatory-only build included this entry, so an optional build omitting it
                // cannot authorize a skip. Keep the already completed inclusion instead.
                return Err(crate::engine::forced::ForcedBuildError::Retained.into());
            }
            encode_proposal(EtnaEnvelope { block, anchor, forced }, &decision, req.max_tx_bytes)
        };
        match tokio::time::timeout_at(optional_deadline, optional).await {
            Ok(Ok(built)) => Ok(built),
            Ok(Err(error)) if error.requires_dependency_repair() => Err(error),
            failed => {
                let reason = match failed {
                    Ok(Err(error)) => error.to_string(),
                    Err(_) => "optional work exhausted the preparation budget".into(),
                    Ok(Ok(_)) => unreachable!("successful build handled above"),
                };
                tracing::warn!(height, %reason, "proposing the completed mandatory-only block");
                AbciMetrics::proposal_fallbacks().with_label_values(&["optional_build"]).inc();
                Ok(minimum)
            }
        }
    }

    /// The L1 block the block at `height` on top of `state` anchors at (CONS-3.3-4). The
    /// proposer keeps its parent's anchor, except at a generation's first block, at a height
    /// that is a multiple of [`AppOptions::anchor_interval`](super::AppOptions) (1,024), and
    /// when that anchor no longer serves the block: with it the block would fail back-pressure
    /// or anchor freshness (3.4 rules 5 and 7), or the own `finalized` block is more than
    /// `maxAnchorAge` newer than it by L1 timestamp, as after a production pause. (A forced
    /// witness the own L1 cannot serve under it also moves it; [`App::propose`] handles that.)
    /// In those cases it picks the own `finalized` block, never below the parent's anchor; but
    /// a move at a multiple whose parent anchor still serves takes the newest finalized block
    /// the own L1 first showed at least [`AppOptions::anchor_hold`](super::AppOptions) ago, and
    /// keeps the parent's anchor when there is none, so that validators whose view is slightly
    /// behind do not reject the proposal (RECOV-8-5). That instant is the first read of the own
    /// L1 showing the block, by the trust worker on its regular cadence or any handler
    /// ([`OwnL1`](super::OwnL1)), whether or not this node proposed since. A generation's first
    /// block carries a witness of the own finalized head. Reading the finalized block's header
    /// for its timestamp can fail; the parent's anchor is then kept, which 3.4 still bounds.
    async fn anchor_to_propose(
        &self,
        state: &AppState,
        height: u64,
        finalized: u64,
        bft_secs: u64,
    ) -> Result<u64, Rejection> {
        let parent = &state.anchor;
        if state.origin_height().checked_add(1) == Some(height) {
            return Ok(parent.number.max(finalized));
        }
        if finalized <= parent.number {
            return Ok(parent.number);
        }
        let max_age = state.genesis.max_anchor_age;
        let timestamp = rules::block_timestamp(state.parent.timestamp, bft_secs, parent.timestamp);
        let serves = rules::check_anchor_freshness(timestamp, parent.timestamp, max_age).is_ok() &&
            rules::check_back_pressure(
                height,
                parent.inbox.last_checkpoint_height,
                self.params.unsettled_limit,
            )
            .is_ok();
        if !serves {
            return Ok(finalized);
        }
        if height.checked_rem(self.opts.anchor_interval).is_some_and(|rem| rem != 0) {
            let finalized_time = match self.finalized_timestamp(finalized).await {
                Ok(time) => time,
                Err(error) if error.requires_dependency_repair() => return Err(error),
                Err(error) => {
                    tracing::debug!(
                        height,
                        finalized,
                        %error,
                        "own finalized header unavailable; keeping the parent anchor"
                    );
                    return Ok(parent.number);
                }
            };
            if finalized_time.saturating_sub(parent.timestamp) <= max_age {
                return Ok(parent.number);
            }
            tracing::info!(
                height,
                parent_anchor = parent.number,
                finalized,
                "the own finalized L1 block is more than maxAnchorAge newer; moving the anchor"
            );
            return Ok(finalized);
        }
        Ok(self.l1.settled_finalized_above(parent.number, self.opts.anchor_hold).unwrap_or_else(
            || {
                tracing::debug!(
                    height,
                    parent = parent.number,
                    finalized,
                    "holding the parent anchor"
                );
                parent.number
            },
        ))
    }

    /// The L1 timestamp of the own `finalized` block `n`, read once per finality advance.
    async fn finalized_timestamp(&self, n: u64) -> Result<u64, Rejection> {
        if let Some((number, time)) = self.preparation_cache().finalized_time &&
            number == n
        {
            return Ok(time);
        }
        let header = self.l1_read("L1 finalized header read", header_at(self.l1(), n)).await?;
        let time = header.timestamp();
        self.preparation_cache().finalized_time = Some((n, time));
        Ok(time)
    }

    /// The anchor of the block at `height` on top of `state`: L1 block `n` (never below the
    /// parent's), with its witness when the anchor moves or at `H0` ([`App::anchor_candidate`]).
    ///
    /// A moved anchor whose proven `lastCheckpoint` does not name a block of the local chain
    /// ([`App::check_anchor_checkpoint`]) proposes nothing, and the refusal is an alert: a
    /// checkpoint above the parent leaves signing closed until the chain reaches it, a hash that
    /// conflicts at a held height revokes trust, and the node never keeps producing on an older
    /// anchor instead (CONS-3.4-16, [`App::checkpoint_refused`]).
    async fn choose_anchor(
        &self,
        state: &AppState,
        height: u64,
        n: u64,
    ) -> Result<(Option<AnchorWitness>, AnchorState), Rejection> {
        let (witness, anchor) = self.anchor_candidate(state, height, n).await?;
        if witness.is_some() &&
            let Err(rejection) = self.check_anchor_checkpoint(state, &anchor).await
        {
            self.checkpoint_refused(&anchor, &rejection);
            return Err(rejection);
        }
        Ok((witness, anchor))
    }

    /// A candidate anchored at L1 block `n`: its witness, fetched when the anchor moves to `n` or
    /// the height is the generation's first, and the anchor that [`check_candidate_anchor`] proves
    /// (progress, generation and back-pressure) or inherits.
    async fn anchor_candidate(
        &self,
        state: &AppState,
        height: u64,
        n: u64,
    ) -> Result<(Option<AnchorWitness>, AnchorState), Rejection> {
        let params = &self.params;
        let witness =
            if n != state.anchor.number || state.origin_height().checked_add(1) == Some(height) {
                let known = if n == state.anchor.number {
                    Some(state.anchor.clone())
                } else {
                    self.preparation_cache()
                        .anchor
                        .as_ref()
                        .filter(|witness| witness.l1_header.number() == n)
                        .and_then(|witness| verify_anchor_witness(witness, params.inbox).ok())
                };
                let witness = if let Some(known) =
                    known.filter(|anchor| state.forced_cursor < anchor.inbox.forced_inclusion_tail)
                {
                    // A known non-empty queue permits an independent entry proof while the
                    // header/anchor are refreshed. The eventual chosen root still keys reuse.
                    let (witness, _) = tokio::join!(
                        self.anchor_witness(n),
                        self.forced_entry(&known, state.forced_cursor),
                    );
                    witness?
                } else {
                    self.anchor_witness(n).await?
                };
                Some(witness)
            } else {
                None
            };
        let candidate = Candidate {
            anchor: witness.as_ref(),
            extra_generation: state.generation,
            extra_anchor: n,
        };
        let anchor = check_candidate_anchor(&state.chain_context(), params, height, &candidate)?;
        Ok((witness, anchor))
    }

    /// Attempts early inclusion within its share of the optional budget. The authenticated
    /// admission read can finish in the background when this round stops waiting.
    async fn pre_due_admission(&self, entry: ForcedEntry, budget: std::time::Duration) -> Bytes {
        let index = entry.index;
        match tokio::time::timeout(budget, self.forced_transaction(entry)).await {
            Ok(Ok(tx)) => tx,
            Ok(Err(error)) => {
                tracing::debug!(index, reason = error.label(), "pre-due admission unavailable");
                Bytes::new()
            }
            Err(_) => {
                tracing::debug!(index, "pre-due admission still pending");
                Bytes::new()
            }
        }
    }

    /// The anchor witness at L1 block `n`: its canonical header (which must be block `n`) and the
    /// Inbox proofs of `anchor_slots()`.
    async fn anchor_witness(&self, n: u64) -> Result<AnchorWitness, Rejection> {
        let cached = self
            .preparation_cache()
            .anchor
            .as_ref()
            .filter(|witness| witness.l1_header.number() == n)
            .cloned();
        let slots = inbox::anchor_slots();
        let header = self.l1_read("L1 header read", header_at(self.l1(), n));
        let proof =
            self.l1_read("inbox proof read", self.l1.account_witness(self.params.inbox, &slots, n));
        let witness = if let Some(cached) = cached {
            let l1_header = header.await?;
            if l1_header.hash() == cached.l1_header.hash() {
                return Ok(cached);
            }
            AnchorWitness { l1_header, inbox: proof.await? }
        } else {
            let (l1_header, inbox) = tokio::try_join!(header, proof)?;
            AnchorWitness { l1_header, inbox }
        };
        verify_anchor_witness(&witness, self.params.inbox).map_err(Rejection::OwnWitness)?;
        self.preparation_cache().anchor = Some(witness.clone());
        Ok(witness)
    }

    /// Runs one own-L1 read within the L1 deadline.
    async fn l1_read<T>(
        &self,
        what: &'static str,
        fut: impl Future<Output = Result<T, L1Error>>,
    ) -> Result<T, Rejection> {
        deadline(what, self.opts.l1_timeout, fut).await
    }
}

/// Encodes a proposal only if both the EL block and the complete CometBFT envelope fit.
fn encode_proposal(
    mut envelope: EtnaEnvelope,
    decision: &ForcedDecision,
    max_tx_bytes: i64,
) -> Result<Bytes, Rejection> {
    check_execution_size(&envelope.block)?;
    if matches!(decision, ForcedDecision::Ordinary | ForcedDecision::Included(_)) &&
        let Some(witness) = &mut envelope.forced
    {
        // The entry proof determines timing. Inclusion is already proved by the first transaction.
        witness.tx = Bytes::new();
    }
    let bytes = envelope.encode();
    if !i64::try_from(bytes.len()).is_ok_and(|len| len <= max_tx_bytes) {
        return Err(Rejection::Oversize { len: bytes.len(), max: max_tx_bytes });
    }
    Ok(bytes)
}
