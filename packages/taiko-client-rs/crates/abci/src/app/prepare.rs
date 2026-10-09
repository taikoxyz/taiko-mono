//! `PrepareProposal` (spec §5.3): choose the anchor, collect the L1 witnesses the height needs,
//! check them as `ProcessProposal` would, and let the EL build the block.

use std::future::Future;

use alloy_primitives::Bytes;
use tendermint::abci::{request, response};

use super::{
    AbciError, App, CachedCommittee, deadline,
    validate::{Candidate, Rejection, check_candidate_anchor, expected_header, finish_candidate},
};
use crate::{
    engine::Engine,
    envelope::{AnchorWitness, CommitteeWitness, EtnaEnvelope},
    l1::{L1Error, L1Source, build_committee_witness_within, layout::inbox},
    metrics::{AbciMetrics, set_u64},
    rules,
    store::AppState,
};

impl<L: L1Source, E: Engine> App<L, E> {
    /// Handles `PrepareProposal`: one envelope, or no transactions when the node cannot or must
    /// not propose (liveness only).
    ///
    /// The whole build runs within [`AppOptions::prepare_timeout`](super::AppOptions) (each
    /// external call also keeps its own deadline), so the proposer answers before CometBFT's
    /// `timeout_propose` even when every call is slow but in time. A failed build (I/O error,
    /// timeout, a failing pre-check, an oversized envelope) is recorded as the halt reason and
    /// logged, and answers empty `txs`; it is never an error. The only error is a request before
    /// `InitChain`.
    pub(super) async fn prepare_proposal(
        &mut self,
        req: request::PrepareProposal,
    ) -> Result<response::PrepareProposal, AbciError> {
        let height = req.height.value();
        let built = match &self.state {
            None => return Err(AbciError::Uninitialized("PrepareProposal")),
            Some(state) => {
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
                AbciMetrics::proposals_empty().inc();
                self.note_rejection("PrepareProposal", height, &rejection);
                vec![]
            }
        };
        Ok(response::PrepareProposal { txs })
    }

    /// Builds the encoded envelope of the block at `req.height` on top of `state`.
    ///
    /// In order: a superseded chain proposes nothing; the anchor is
    /// `n = max(parent anchor, own finalized − F_L1)`, and its witness (header and Inbox proofs
    /// at `n`) is fetched iff `n` moves, the height is `H_0` or a switch height; the anchor
    /// passes the committee-free checks of `ProcessProposal` ([`check_candidate_anchor`]: anchor
    /// progress, generation, `migrationState`, back-pressure), so a block that cannot be proposed
    /// costs no committee discovery; at `h_first(e)` the committee witness for `e + 1` is taken
    /// from an earlier round at this height or built against the parent's anchor
    /// ([`App::committee_witness`]); the rest of `ProcessProposal`'s witness checks pass
    /// ([`finish_candidate`]); the EL builds on the parent with the derived attributes, and the
    /// built header must carry the derived fields; the envelope must fit `max_tx_bytes`.
    async fn propose(
        &self,
        state: &AppState,
        req: &request::PrepareProposal,
    ) -> Result<Bytes, Rejection> {
        if self.superseded {
            return Err(Rejection::ChainSuperseded);
        }
        let params = &self.params;
        let schedule = &state.schedule;
        let height = req.height.value();
        let switch = schedule.switch_target(height);

        let finalized = self.l1_read("L1 finalized read", self.l1.finalized_number()).await?;
        set_u64(AbciMetrics::l1_finality_lag(), finalized.saturating_sub(state.anchor.number));
        let n = state.anchor.number.max(finalized.saturating_sub(params.l1_finality_extra_depth));
        let anchor = if n != state.anchor.number || height == schedule.h0() || switch.is_some() {
            Some(self.anchor_witness(n, switch).await?)
        } else {
            None
        };
        let candidate = Candidate {
            anchor: anchor.as_ref(),
            committee: None,
            extra_generation: state.generation,
            extra_anchor: n,
        };
        let anchor_state = check_candidate_anchor(state, params, height, &candidate)?;
        let committee = match schedule.epoch_starting_at(height) {
            Some(e) => {
                let target = e.checked_add(1).expect("an epoch below u64::MAX starts at a height");
                Some((target, self.committee_witness(state.anchor.number, target).await?))
            }
            None => None,
        };
        let witness = committee.as_ref().map(|(_, w)| w);
        let facts = finish_candidate(state, params, height, witness, anchor_state)?;
        if let Some((target_epoch, witness)) = &committee {
            *self.committee_cache() = Some(CachedCommittee {
                parent_anchor: state.anchor.number,
                target_epoch: *target_epoch,
                witness: witness.clone(),
            });
        }
        let expected =
            expected_header(state, params, height, &facts.anchor, super::unix_secs(req.time))?;
        let attrs = rules::payload_attributes(&expected, facts.anchor.hash);
        let block = deadline(
            "engine block build",
            self.opts.engine_timeout,
            self.engine.build_block(state.parent.hash, attrs),
        )
        .await?;
        rules::check_header(&block.header, &expected).map_err(Rejection::BuiltHeader)?;

        let committee = committee.map(|(_, w)| w);
        let envelope = EtnaEnvelope { block, anchor, committee }.encode();
        if i64::try_from(envelope.len()).is_ok_and(|len| len <= req.max_tx_bytes) {
            Ok(envelope)
        } else {
            Err(Rejection::Oversize { len: envelope.len(), max: req.max_tx_bytes })
        }
    }

    /// The committee witness of `target_epoch` against the parent's anchor `parent_anchor`: the
    /// one an earlier round at this height discovered and verified, if its key matches, else a
    /// fresh discovery ([`build_committee_witness_within`], each read within the L1 deadline,
    /// reading no state older than the committee cutoff). The caller caches a fresh witness once
    /// it verifies.
    async fn committee_witness(
        &self,
        parent_anchor: u64,
        target_epoch: u64,
    ) -> Result<CommitteeWitness, Rejection> {
        let cached = self.committee_cache().as_ref().and_then(|c| {
            (c.parent_anchor == parent_anchor && c.target_epoch == target_epoch)
                .then(|| c.witness.clone())
        });
        if let Some(witness) = cached {
            tracing::debug!(
                parent_anchor,
                target_epoch,
                "reusing the discovered committee witness"
            );
            return Ok(witness);
        }
        Ok(build_committee_witness_within(
            &self.l1,
            &self.params,
            parent_anchor,
            target_epoch,
            self.opts.l1_timeout,
        )
        .await?)
    }

    /// The anchor witness at L1 block `n`: its canonical header and the Inbox proofs of
    /// `anchor_slots(switch)`.
    async fn anchor_witness(
        &self,
        n: u64,
        switch: Option<u64>,
    ) -> Result<AnchorWitness, Rejection> {
        let l1_header = self.l1_read("L1 header read", self.l1.header(n)).await?;
        let slots = inbox::anchor_slots(switch);
        let inbox = self
            .l1_read("inbox proof read", self.l1.account_witness(self.params.inbox, &slots, n))
            .await?;
        Ok(AnchorWitness { l1_header, inbox })
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
