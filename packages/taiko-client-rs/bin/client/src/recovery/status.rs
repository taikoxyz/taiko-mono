//! Redacted local observations; prepared plans never authorize startup or signing.
use super::{RecoveryCommandError, plan::Prerequisite, store::RecoveryStore};
use alloy_primitives::B256;
use serde::{Deserialize, Serialize};

/// Durable orchestration observation, extended by activation without implying authorization.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryJournal {
    /// Supported journal schema.
    pub schema: u32,
    /// Exact immutable plan whose operation is observed.
    pub plan_id: B256,
    /// Last durable operation phase.
    pub phase: RecoveryPhase,
}
/// Durable operation phases; callers must recheck real facts before any transition.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum RecoveryPhase {
    /// Only immutable evidence/configuration has been staged.
    Prepared,
}
/// Public redacted report, separate from private executable and signer paths.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryStatus {
    /// Exact content-addressed plan.
    pub plan_id: B256,
    /// Requested authenticated generation.
    pub generation: u64,
    /// Fixed retained L2 origin c.
    pub origin_height: u64,
    /// Fixed L1 recovery execution block R.
    pub recovery_l1_block: u64,
    /// Durable local phase, not a trust claim.
    pub phase: RecoveryPhase,
    /// Last authenticated L1-finalized checkpoint height, not a runtime commitment.
    pub landed_height: u64,
    /// Authenticated checkpoint the future runtime must meet before trust can be observed.
    pub trust_target_height: u64,
    /// No runtime session has been queried by this local status command.
    pub component_state: ComponentObservation,
    /// Committed height is unknown until a running owned session is observed.
    pub committed_height: Option<u64>,
    /// Missing preliminary and activation prerequisites.
    pub prerequisites: Vec<Prerequisite>,
}
/// Local-only status cannot infer live component liveness from persisted plans.
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ComponentObservation {
    /// No current-session component observation has been performed.
    NotObserved,
}
/// Reads only local durable evidence; does not query trust or authorize a signer.
pub fn status(store: &RecoveryStore, id: B256) -> Result<RecoveryStatus, RecoveryCommandError> {
    let plan = store.load_plan(id)?;
    let witness = plan.validate()?;
    let checkpoint_slot =
        abci::l1::layout::inbox::slot(abci::l1::layout::inbox::LAST_CHECKPOINT_HEIGHT);
    let landed_height = witness
        .finalized_inbox
        .storage
        .iter()
        .find(|word| word.slot == checkpoint_slot)
        .ok_or(RecoveryCommandError::PlanMismatch)?
        .value
        .try_into()
        .map_err(|_| RecoveryCommandError::PlanMismatch)?;
    let phase = store.load_journal(id)?.map_or(RecoveryPhase::Prepared, |j| j.phase);
    Ok(RecoveryStatus {
        plan_id: id,
        generation: plan.origin.generation,
        origin_height: plan.origin.height,
        recovery_l1_block: plan.origin.l1_number,
        phase,
        landed_height,
        trust_target_height: landed_height,
        component_state: ComponentObservation::NotObserved,
        committed_height: None,
        prerequisites: plan.prerequisites,
    })
}
