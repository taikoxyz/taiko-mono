//! `ProcessProposal`: the deterministic checks of [`validate_block`], then the
//! node-local ¹ checks (anchor finality in the own L1 view, EL execution).

use alloy_primitives::Bytes;
use tendermint::abci::{request, response};

use super::{
    AbciError, App, deadline,
    validate::{Rejection, Validated, validate_block},
};
use crate::{
    engine::{Engine, PayloadVerdict},
    envelope::{AnchorWitness, single_envelope},
    l1::{L1Source, is_final_canonical},
    metrics::AbciMetrics,
    store::AppState,
};

impl<L: L1Source, E: Engine> App<L, E> {
    /// Handles `ProcessProposal`: `ACCEPT` iff the proposal is valid in this node's view.
    ///
    /// An accepted block's [`Validated`] (with `executed = true`) is cached by the CometBFT block
    /// hash for `FinalizeBlock`. A rejection is recorded as the halt reason and logged; it is
    /// never an error. A proven later recovery generation sets the `superseded` status, after
    /// which every proposal is rejected. The only error is a request before `InitChain`.
    pub(super) async fn process_proposal(
        &mut self,
        req: request::ProcessProposal,
    ) -> Result<response::ProcessProposal, AbciError> {
        let _timer = AbciMetrics::process_seconds().start_timer();
        let height = req.height.value();
        let verdict = match &self.state {
            None => return Err(AbciError::Uninitialized("ProcessProposal")),
            Some(state) => self.judge(state, &req).await,
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
                AbciMetrics::process_rejected().with_label_values(&[rejection.label()]).inc();
                self.note_rejection("ProcessProposal", height, &rejection);
                Ok(response::ProcessProposal::Reject)
            }
        }
    }

    /// Judges one proposal on top of `state`.
    ///
    /// In order: a superseded chain rejects everything; no transaction at all is an
    /// [`Rejection::EmptyProposal`]; the transactions must be exactly one envelope;
    /// [`validate_block`] with the request's BFT time; a present anchor witness must be
    /// final and canonical in the own L1 view (L1 is not called when it is absent); the EL must
    /// execute the block as `VALID`. An Inbox ahead of the chain is reported as
    /// [`Rejection::Superseded`] only once its anchor is final and canonical: a forged L1 header
    /// could claim any generation.
    async fn judge(
        &self,
        state: &AppState,
        req: &request::ProcessProposal,
    ) -> Result<Validated, Rejection> {
        if self.superseded {
            return Err(Rejection::ChainSuperseded);
        }
        if req.txs.is_empty() {
            return Err(Rejection::EmptyProposal);
        }
        let txs: Vec<Bytes> = req.txs.iter().cloned().map(Bytes::from).collect();
        let env = single_envelope(&txs)?;
        let height = req.height.value();
        let validated =
            match validate_block(state, &self.params, &env, height, super::unix_secs(req.time)) {
                Err(superseded @ Rejection::Superseded { .. }) => {
                    // Without a witness the facts are the committed parent's, already trusted.
                    if let Some(w) = &env.anchor {
                        self.check_anchor_final(w).await?;
                    }
                    return Err(superseded);
                }
                other => other?,
            };
        if let Some(w) = &env.anchor {
            self.check_anchor_final(w).await?;
        }
        let verdict = deadline(
            "engine_newPayload",
            self.opts.engine_timeout,
            self.engine.new_payload(&validated.block),
        )
        .await?;
        match verdict {
            PayloadVerdict::Valid => Ok(Validated { executed: true, ..validated }),
            PayloadVerdict::Invalid(reason) => Err(Rejection::PayloadInvalid(reason)),
            PayloadVerdict::Syncing => Err(Rejection::PayloadSyncing),
        }
    }

    /// ¹ Requires the anchor header of `w` to be final and canonical in the own L1 view (with
    /// the chain's extra finality depth), within the L1 deadline.
    async fn check_anchor_final(&self, w: &AnchorWitness) -> Result<(), Rejection> {
        let is_final = deadline(
            "L1 finality check",
            self.opts.l1_timeout,
            is_final_canonical(&self.l1, &w.l1_header, self.params.l1_finality_extra_depth),
        )
        .await?;
        if is_final {
            Ok(())
        } else {
            Err(Rejection::AnchorNotFinal { number: w.l1_header.number() })
        }
    }
}
