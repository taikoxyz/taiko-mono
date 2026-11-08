//! `PrepareProposal`: choose the anchor, collect the L1 witnesses the height needs (with the
//! authenticated transaction of every pending forced entry), check them as `ProcessProposal` would,
//! and let the EL build the block.

use std::future::Future;

use crate::wire::{request, response};
use alloy_consensus::Transaction;
use alloy_primitives::Bytes;

use super::{
    AbciError, App,
    committee_cache::snapshot_block,
    deadline, unix_secs,
    validate::{
        Candidate, Rejection, check_candidate_anchor, check_execution_size, expected_header,
        finish_candidate,
    },
};
use crate::{
    committee::verify_committee_witness_at_cutoff,
    engine::Engine,
    envelope::{AnchorWitness, CommitteeWitness, EtnaEnvelope, ForcedWitness},
    forced::{self, ForcedContext},
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
/// proposer policy preserves the existing 128 KiB budget; landing capacity is checked separately.
const MIXED_TX_SELECTION_BYTES: u64 = 128 * 1024;

impl<L: L1Source, E: Engine> App<L, E> {
    /// Handles `PrepareProposal`: one envelope, or no transactions when the node cannot or must
    /// not propose (liveness only).
    ///
    /// It first refreshes the background switch-witness discovery
    /// ([`App::prefetch_committee_witness`]), which runs on past this request. The whole build
    /// runs within [`AppOptions::prepare_timeout`](super::AppOptions) (each external call also
    /// keeps its own deadline), so the proposer answers before CometBFT's `timeout_propose` even
    /// when every call is slow but in time; a request queued behind it waits no longer. A failed
    /// build (I/O error, timeout, a failing pre-check, an unavailable switch witness or forced
    /// admission bytes, an envelope above `max_tx_bytes` or one landing) is recorded as the halt
    /// reason and logged, and answers empty `txs`; it is never an error. The only error is a
    /// request before `InitChain`.
    pub(super) async fn prepare_proposal(
        &mut self,
        req: request::PrepareProposal,
    ) -> Result<response::PrepareProposal, AbciError> {
        let height = req.height.value();
        let built = match &self.state {
            None => return Err(AbciError::Uninitialized("PrepareProposal")),
            Some(state) => {
                self.prefetch_committee_witness(state);
                deadline("PrepareProposal", self.opts.prepare_timeout, self.propose(state, &req))
                    .await
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
                AbciMetrics::proposals_empty().inc();
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
    /// verifies the candidate, collects the forced inclusion witness the anchor's
    /// queue requires ([`App::forced_inclusion`]), attempts a forced-first mixed list, confirms
    /// any required skip, restores full ordinary selection after a failed forced attempt,
    /// checks every derived header field and ensures the envelope fits CometBFT's transaction
    /// limit and one landing on its own ([`check_execution_size`]).
    async fn propose(
        &self,
        state: &AppState,
        req: &request::PrepareProposal,
    ) -> Result<Bytes, Rejection> {
        if self.superseded {
            return Err(Rejection::ChainSuperseded);
        }
        let prepare_deadline = tokio::time::Instant::now() + self.opts.prepare_timeout;
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
            state.genesis.genesis_height,
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
                let witness = self.committee_witness(state, &anchor_state, target).await?;
                Some((target, witness))
            }
            None => None,
        };
        let witness = committee.as_ref().map(|(_, w)| w);
        let facts =
            finish_candidate(&state.chain_context(), params, height, witness, anchor_state)?;
        if let Some((target_epoch, witness)) = &committee {
            self.cache_candidate_committee_witness(state, &facts.anchor, *target_epoch, witness)?;
        }
        let mut forced = self.forced_inclusion(state, &facts.anchor, prepare_deadline).await?;
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
        let tx_list = if let Some(transaction) = canonical {
            let gas_limit = expected.gas_limit.saturating_sub(transaction.gas_limit());
            let max_bytes = MIXED_TX_SELECTION_BYTES
                .saturating_sub(forced.as_ref().expect("pending witness").tx.len() as u64);
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
                    AbciMetrics::proposal_fallbacks().with_label_values(&["pool_selection"]).inc();
                    Vec::new()
                })
            };
            Some(protocol::shasta::encode_transactions(
                &std::iter::once(transaction).chain(tail).collect::<Vec<_>>(),
            ))
        } else {
            None
        };
        let attempted = tx_list.is_some();
        let mut block = deadline(
            "engine block build",
            self.opts.engine_timeout,
            self.engine.build_block(
                state.parent.hash,
                rules::payload_attributes(&expected, facts.anchor.hash, tx_list),
            ),
        )
        .await?;
        rules::check_header(&block.header, &expected).map_err(Rejection::BuiltHeader)?;
        let mut decision = forced::check(
            context,
            forced.as_ref(),
            block.transactions.first().map(|tx| tx.as_ref()),
        )?;
        let build_context = crate::engine::forced::ForcedBuildContext {
            expected: &expected,
            anchor_hash: facts.anchor.hash,
        };
        deadline(
            "forced singleton check",
            self.opts.engine_timeout,
            crate::engine::forced::verify_forced(self.engine(), build_context, &decision),
        )
        .await?;
        if attempted && !matches!(decision, forced::ForcedDecision::Included(_)) {
            // The provided-list builder can stop at a rejected forced transaction (e.g. zk gas).
            // An ordinary build restores its full native mempool budget.
            block = deadline(
                "ordinary block build",
                self.opts.engine_timeout,
                self.engine.build_block(
                    state.parent.hash,
                    rules::payload_attributes(&expected, facts.anchor.hash, None),
                ),
            )
            .await?;
            rules::check_header(&block.header, &expected).map_err(Rejection::BuiltHeader)?;
            let final_decision = forced::check(
                context,
                forced.as_ref(),
                block.transactions.first().map(|tx| tx.as_ref()),
            )?;
            // The parent, expected header, anchor and witness are unchanged. The successful
            // confirmation above remains valid only if the final candidate has the same decision.
            if final_decision != decision {
                deadline(
                    "final forced singleton check",
                    self.opts.engine_timeout,
                    crate::engine::forced::verify_forced(
                        self.engine(),
                        build_context,
                        &final_decision,
                    ),
                )
                .await?;
            }
            decision = final_decision;
        }
        if matches!(
            decision,
            forced::ForcedDecision::Ordinary | forced::ForcedDecision::Included(_)
        ) && let Some(witness) = &mut forced
        {
            // The entry proof determines timing; the canonical first transaction proves
            // inclusion. Only a skip needs to publish a separate admission preimage.
            witness.tx = Bytes::new();
        }

        let committee = committee.map(|(_, w)| w);
        let envelope = EtnaEnvelope { block, anchor, committee, forced };
        let encoded = envelope.encode();
        if !i64::try_from(encoded.len()).is_ok_and(|len| len <= req.max_tx_bytes) {
            return Err(Rejection::Oversize { len: encoded.len(), max: req.max_tx_bytes });
        }
        check_execution_size(&envelope.block)?;
        Ok(encoded)
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
    /// 1. a retained witness proven under `anchor`;
    /// 2. a retained witness of the same snapshot, re-proved under `anchor` with two reads
    ///    ([`reprove_committee_witness`]) and verified at the snapshot block there; one that does
    ///    not hold is dropped;
    /// 3. else the background discovery at the snapshot block, started or joined and awaited
    ///    ([`App::discovered_committee_witness`]), retained, and re-proved under `anchor` unless it
    ///    was proven there.
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
    ) -> Result<CommitteeWitness, Rejection> {
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
            // The retained witness may have verified only under a forged proposal's root.
            match verify_committee_witness_at_cutoff(
                anchor.state_root,
                snapshot,
                &self.params,
                &witness,
                target,
            ) {
                Ok(_) => return Ok(witness),
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
            Ok(found.witness)
        } else {
            self.reproved_under(&found.witness, anchor).await
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

    /// Fetches the mandatory entry proof. Before due, spends at most one quarter of the
    /// remaining preparation time on optional authenticated admission bytes, leaving time for
    /// an ordinary build. Cancelled waiters retain the bounded owned read for a later round.
    /// Due acquisition errors remain fatal to preparation and never authorize a skip.
    async fn forced_inclusion(
        &self,
        state: &AppState,
        anchor: &AnchorState,
        prepare_deadline: tokio::time::Instant,
    ) -> Result<Option<ForcedWitness>, Rejection> {
        let index = state.forced_cursor;
        if index >= anchor.inbox.forced_inclusion_tail {
            return Ok(None);
        }
        let cached = self.forced_entry(anchor, index).await?;
        let tx = if forced::is_due(
            cached.proven.timestamp,
            state.genesis.forced_inclusion_delay,
            anchor.timestamp,
        ) {
            self.forced_transaction(cached.proven).await?
        } else {
            let budget =
                prepare_deadline.saturating_duration_since(tokio::time::Instant::now()) / 4;
            match tokio::time::timeout(budget, self.forced_transaction(cached.proven)).await {
                Ok(Ok(tx)) => tx,
                Ok(Err(error)) => {
                    tracing::debug!(
                        index,
                        reason = error.label(),
                        "pre-due admission unavailable; building ordinary block"
                    );
                    Bytes::new()
                }
                Err(_) => {
                    tracing::debug!(
                        index,
                        "pre-due admission still pending; building ordinary block"
                    );
                    Bytes::new()
                }
            }
        };
        Ok(Some(ForcedWitness { index, entry: cached.witness, tx }))
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
