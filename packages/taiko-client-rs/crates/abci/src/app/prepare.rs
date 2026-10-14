//! `PrepareProposal`: choose the anchor, collect the L1 witnesses the height needs (with the
//! blob of a due forced inclusion entry), check them as `ProcessProposal` would, and let the EL
//! build the block.

use std::future::Future;

use alloy_primitives::Bytes;
use tendermint::abci::{request, response};

use super::{
    AbciError, App, deadline,
    preparation_cache::CachedBlob,
    unix_secs,
    validate::{
        Candidate, Rejection, check_candidate_anchor, check_landing_capacity, expected_header,
        finish_candidate,
    },
};
use crate::{
    engine::Engine,
    envelope::{AnchorWitness, CommitteeWitness, EtnaEnvelope, ForcedWitness},
    forced::{self, ForcedEntry, ForcedError},
    l1::{
        L1Error, L1Source, build_committee_witness_within, header_at, layout::inbox,
        verify_anchor_witness,
    },
    metrics::{AbciMetrics, set_u64},
    rules,
    store::AppState,
    types::AnchorState,
};

impl<L: L1Source, E: Engine> App<L, E> {
    /// Handles `PrepareProposal`: one envelope, or no transactions when the node cannot or must
    /// not propose (liveness only).
    ///
    /// The whole build runs within [`AppOptions::prepare_timeout`](super::AppOptions) (each
    /// external call also keeps its own deadline), so the proposer answers before CometBFT's
    /// `timeout_propose` even when every call is slow but in time. A failed build (I/O error,
    /// timeout, a failing pre-check, an unavailable forced inclusion blob, an envelope above
    /// `max_tx_bytes` or one landing) is recorded as the halt reason and logged, and answers
    /// empty `txs`; it is never an error. The only error is a request before `InitChain`.
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
    /// Chooses `max(parent anchor, own finalized - extra depth)`, authenticates a changed anchor
    /// or the forced H0 anchor, checks progress, generation, status and back-pressure, derives
    /// the header and checks that its timestamp keeps the anchor fresh (an anchor older than
    /// `maxAnchorAge` proposes nothing until L1 finalizes a newer block). At `H(t)-2`, discovers
    /// or reuses committee `t` under the committed parent's state root and anchor number. Then
    /// verifies the candidate, collects the forced inclusion witness the anchor's queue requires
    /// ([`App::forced_inclusion`]), builds through the EL (from the consumed entry's transaction
    /// list for a forced inclusion block), checks every derived header field and ensures the
    /// envelope fits CometBFT's transaction limit and one landing on its own
    /// ([`check_landing_capacity`]).
    async fn propose(
        &self,
        state: &AppState,
        req: &request::PrepareProposal,
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
        let n = state.anchor.number.max(finalized.saturating_sub(params.l1_finality_extra_depth));
        let anchor = if n != state.anchor.number || height == schedule.h0() {
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
            anchor: anchor.as_ref(),
            committee: None,

            extra_generation: state.generation,
            extra_anchor: n,
        };
        let anchor_state = check_candidate_anchor(state, params, height, &candidate)?;
        let expected = expected_header(state, params, height, &anchor_state, unix_secs(req.time))?;
        rules::check_anchor_freshness(
            expected.timestamp,
            anchor_state.timestamp,
            state.genesis.max_anchor_age,
        )?;
        let committee = match switch {
            Some(target) => {
                let witness = self.committee_witness(state, target).await?;
                Some((target, witness))
            }
            None => None,
        };
        let witness = committee.as_ref().map(|(_, w)| w);
        let facts = finish_candidate(state, params, height, witness, anchor_state)?;
        if let Some((target_epoch, witness)) = &committee {
            self.cache_committee_witness(state, *target_epoch, witness)?;
        }
        let (forced, tx_list) = self.forced_inclusion(state, &facts.anchor).await?;
        let attrs = rules::payload_attributes(&expected, facts.anchor.hash, tx_list);
        let block = deadline(
            "engine block build",
            self.opts.engine_timeout,
            self.engine.build_block(state.parent.hash, attrs),
        )
        .await?;
        rules::check_header(&block.header, &expected).map_err(Rejection::BuiltHeader)?;

        let committee = committee.map(|(_, w)| w);
        let envelope = EtnaEnvelope { block, anchor, committee, forced }.encode();
        if !i64::try_from(envelope.len()).is_ok_and(|len| len <= req.max_tx_bytes) {
            return Err(Rejection::Oversize { len: envelope.len(), max: req.max_tx_bytes });
        }
        check_landing_capacity(&envelope)?;
        Ok(envelope)
    }

