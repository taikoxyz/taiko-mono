//! `PrepareProposal` (spec §5.3): choose the anchor, collect the L1 witnesses the height needs,
//! check them as `ProcessProposal` would, and let the EL build the block.

use std::future::Future;

use alloy_primitives::{B256, Bytes, U256};
use tendermint::abci::{request, response};

use super::{
    AbciError, App, deadline,
    validate::{Candidate, Rejection, check_candidate, expected_header},
};
use crate::{
    committee::{self, Snapshot, snapshot_slots},
    engine::Engine,
    envelope::{AnchorWitness, CommitteeWitness, EtnaEnvelope},
    l1::{
        L1Error, L1Source,
        layout::{inbox, registry, word_u32, word_u64},
    },
    rules,
    store::AppState,
    types::RegistryEntry,
};

impl<L: L1Source, E: Engine> App<L, E> {
    /// Handles `PrepareProposal`: one envelope, or no transactions when the node cannot or must
    /// not propose (liveness only).
    ///
    /// A failed build (I/O error, timeout, a failing pre-check, an oversized envelope) is recorded
    /// as the halt reason and logged, and answers empty `txs`; it is never an error. The only
    /// error is a request before `InitChain`.
    pub(super) async fn prepare_proposal(
        &mut self,
        req: request::PrepareProposal,
    ) -> Result<response::PrepareProposal, AbciError> {
        let height = req.height.value();
        let built = match &self.state {
            None => return Err(AbciError::Uninitialized("PrepareProposal")),
            Some(state) => self.propose(state, &req).await,
        };
        let txs = match built {
            Ok(envelope) => {
                tracing::debug!(height, bytes = envelope.len(), "proposal built");
                self.halt = None;
                vec![envelope.0]
            }
            Err(rejection) => {
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
    /// at `n`) is fetched iff `n` moves, the height is `H_0` or a switch height; at
    /// `h_first(e)` the committee witness for `e + 1` is built against the parent's anchor; the
    /// witnesses pass the same checks as in `ProcessProposal` ([`check_candidate`]); the EL
    /// builds on the parent with the derived attributes, and the built header must carry the
    /// derived fields; the envelope must fit `max_tx_bytes`.
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
        let n = state.anchor.number.max(finalized.saturating_sub(params.l1_finality_extra_depth));
        let anchor = if n != state.anchor.number || height == schedule.h0() || switch.is_some() {
            Some(self.anchor_witness(n, switch).await?)
        } else {
            None
        };
        let committee = match schedule.epoch_starting_at(height) {
            Some(e) => {
                let target = e.checked_add(1).expect("an epoch below u64::MAX starts at a height");
                Some(self.committee_witness(state, target).await?)
            }
            None => None,
        };

        let candidate = Candidate {
            anchor: anchor.as_ref(),
            committee: committee.as_ref(),
            extra_generation: state.generation,
            extra_anchor: n,
        };
        let facts = check_candidate(state, params, height, &candidate)?;
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

        let envelope = EtnaEnvelope { block, anchor, committee }.encode();
        if i64::try_from(envelope.len()).is_ok_and(|len| len <= req.max_tx_bytes) {
            Ok(envelope)
        } else {
            Err(Rejection::Oversize { len: envelope.len(), max: req.max_tx_bytes })
        }
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

    /// The committee witness for `target` against the parent's anchor `n_p` (spec §6.4,
    /// amendment A1).
    ///
    /// Discovers, with unproven storage reads at `n_p`, the last checkpoint `i` whose `l1Block`
    /// is at or before the cutoff (binary search; checkpoint 0 when none is, which the
    /// pre-check then rejects) and its `count`; reads its entries at L1 block
    /// `checkpoints[i].l1Block`; proves `snapshot_slots(i, i + 1 < length)` at `n_p`; and
    /// derives the record the block claims.
    async fn committee_witness(
        &self,
        state: &AppState,
        target: u64,
    ) -> Result<CommitteeWitness, Rejection> {
        let params = &self.params;
        let n_p = state.anchor.number;
        let cutoff = committee::cutoff(n_p, params.cutoff_grid, params.cutoff_lag)?;

        let length = self.registry_word(registry::length_slot(), n_p).await?;
        let length = u64::try_from(length)
            .map_err(|_| Rejection::Registry(format!("checkpoints.length {length} exceeds u64")))?;
        // Invariant: checkpoints below `lo` are at or before the cutoff, from `hi` on after it.
        let (mut lo, mut hi) = (0u64, length);
        while lo < hi {
            let mid = lo + (hi - lo) / 2;
            let head = self.registry_word(registry::checkpoint_slots(mid)[0], n_p).await?;
            if word_u64(head, 0) <= cutoff {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        let index = lo.saturating_sub(1);
        let head = self.registry_word(registry::checkpoint_slots(index)[0], n_p).await?;
        let (l1_block, count) = (word_u64(head, 0), word_u32(head, 64));

        let mut entries = Vec::new();
        for j in 0..u64::from(count) {
            let [pubkey, stake, packed] = registry::entry_slots(j);
            let packed = self.registry_word(packed, l1_block).await?;
            entries.push(RegistryEntry {
                pubkey: B256::from(self.registry_word(pubkey, l1_block).await?),
                eff_stake: self.registry_word(stake, l1_block).await?,
                active_from_l1: word_u64(packed, 0),
                exit_effective_l1: word_u64(packed, 64),
                last_heartbeat_at: word_u64(packed, 128),
            });
        }

        let has_next = index.checked_add(1).is_some_and(|next| next < length);
        let slots = snapshot_slots(index, has_next);
        let proof = self
            .l1_read("registry proof read", self.l1.account_witness(params.registry, &slots, n_p))
            .await?;
        let snapshot = Snapshot { checkpoint_index: index, l1_block, entries };
        let (record, _) = committee::derive(&snapshot, cutoff, target, params)?;
        Ok(CommitteeWitness { record, registry: proof, entries: snapshot.entries })
    }

    /// The raw registry storage word at `slot` as of L1 block `block`.
    async fn registry_word(&self, slot: B256, block: u64) -> Result<U256, Rejection> {
        self.l1_read("registry storage read", self.l1.storage_at(self.params.registry, slot, block))
            .await
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
