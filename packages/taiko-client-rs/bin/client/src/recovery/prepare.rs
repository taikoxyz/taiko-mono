//! Read-only authentication of a requested generation; no file, process or EL change.
use super::{
    RecoveryCommandError,
    plan::{Deployment, RECOVERY_PLAN_SCHEMA, RecoveryPlan},
};
use abci::{
    ChainParams, Engine, L1Source,
    l1::ReadBounded,
    recovery::{
        authenticate_recovery, build_recovery_genesis, check_recovery_canonicality,
        verify_recovery_witness,
    },
};
use std::{sync::Arc, time::Duration};

/// Deadline of each L1 read, independent of the provider's own transport deadline. Only single
/// reads are bounded, never the acquisition as a whole: the origin fallback key list of a
/// generation whose list was stored long before R comes, on an L1 without archive state at R,
/// from a backward log scan of many queries, which must be able to finish.
const L1_READ_DEADLINE: Duration = Duration::from_secs(30);
/// Deadline of the read-only EL state check at c.
const READ_DEADLINE: Duration = Duration::from_secs(10);

/// Authenticates generation `generation` on the node's own finalized L1 and returns its plan.
///
/// In order (RECOV-8.2-4, RECOV-8.4-2/7..9): authenticate the new generation, c, R and the
/// `fallbackKeysHash` of its origin record, and build the fixed genesis on the list with that
/// hash, obtained by it from the own L1; verify the
/// witness; require readable EL state at c (SYNC-9-16, RECOV-8.4-8); recheck own finality and
/// the current generation (RECOV-8-14); validate the plan. It writes nothing, starts nothing and
/// makes no Engine build, payload or forkchoice call. InitChain repeats every check.
///
/// Every L1 read has its own deadline ([`L1_READ_DEADLINE`]); a read that misses it is missing
/// history. EL header reads keep the engine's own request deadline.
///
/// An EL that holds another block at c, or none, has not yet taken the settled block there
/// (RECOV-8.1-7): [`RecoveryCommandError::OriginNotHeld`], which names the authenticated EL
/// hash at c and the runbook, never invalid evidence.
pub async fn prepare<L: L1Source, E: Engine + ?Sized>(
    params: &ChainParams,
    generation: u64,
    l1: Arc<L>,
    engine: &E,
) -> Result<RecoveryPlan, RecoveryCommandError> {
    if generation == 0 || generation >= 1 << 48 {
        return Err(RecoveryCommandError::Parse("nonzero uint48 generation"));
    }
    let l1 = ReadBounded { l1, limit: L1_READ_DEADLINE };
    let witness = authenticate_recovery(&l1, engine, params, generation).await?;
    let genesis = build_recovery_genesis(&l1, engine, params, generation).await?;
    let origin = verify_recovery_witness(&witness, params)?;
    match tokio::time::timeout(READ_DEADLINE, engine.historical_state_available(origin.el_hash))
        .await
    {
        Ok(Ok(true)) => {}
        Ok(Err(error)) if error.is_integrity_failure() => return Err(RecoveryCommandError::Invalid),
        _ => return Err(RecoveryCommandError::Missing("EL state at c")),
    }
    check_recovery_canonicality(&l1, params, &witness).await?;
    let plan = RecoveryPlan {
        schema_version: RECOVERY_PLAN_SCHEMA,
        deployment: Deployment::from(params),
        witness: alloy_rlp::encode(&witness).into(),
        origin,
        genesis: genesis.to_json_pretty().into_bytes().into(),
    };
    plan.validate()?;
    Ok(plan)
}
