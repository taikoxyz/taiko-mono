//! `FinalizeBlock` (spec §5.5) and `Commit` (spec §5.6).
//!
//! `FinalizeBlock` is deterministic: it judges a decided block on its envelope, the committed
//! [`AppState`] and the EL alone, never L1 (D4), so a node replaying after a crash or
//! block-syncing derives the same response and state as one that voted. A decided block that
//! fails a deterministic check, that the EL rejects, or that contradicts a known committee is a
//! safety halt (spec §8.2). The derived state stays pending until `Commit` persists it.

use std::{fmt, future::Future};

use alloy_primitives::{B256, Bytes};
use tendermint::{
    abci::{Code, request, response, types::ExecTxResult},
    block::Height,
    public_key::PublicKey,
    validator,
    vote::Power,
};

use super::{
    AbciError, App, FINALIZE_RETRY_INITIAL, FINALIZE_RETRY_MAX, app_hash, unix_secs,
    validate::{Rejection, Validated, validate_block},
};
use crate::{
    committee,
    engine::{Engine, EngineError, PayloadVerdict},
    envelope::single_envelope,
    l1::L1Source,
    store::AppState,
    types::ParentInfo,
};

impl<L: L1Source, E: Engine> App<L, E> {
    /// Handles `FinalizeBlock`: derives the state after the decided block and makes the EL
    /// execute it and adopt it as its head.
    ///
    /// In order: the block's [`Validated`] verdict is taken from the `ProcessProposal` cache
    /// (by CometBFT block hash) or, when absent (crash replay, block sync), recomputed by
    /// [`validate_block`] from the block's single envelope and BFT time; the next state and the
    /// validator updates are derived ([`next_state`]); the EL executes the block unless the
    /// cached verdict already did, then moves its forkchoice to `head = safe =` the block and
    /// `finalized =` the anchored `lastCheckpoint.blockHash` (D18; zero stays zero); the next
    /// state becomes pending until `Commit`. The state is derived before any EL call so a
    /// contradiction halts before the EL moves.
    ///
    /// The response carries one code-0 `ExecTxResult` for the envelope transaction, the
    /// validator updates of a switch height (D20), `app_hash =` the block hash, no events and
    /// no parameter updates.
    ///
    /// Re-finalizing a block the EL already executed (a replay after a crash before `Commit`)
    /// answers the same: the EL accepts a known payload and forkchoice again. EL calls block
    /// until the EL answers ([`App::settle`]). Errors: [`AbciError::Uninitialized`] before
    /// `InitChain`; [`AbciError::SafetyHalt`] for any failure of the decided block.
    pub(super) async fn finalize_block(
        &mut self,
        req: request::FinalizeBlock,
    ) -> Result<response::FinalizeBlock, AbciError> {
        let height = req.height.value();
        let Some(state) = &self.state else {
            return Err(AbciError::Uninitialized("FinalizeBlock"));
        };
        let validated = match self.verdicts.remove(&req.hash) {
            Some(cached) => cached,
            None => {
                let txs: Vec<Bytes> = req.txs.iter().cloned().map(Bytes::from).collect();
                single_envelope(&txs)
                    .map_err(Rejection::from)
                    .and_then(|env| {
                        validate_block(state, &self.params, &env, height, unix_secs(req.time))
                    })
                    .map_err(|rejection| {
                        safety_halt(
                            height,
                            rejection.label(),
                            format!("invalid block: {rejection}"),
                        )
                    })?
            }
        };
        let (next, updates) = next_state(state, &validated, height)?;
        let validator_updates = updates
            .into_iter()
            .map(|update| validator_update(height, update))
            .collect::<Result<Vec<_>, _>>()?;

        let hash = next.parent.hash;
        if !validated.executed {
            self.settle(height, "engine_newPayload", || self.engine.new_payload(&validated.block))
                .await?;
        }
        let finalized = next.anchor.inbox.last_checkpoint_hash;
        self.settle(height, "engine_forkchoiceUpdated", || {
            self.engine.forkchoice(hash, hash, finalized)
        })
        .await?;

        tracing::debug!(
            height,
            %hash,
            anchor = next.anchor.number,
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
    /// Clears the `ProcessProposal` cache and the halt reason, and answers `retain_height = 0`
    /// (D17). Errors: [`AbciError::NothingToCommit`] without a pending state;
    /// [`AbciError::Store`] when it cannot be persisted (it then stays pending).
    pub(super) fn commit(&mut self) -> Result<response::Commit, AbciError> {
        let pending = self.pending.as_ref().ok_or(AbciError::NothingToCommit)?;
        self.store.save(pending)?;
        tracing::info!(height = pending.last_height, hash = %pending.parent.hash, "block committed");
        self.state = self.pending.take();
        self.verdicts.clear();
        self.halt = None;
        Ok(response::Commit { data: Default::default(), retain_height: Height::from(0u32) })
    }

    /// Runs the EL call `call` (named `what`) for the block at `height` until it answers
    /// `VALID`.
    ///
    /// `INVALID` and any error but a transport failure (e.g. a block the engine adapter cannot
    /// encode) are [`AbciError::SafetyHalt`]s. `SYNCING`/`ACCEPTED`, a transport failure
    /// ([`EngineError::Rpc`]) and a call exceeding the engine deadline are retried after a pause
    /// of [`FINALIZE_RETRY_INITIAL`], doubling up to [`FINALIZE_RETRY_MAX`], for as long as it
    /// takes: `FinalizeBlock` must not answer before the EL holds the block (spec §8.1).
    async fn settle<F, Fut>(
        &self,
        height: u64,
        what: &'static str,
        mut call: F,
    ) -> Result<(), AbciError>
    where
        F: FnMut() -> Fut,
        Fut: Future<Output = Result<PayloadVerdict, EngineError>>,
    {
        let limit = self.opts.engine_timeout;
        let mut pause = FINALIZE_RETRY_INITIAL;
        loop {
            let reason = match tokio::time::timeout(limit, call()).await {
                Ok(Ok(PayloadVerdict::Valid)) => return Ok(()),
                Ok(Ok(PayloadVerdict::Invalid(reason))) => {
                    return Err(safety_halt(
                        height,
                        "payload_invalid",
                        format!("{what} answered INVALID: {reason}"),
                    ));
                }
                Ok(Ok(PayloadVerdict::Syncing)) => "the execution engine is syncing".to_string(),
                Ok(Err(e @ EngineError::Rpc(_))) => e.to_string(),
                Ok(Err(e)) => {
                    return Err(safety_halt(height, "engine_error", format!("{what} failed: {e}")));
                }
                Err(_) => format!("timed out after {limit:?}"),
            };
            tracing::warn!(height, method = what, %reason, retry_in = ?pause, "retrying the EL");
            tokio::time::sleep(pause).await;
            pause = (pause * 2).min(FINALIZE_RETRY_MAX);
        }
    }
}

/// The state after committing `v` at `height` on top of `state`, and the `(pubkey, power)`
/// validator updates the height emits.
///
/// The parent becomes the block's header summary (its grandparent timestamp the old parent's)
/// and the anchor the block's; a committee derived at `h_first(e)` is added, a different record
/// already known for its epoch being a [`AbciError::SafetyHalt`]. At the switch height to epoch
/// `t` (D20) the updates are [`committee::validator_updates`] from set `t − 1` to set `t`, and
/// committees below `t − 1` are pruned; every other height emits none.
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

    let Some(t) = state.schedule.switch_target(height) else {
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

/// Logs a safety halt of the decided block at `height` (ERROR, with its `reason` label) and
/// returns it as [`AbciError::SafetyHalt`].
fn safety_halt(height: u64, reason: &'static str, detail: impl fmt::Display) -> AbciError {
    tracing::error!(height, reason, error = %detail, "safety halt in FinalizeBlock");
    AbciError::SafetyHalt(format!("decided block {height}: {detail}"))
}
