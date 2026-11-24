//! `ProcessProposal`: the deterministic checks of [`validate_block`], then the
//! node-local ¹ checks (anchor finality in the own L1 view, checkpoint ancestry against the local
//! chain, EL execution), with the EL rebuild of canonical forced skips before normal execution.

use crate::wire::{request, response};
use alloy_primitives::Bytes;

use super::{
    AbciError, App, deadline, unix_secs,
    validate::{Rejection, Validated, validate_block},
};
use crate::{
    engine::{Engine, PayloadVerdict},
    envelope::{AnchorWitness, single_envelope},
    l1::{L1Source, OwnFinality, own_finality},
    metrics::AbciMetrics,
    rules::RuleViolation,
    store::AppState,
    types::AnchorState,
};

impl<L: L1Source, E: Engine> App<L, E> {
    /// Handles `ProcessProposal`: `ACCEPT` iff the proposal is valid in this node's view.
    ///
    /// An accepted block's [`Validated`] (with `executed = true`) is cached by the CometBFT block
    /// hash for `FinalizeBlock`. A rejection is recorded as the halt reason and logged; it is
    /// never an error. A proven later recovery generation sets the `superseded` status, after
    /// which every proposal is rejected. Missing initialization and own-node integrity failures
    /// return errors; temporary dependencies wait without a false rejection, among them a
    /// fallback key list the own L1 cannot give yet.
    /// Hash-canonical unsupported L1 header formats reject without a fatal latch; FinalizeBlock
    /// waits instead.
    pub(super) async fn process_proposal(
        &mut self,
        req: request::ProcessProposal,
    ) -> Result<response::ProcessProposal, AbciError> {
        let _timer = AbciMetrics::process_seconds().start_timer();
        let height = req.height.value();
        let verdict = match &self.state {
            None => return Err(AbciError::Uninitialized("ProcessProposal")),
            Some(state) => {
                let mut backoff = super::finalize::Backoff::new("proposal dependency", height);
                loop {
                    let result = self.judge(state, &req).await;
                    if result.as_ref().err().is_some_and(Rejection::retryable_dependency) {
                        let rejection = result.as_ref().expect_err("retryable rejection");
                        let reason = if matches!(
                            rejection,
                            Rejection::PayloadSyncing | Rejection::LocalBlockMissing(_)
                        ) {
                            let nudge = self.nudge_committed_head(height, state).await?;
                            format!("{rejection}; {nudge}")
                        } else if matches!(
                            rejection,
                            Rejection::Timeout(_) |
                                Rejection::Engine(_) |
                                Rejection::ForcedBuild(
                                    crate::engine::forced::ForcedBuildError::Engine(_)
                                )
                        ) {
                            let ready = self.execution_parent_ready(state).await?;
                            format!("{rejection}; committed execution parent available: {ready}")
                        } else {
                            rejection.to_string()
                        };
                        backoff.wait("ProcessProposal dependency", &reason).await;
                        continue;
                    }
                    break result;
                }
            }
        };
        match verdict {
            Ok(validated) => {
                tracing::debug!(height, hash = %req.hash, "proposal accepted");
                AbciMetrics::process_accepted().inc();
                self.clear_halt();
                self.verdicts.insert(req.hash, validated);
                Ok(response::ProcessProposal::Accept)
            }
            Err(rejection) => {
                if rejection.requires_dependency_repair() {
                    return Err(AbciError::SafetyHalt(rejection.to_string()));
                }
                AbciMetrics::process_rejected().with_label_values(&[rejection.label()]).inc();
                self.note_rejection("ProcessProposal", height, &rejection);
                Ok(response::ProcessProposal::Reject)
            }
        }
    }

