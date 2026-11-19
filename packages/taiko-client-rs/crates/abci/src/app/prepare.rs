//! `PrepareProposal`: authenticate the L1 witnesses, build a valid minimum proposal, then try
//! to include optional transactions within the remaining time and size limits.

use std::future::Future;

use crate::wire::{request, response};
use alloy_consensus::Transaction;
use alloy_primitives::Bytes;

use super::{
    AbciError, App,
    committee_cache::{own_l1_proof_failure, snapshot_block},
    deadline, unix_secs,
    validate::{
        Candidate, Rejection, check_candidate_anchor, check_execution_size, expected_header,
        finish_candidate,
    },
};
use crate::{
    committee::{CommitteeError, VerifiedWitness},
    engine::Engine,
    envelope::{AnchorWitness, CommitteeWitness, EtnaEnvelope, ForcedWitness},
    forced::{self, ForcedContext, ForcedDecision, ForcedEntry},
    l1::{
        L1Error, L1Source, header_at, layout::inbox, reprove_committee_witness,
        verify_anchor_witness,
    },
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
    /// It first refreshes the background committee-witness discovery
    /// ([`App::prefetch_committee_witness`]), which runs on past this request. The whole build
    /// runs within [`AppOptions::prepare_timeout`](super::AppOptions) (each external call also
    /// keeps its own deadline), so the proposer answers before CometBFT's `timeout_propose` even
    /// when every call is slow but in time; a request queued behind it waits no longer. A failed
    /// mandatory build (I/O error, timeout, a failing pre-check, an unavailable committee witness
    /// or forced admission bytes, an envelope above `max_tx_bytes` or one landing) is recorded
    /// as the halt reason and logged, and answers empty `txs`. The errors are a request before
    /// `InitChain` and a failure that needs its dependency repaired
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
                self.prefetch_committee_witness(state)?;
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
    /// Chooses `max(parent anchor, own finalized)`, authenticates a changed anchor
    /// or the forced H0 anchor, checks progress, generation, back-pressure and checkpoint
    /// ancestry (keeping the parent anchor when a moved one conflicts, see
    /// [`App::choose_anchor`]), derives
    /// the header and checks that its timestamp keeps the anchor fresh (an anchor older than
    /// `maxAnchorAge` proposes nothing until L1 finalizes a newer block). At `H(t)-2`, takes
    /// committee `t`'s witness at the snapshot block (the committed parent anchor, or the
    /// generation origin R when that is later) from memory or the background discovery, under the
    /// candidate anchor's state root ([`App::committee_witness`]). Then
    /// verifies the candidate, collects the queue entry proof and any due admission bytes, and
    /// encodes a mandatory-only block with any singleton skip evidence. It then tries to include
    /// optional transactions within the remaining budget. Both envelopes must fit the execution
    /// block bound and CometBFT's transaction limit.
    async fn propose(
        &self,
        state: &AppState,
        req: &request::PrepareProposal,
        prepare_deadline: tokio::time::Instant,
    ) -> Result<Bytes, Rejection> {
        if self.superseded {
            return Err(Rejection::ChainSuperseded);
        }
        let params = &self.params;
        let schedule = &state.schedule();
        let height = req.height.value();
        let switch = schedule.switch_target(height);

        let finalized = self.l1_read("L1 finalized read", self.l1.finalized_number()).await?;
        set_u64(AbciMetrics::l1_finality_lag(), finalized.saturating_sub(state.anchor.number));
        let newest = state.anchor.number.max(finalized);
        let (anchor, anchor_state) = self.choose_anchor(state, height, newest).await?;
        rules::check_rules_schedule(
            anchor_state.inbox.rules_schedule,
            &state.parent,
            rules::block_timestamp(
                state.parent.timestamp,
                unix_secs(req.time),
                anchor_state.timestamp,
            ),
        )?;
        let expected = expected_header(
            &state.chain_context(),
            params,
            height,
            &anchor_state,
            unix_secs(req.time),
            req.proposer_address,
        )?;
        rules::check_anchor_freshness(
            expected.timestamp,
            anchor_state.timestamp,
            state.genesis.max_anchor_age,
        )?;
        let committee = match switch {
            Some(target) => {
                let witness =
                    self.committee_witness(state, &anchor_state, target, finalized).await?;
                Some((target, witness))
            }
            None => None,
        };
        let witness = committee.as_ref().map(|(_, w)| w);
        // The witness was verified once, for this anchor's root, cutoff and target; neither the
        // candidate check nor the retention verifies it again.
        let facts = finish_candidate(&state.chain_context(), height, witness, anchor_state)?;
        if let Some((target_epoch, witness)) = &committee {
            self.cache_candidate_committee_witness(state, &facts.anchor, *target_epoch, witness)?;
        }
        let index = state.forced_cursor;
        let entry = if index < facts.anchor.inbox.forced_inclusion_tail {
            Some(self.forced_entry(&facts.anchor, index).await?)
        } else {
            None
        };
        let due = entry.as_ref().is_some_and(|entry| {
            forced::is_due(
                entry.proven.timestamp,
                state.genesis.forced_inclusion_delay,
                facts.anchor.timestamp,
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
            anchor: &facts.anchor,
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
                rules::payload_attributes(&expected, facts.anchor.hash, Some(minimum_list)),
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
        let committee = committee.map(|(_, w)| w.into_witness());
        let minimum = encode_proposal(
            EtnaEnvelope {
                block: minimum,
                anchor: anchor.clone(),
                committee: committee.clone(),
                forced: forced.clone(),
            },
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
                    rules::payload_attributes(&expected, facts.anchor.hash, tx_list),
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
            encode_proposal(
                EtnaEnvelope { block, anchor, committee, forced },
                &decision,
                req.max_tx_bytes,
            )
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

    /// The anchor of the block at `height` on top of `state`: the newest own-finalized L1 block
    /// `newest` (never below the parent's), with its witness when the anchor moves or at `H0`
    /// ([`App::anchor_candidate`]).
    ///
    /// A moved anchor whose proven `lastCheckpoint` conflicts with the local chain
    /// ([`App::check_anchor_checkpoint`]) is never proposed, since every honest validator rejects
    /// it: the parent's still-valid anchor is kept instead, and the conflict is logged at ERROR
    /// and counted in `abci_proposal_fallbacks_total` as an alert. Any other failure of the check
    /// (a dependency that is not ready, say) refuses the proposal.
    async fn choose_anchor(
        &self,
        state: &AppState,
        height: u64,
        newest: u64,
    ) -> Result<(Option<AnchorWitness>, AnchorState), Rejection> {
        let (witness, anchor) = self.anchor_candidate(state, height, newest).await?;
        if witness.is_none() {
            return Ok((witness, anchor));
        }
        match self.check_anchor_checkpoint(state, &anchor).await {
            Ok(()) => Ok((witness, anchor)),
            Err(conflict) if conflict.is_checkpoint_conflict() && newest != state.anchor.number => {
                tracing::error!(
                    height,
                    anchor = newest,
                    parent_anchor = state.anchor.number,
                    reason = conflict.label(),
                    error = %conflict,
                    "the finalized anchor's lastCheckpoint conflicts with the local chain; \
                     proposing on the parent anchor"
                );
                AbciMetrics::proposal_fallbacks().with_label_values(&[conflict.label()]).inc();
                let (witness, anchor) =
                    self.anchor_candidate(state, height, state.anchor.number).await?;
                if witness.is_some() {
                    self.check_anchor_checkpoint(state, &anchor).await?;
                }
                Ok((witness, anchor))
            }
            Err(other) => Err(other),
        }
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
            committee: None,
            extra_generation: state.generation,
            extra_anchor: n,
        };
        let anchor = check_candidate_anchor(&state.chain_context(), params, height, &candidate)?;
        Ok((witness, anchor))
    }

    /// The committee witness of `target` for a switch block anchored at `anchor`. Its snapshot
    /// is the one `state` fixes at [`snapshot_block`]: the committed parent anchor, or the
    /// generation origin R while that anchor precedes it (COMM-4.3-11); `anchor` never selects it.
    /// Only the proofs follow `anchor`'s root (COMM-4.3-12). In order:
    ///
    /// 1. a retained witness verified under `anchor`, served as verified;
    /// 2. a retained witness of the same snapshot, re-proved under `anchor` with two reads
    ///    ([`reprove_committee_witness`]) and verified at the snapshot block there; one that does
    ///    not hold is dropped;
    /// 3. else the background discovery at the snapshot block, started or joined and awaited
    ///    ([`App::discovered_committee_witness`]), retained as it verified it, and re-proved and
    ///    verified under `anchor` unless it was proven there.
    ///
    /// Each witness is verified once for (`anchor`'s root, snapshot block, `target`)
    /// ([`VerifiedWitness::verify`]); the caller carries that value instead of verifying again.
    ///
    /// A discovery still running at `PrepareProposal`'s deadline, or a failed or backing-off one
    /// whose own L1 was unavailable, proposes nothing (RECOV-8-4, RECOV-8-5, RECOV-8-10) while
    /// the discovery goes on; malformed data from the own L1 halts (SYNC-9-7). Historical entries
    /// may require state older than the snapshot block; the complete witness verifies under the
    /// switch block's own anchor root before the caller retains it.
    async fn committee_witness(
        &self,
        state: &AppState,
        anchor: &AnchorState,
        target: u64,
        finalized: u64,
    ) -> Result<VerifiedWitness, Rejection> {
        if let Some(witness) = self.cached_candidate_committee_witness(state, anchor, target) {
            tracing::debug!(
                anchor = anchor.number,
                target,
                "reusing the retained committee witness"
            );
            return Ok(witness);
        }
        let snapshot = snapshot_block(state);
        if let Some(retained) = self.context_committee_witness(state, target) {
            let witness = self.reproved_under(&retained, anchor).await?;
            // The retained witness may have verified only under a forged proposal's root: then
            // its snapshot does not hold here. Its registry proof is the own L1's, though, so a
            // proof that does not verify is an own-L1 contradiction.
            match VerifiedWitness::verify(
                anchor.state_root,
                snapshot,
                &self.params,
                witness,
                target,
            ) {
                Ok(verified) => return Ok(verified),
                Err(error @ CommitteeError::Mpt(_)) => {
                    let timeout = self.opts.l1_timeout;
                    let anchor_id = (anchor.number, anchor.hash);
                    return Err(own_l1_proof_failure(
                        self.l1(),
                        anchor_id,
                        finalized,
                        timeout,
                        error,
                    )
                    .await
                    .into());
                }
                Err(error) => {
                    tracing::warn!(
                        snapshot,
                        anchor = anchor.number,
                        target,
                        %error,
                        "the retained committee snapshot does not hold under the candidate anchor"
                    );
                    self.forget_committee_witness(state, target, &retained);
                }
            }
        }
        let found = self.discovered_committee_witness(state, target).await?;
        self.cache_committee_witness_at_root(state, found.proof_anchor, target, &found.witness)?;
        if found.proof_anchor.1 == anchor.hash {
            return Ok(found.witness);
        }
        let witness = self.reproved_under(found.witness.witness(), anchor).await?;
        match VerifiedWitness::verify(anchor.state_root, snapshot, &self.params, witness, target) {
            Ok(verified) => Ok(verified),
            Err(error) => {
                let anchor_id = (anchor.number, anchor.hash);
                Err(own_l1_proof_failure(
                    self.l1(),
                    anchor_id,
                    finalized,
                    self.opts.l1_timeout,
                    error,
                )
                .await
                .into())
            }
        }
    }

    /// `base` re-proved under `anchor`'s root ([`reprove_committee_witness`]), within the L1
    /// deadline.
    async fn reproved_under(
        &self,
        base: &CommitteeWitness,
        anchor: &AnchorState,
    ) -> Result<CommitteeWitness, Rejection> {
        tracing::debug!(
            cutoff = base.record.cutoff_l1_block,
            anchor = anchor.number,
            target_epoch = base.record.target_epoch,
            "re-proving the committed snapshot under the candidate anchor"
        );
        deadline(
            "switch registry proof",
            self.opts.l1_timeout,
            reprove_committee_witness(
                self.l1(),
                &self.params,
                base,
                anchor.number,
                self.opts.l1_timeout,
            ),
        )
        .await
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
