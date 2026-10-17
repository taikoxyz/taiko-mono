//! Scalar committee mutation plans; full record equality and update unions stay in adapters.

use crate::schedule::Schedule;

/// Adapter-established relation of a derived committee to the complete known record.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DerivedRelation {
    /// This block does not derive a committee.
    None,
    /// No record was known for the derived epoch.
    Absent(u64),
    /// Full record and member equality holds for the derived epoch.
    Equal(u64),
    /// Full equality fails for the derived epoch.
    Conflicting(u64),
}

/// Pre-insertion knowledge established from the adapter's full committee map.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct CommitteeFacts {
    /// Derived record relation, authenticated before committee transition.
    pub derived: DerivedRelation,
    /// Outgoing target-1 exists in the unmodified map (ignored at non-switch heights).
    pub outgoing_known: bool,
    /// Incoming target exists in the unmodified map (ignored at non-switch heights).
    pub incoming_known: bool,
}

/// Epochs needed for a validator update union and retention cutoff.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct SwitchPlan {
    /// Outgoing epoch, always incoming minus one.
    pub outgoing_epoch: u64,
    /// Incoming epoch, always positive.
    pub incoming_epoch: u64,
    /// Remove map epochs strictly below this cutoff.
    pub prune_before: u64,
}

/// Ordered mutation plan without allocating or carrying opaque committee values.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct CommitteePlan {
    /// Insert the derived record, including equal-known restatements.
    pub insert_epoch: Option<u64>,
    /// Optional validator update and pruning operation.
    pub switch: Option<SwitchPlan>,
}

/// Committee transition failures, ordered conflict, outgoing unknown, incoming unknown.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CommitteeError {
    /// Derived value conflicts with a complete known value.
    Conflict(u64),
    /// Required epoch is absent after overlaying the derived value.
    Unknown(u64),
}

/// Plans conflict checking, insertion and switch lookup over adapter-authenticated facts.
/// The core overlays the derived epoch itself, so callers cannot forget insertion semantics.
pub fn transition_committee(
    epoch_schedule: &Schedule,
    height: u64,
    facts: CommitteeFacts,
) -> Result<CommitteePlan, CommitteeError> {
    let insert_epoch = match facts.derived {
        DerivedRelation::None => None,
        DerivedRelation::Absent(epoch) | DerivedRelation::Equal(epoch) => Some(epoch),
        DerivedRelation::Conflicting(epoch) => return Err(CommitteeError::Conflict(epoch)),
    };
    let Some(target) = epoch_schedule.switch_target(height) else {
        return Ok(CommitteePlan { insert_epoch, switch: None });
    };
    let outgoing = target - 1;
    let derived_outgoing = match insert_epoch {
        Some(epoch) => epoch == outgoing,
        None => false,
    };
    let derived_incoming = match insert_epoch {
        Some(epoch) => epoch == target,
        None => false,
    };
    if !facts.outgoing_known && !derived_outgoing {
        return Err(CommitteeError::Unknown(outgoing));
    }
    if !facts.incoming_known && !derived_incoming {
        return Err(CommitteeError::Unknown(target));
    }
    Ok(CommitteePlan {
        insert_epoch,
        switch: Some(SwitchPlan {
            outgoing_epoch: outgoing,
            incoming_epoch: target,
            prune_before: outgoing,
        }),
    })
}