    /// Judges one proposal on top of `state`.
    ///
    /// In order: a superseded chain rejects everything; no transaction at all is an
    /// [`Rejection::PlaceholderProposal`]; the transactions must be exactly one envelope;
    /// [`validate_block`] with the request's BFT time, whose first check is the block size bound
    /// ([`check_execution_size`](super::validate::check_execution_size)); a present
    /// anchor witness must be final and canonical in the own L1 view (L1 is not called when it is
    /// absent), and its proven `lastCheckpoint` must name a block of the local chain
    /// ([`App::check_anchor_checkpoint`]); the shared checker must complete the authenticated
    /// forced decision within the engine deadline; the EL must execute the ordinary candidate
    /// payload as `VALID`; finally this node must hold the fallback key list the block's anchor
    /// proves, or obtain it from the own L1 ([`App::prefetch_fallback_keys`]), so that
    /// `FinalizeBlock` finds it at hand. Only a block valid in every other respect waits for
    /// its list, and a list the own L1 cannot give yet is
    /// [`Rejection::FallbackKeysUnavailable`], on which `ProcessProposal` waits.
    ///
    /// Supersession is reported only after the supplied anchor is independently confirmed final
    /// and canonical, since a forged header could claim a later generation.
    ///
    /// Anchor age is measured against the fixed derived block timestamp in [`validate_block`],
    /// never against a moving local finalized head. Once final and canonical, an anchor does not
    /// expire merely because more L1 blocks finalize, including on a node without a cached verdict.
    async fn judge(
        &self,
        state: &AppState,
        req: &request::ProcessProposal,
    ) -> Result<Validated, Rejection> {
        if self.superseded {
            return Err(Rejection::ChainSuperseded);
        }
        if req.txs.is_empty() {
            return Err(Rejection::PlaceholderProposal);
        }
        let txs: Vec<Bytes> = req.txs.iter().cloned().map(Bytes::from).collect();
        let env = match single_envelope(&txs) {
            Ok(env) => env,
            Err(error) => {
                // Every outcome rejects (RECOV-8-6); the own L1 only names the reason, so a
                // temporary answer about a number the proposer chose never keeps this pending.
                return Err(match self.check_header_format(&txs).await {
                    Err(reason) if !reason.retryable_dependency() => reason,
                    _ => error.into(),
                });
            }
        };
        let (height, bft_secs) = (req.height.value(), unix_secs(req.time));
        let mut validated = match validate_block(
            &state.chain_context(),
            &self.params,
            &env,
            height,
            bft_secs,
            req.proposer_address,
        ) {
            Err(l1_fact @ Rejection::Superseded { .. }) => {
                // Without a witness the facts are the committed parent's, already trusted.
                if let Some(w) = &env.anchor {
                    self.check_anchor_final(w).await?;
                }
                return Err(l1_fact);
            }
            other => other?,
        };
        if let Some(w) = &env.anchor {
            self.check_anchor_final(w).await?;
            if let Err(rejection) = self.check_anchor_checkpoint(state, &validated.anchor).await {
                self.checkpoint_refused(&validated.anchor, &rejection);
                return Err(rejection);
            }
            self.observe_anchor_checkpoint(&validated.anchor);
        }
        validated.forced = deadline(
            "forced singleton check",
            self.opts.engine_timeout,
            crate::engine::forced::verify_forced(
                self.engine(),
                crate::engine::forced::ForcedBuildContext {
                    expected: &validated.expected,
                    anchor_hash: validated.anchor.hash,
                },
                &validated.decision,
            ),
        )
        .await?;
        let verdict = deadline(
            "engine_newPayload",
            self.opts.engine_timeout,
            self.engine.new_payload(&validated.block),
        )
        .await?;
        match verdict {
            PayloadVerdict::Valid => {}
            PayloadVerdict::Invalid(reason) => return Err(Rejection::PayloadInvalid(reason)),
            PayloadVerdict::Syncing => return Err(Rejection::PayloadSyncing),
        }
        self.prefetch_fallback_keys(state, &validated.anchor).await?;
        Ok(Validated { executed: true, ..validated })
    }

    /// Distinguishes a canonical unsupported L1 header from a forged malformed witness.
    ///
    /// The proposer chooses the `extraData` anchor number, so one above the own finalized head is
    /// [`Rejection::AnchorNotFinal`] before any header lookup (CONS-3.3-5); FinalizeBlock then
    /// waits for L1 finality instead of comparing against a non-final hash. ProcessProposal never
    /// waits on this check, since it rejects whatever the own L1 answers.
    pub(super) async fn check_header_format(&self, txs: &[Bytes]) -> Result<(), Rejection> {
        if let Some((number, raw)) = crate::envelope::undecodable_anchor(txs) {
            let hash = alloy_primitives::keccak256(&raw);
            match deadline(
                "L1 anchor header finality",
                self.opts.l1_timeout,
                own_finality(self.l1(), number, hash),
            )
            .await?
            {
                OwnFinality::NotFinal { .. } => return Err(Rejection::AnchorNotFinal { number }),
                OwnFinality::Canonical => {
                    let error = crate::l1::RawL1Header::from_raw(raw)
                        .expect_err("unrecognized header shape");
                    return Err(crate::l1::L1Error::UnsupportedHeaderFormat { number, error }.into());
                }
                // Not the own block: the caller's envelope decode error stands.
                OwnFinality::OffChain { .. } => {}
            }
        }
        Ok(())
    }

    /// ¹ Requires the anchor header of `w` to be final and canonical in the own L1 view, within
    /// the L1 deadline. An own L1 node that has not finalized it, because its view is behind the
    /// proposer's, it lags, is unreachable or times out, rejects at once and never waits
    /// (CONS-3.3-5, RECOV-8-5): the node prevotes nil and judges a later round's proposal against
    /// its view then. Only malformed own-L1 data needs repair.
    async fn check_anchor_final(&self, w: &AnchorWitness) -> Result<(), Rejection> {
        let number = w.l1_header.number();
        match deadline(
            "L1 finality check",
            self.opts.l1_timeout,
            own_finality(self.l1(), number, w.l1_header.hash()),
        )
        .await
        {
            Ok(OwnFinality::Canonical) => Ok(()),
            Ok(OwnFinality::NotFinal { .. } | OwnFinality::OffChain { .. }) => {
                Err(Rejection::AnchorNotFinal { number })
            }
            Err(error) if error.requires_dependency_repair() => Err(error),
            Err(error) => {
                tracing::warn!(number, %error, "own L1 cannot confirm the anchor's finality now");
                Err(Rejection::AnchorNotFinal { number })
            }
        }
    }

    /// What a proposal's refused checkpoint means for this node itself (CONS-3.4-16): a
    /// checkpoint above the parent is one its chain has not reached, so it signs nothing until it
    /// has reached that height and compared ([`App::observe_anchor_checkpoint`]); a hash that
    /// differs at a height it holds contradicts finalized L1 and revokes its trust. Any other
    /// refusal, such as a dependency that is not ready, changes nothing.
    pub(super) fn checkpoint_refused(&self, anchor: &AnchorState, rejection: &Rejection) {
        match rejection {
            Rejection::Rule(RuleViolation::CheckpointAboveParent { .. }) => {
                self.observe_anchor_checkpoint(anchor);
            }
            Rejection::Rule(RuleViolation::CheckpointConflict { .. }) => {
                self.revoke_checkpoint_trust(&rejection.to_string());
            }
            _ => {}
        }
    }
}
