//! Offline plan summary for comparing with other operators; never a trust or signing signal.
use super::{RecoveryCommandError, plan::RecoveryPlan};
use alloy_primitives::{B256, keccak256};
use serde::{Deserialize, Serialize};
use std::path::Path;

/// What a plan fixes, and whether a home holds its genesis. Trust is read from the running
/// app's `/status`, never from this report (SYNC-9-15).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryStatus {
    /// Requested authenticated generation.
    pub generation: u64,
    /// The generation's full Comet chain ID.
    pub chain_id: String,
    /// Fixed retained L2 origin c.
    pub origin_height: u64,
    /// Fixed L1 recovery execution block R.
    pub recovery_l1_block: u64,
    /// Genesis time, R's timestamp.
    pub genesis_time: String,
    /// keccak256 of the exact genesis.json bytes; equal across honest operators.
    pub genesis_hash: B256,
    /// Size of the committee reselected on R's registry snapshot.
    pub validators: usize,
    /// Latest checkpoint height `prepare` observed on own finalized L1; not a runtime fact.
    pub observed_checkpoint_height: u64,
    /// Whether the given home holds this plan's genesis.json; absent without a home.
    pub installed: Option<bool>,
}

/// Summarizes `plan` and, with `home`, whether it is installed there. No network, no writes.
/// A home holding another genesis is a mismatch, not "not installed".
pub fn status(
    plan: &RecoveryPlan,
    home: Option<&Path>,
) -> Result<RecoveryStatus, RecoveryCommandError> {
    let witness = plan.validate()?;
    let checkpoint_slot =
        abci::l1::layout::inbox::slot(abci::l1::layout::inbox::LAST_CHECKPOINT_HEIGHT);
    let observed_checkpoint_height = witness
        .finalized_inbox
        .storage
        .iter()
        .find(|word| word.slot == checkpoint_slot)
        .ok_or(RecoveryCommandError::PlanMismatch)?
        .value
        .try_into()
        .map_err(|_| RecoveryCommandError::PlanMismatch)?;
    let doc: abci::GenesisDoc =
        serde_json::from_slice(&plan.genesis).map_err(|_| RecoveryCommandError::PlanMismatch)?;
    let installed = home
        .map(|home| {
            let genesis = home.join("config/genesis.json");
            if std::fs::symlink_metadata(&genesis).is_err() {
                return Ok(false);
            }
            let bytes = super::plan::read_bounded(&genesis, plan.genesis.len() as u64 + 1)
                .map_err(|_| RecoveryCommandError::PlanMismatch)?;
            if bytes != plan.genesis.as_ref() {
                return Err(RecoveryCommandError::PlanMismatch);
            }
            Ok(true)
        })
        .transpose()?;
    Ok(RecoveryStatus {
        generation: plan.origin.generation,
        chain_id: doc.chain_id,
        origin_height: plan.origin.height,
        recovery_l1_block: plan.origin.l1_number,
        genesis_time: doc.genesis_time,
        genesis_hash: keccak256(&plan.genesis),
        validators: doc.validators.len(),
        observed_checkpoint_height,
        installed,
    })
}