    /// The committee witness of `target_epoch` against `state`'s fixed parent anchor: a
    /// previously verified witness whose complete identity matches, or a bounded discovery
    /// ([`build_committee_witness_within`]) resuming the completed reads of an earlier attempt.
    /// Historical entries may require state older than the cutoff; the complete witness still
    /// verifies under the committed parent's state root before the caller durably retains it.
    async fn committee_witness(
        &self,
        state: &AppState,
        target_epoch: u64,
    ) -> Result<CommitteeWitness, Rejection> {
        let parent_anchor = state.anchor.number;
        if let Some(witness) = self.cached_committee_witness(state, target_epoch) {
            tracing::debug!(parent_anchor, target_epoch, "reusing the cached committee witness");
            return Ok(witness);
        }
        Ok(build_committee_witness_within(
            self.l1(),
            &self.params,
            &state.schedule(),
            parent_anchor,
            target_epoch,
            self.opts.l1_timeout,
            &self.discovery,
        )
        .await?)
    }

    /// The forced inclusion witness of the block on top of `state` anchored at `anchor`, and the
    /// EL transaction list of a forced inclusion block (`None`: the EL selects the transactions).
    ///
    /// With the cursor `c` at or past the anchor's queue tail the block is ordinary and carries no
    /// witness. Otherwise it proves entry `c` at the anchor and, as the forced inclusion rule
    /// requires (early inclusion is never chosen): carries the entry's blob and consumes it when
    /// due; carries no blob and consumes it as an empty block when expired, without fetching
    /// anything; carries no blob and stays ordinary (a peek) while it is pending. The witness is
    /// then judged by [`forced::check`], as validators judge it. A due entry whose blob cannot be
    /// fetched, or whose fetched blob is not the entry's, is [`Rejection::BlobUnavailable`].
    async fn forced_inclusion(
        &self,
        state: &AppState,
        anchor: &AnchorState,
    ) -> Result<(Option<ForcedWitness>, Option<Bytes>), Rejection> {
        let index = state.forced_cursor;
        if index >= anchor.inbox.forced_inclusion_tail {
            return Ok((None, None));
        }
        let inbox = self.params.inbox;
        let cached = self.forced_entry(anchor, index).await?;
        let (entry, proven) = (cached.witness, cached.proven);
        let delay = state.genesis.forced_inclusion_delay;
        let blob = if forced::is_due(&proven, anchor.timestamp, delay) &&
            !forced::is_expired(&proven, anchor.timestamp)
        {
            self.forced_blob(&proven).await?
        } else {
            Bytes::new()
        };
        let witness = ForcedWitness { index, entry, blob };
        let consumed =
            forced::check(index, anchor, delay, inbox, Some(&witness)).map_err(|e| match e {
                ForcedError::BlobHashMismatch { .. } | ForcedError::BadBlob => {
                    Rejection::BlobUnavailable(e.to_string())
                }
                e => Rejection::Forced(e),
            })?;
        if !witness.blob.is_empty() {
            self.preparation_cache().blob =
                Some(CachedBlob { hash: proven.blob_hash, bytes: witness.blob.clone() });
        }
        Ok((Some(witness), consumed.map(|c| c.tx_list)))
    }

    /// The blob of the due forced inclusion `entry`, by the entry's timestamp and versioned hash,
    /// from the blob source within the blob deadline; one bounded fetch survives cancellation of
    /// the round that awaits it (and `Commit`, when a decided block prefetched it), so a later
    /// round reuses its verified result. A failed fetch is [`Rejection::BlobUnavailable`], and one
    /// that does not answer in time is [`Rejection::Timeout`] (as is a proposal whose own
    /// deadline expires first).
    async fn forced_blob(&self, entry: &ForcedEntry) -> Result<Bytes, Rejection> {
        self.fetch_forced_blob(entry).await
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
        verify_anchor_witness(&witness, self.params.inbox)?;
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
