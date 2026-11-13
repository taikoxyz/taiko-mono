//! Read-only authentication of a requested generation; no file, process or EL change.
use super::{
    RecoveryCommandError,
    plan::{Deployment, RecoveryPlan},
};
use abci::{
    ChainParams, Engine, L1Source,
    recovery::{
        authenticate_recovery, build_recovery_genesis, check_recovery_canonicality,
        verify_recovery_witness,
    },
};
use std::time::Duration;

/// Overall acquisition deadline, independent of individual provider transport deadlines.
const PREPARE_DEADLINE: Duration = Duration::from_secs(120);
/// Deadline of the read-only EL state check at c.
const READ_DEADLINE: Duration = Duration::from_secs(10);

/// What a deadline expiry means: the history was not available in time.
const UNAVAILABLE: RecoveryCommandError =
    RecoveryCommandError::Missing("authenticated L1/EL recovery history");

/// Authenticates generation `generation` on the node's own finalized L1 and returns its plan.
///
/// In order (RECOV-8.2-4, RECOV-8.4-2/7..9): authenticate the new generation, c, R and the
/// committee reselected on R's registry snapshot, and build the fixed genesis; verify the
/// witness; require readable EL state at c (SYNC-9-16, RECOV-8.4-8); recheck own finality and
/// the current generation (RECOV-8-14); validate the plan. It writes nothing, starts nothing and
/// makes no Engine build, payload or forkchoice call. InitChain repeats every check.
pub async fn prepare<L: L1Source + ?Sized, E: Engine + ?Sized>(
    params: &ChainParams,
    generation: u64,
    l1: &L,
    engine: &E,
) -> Result<RecoveryPlan, RecoveryCommandError> {
    if generation == 0 || generation >= 1 << 48 {
        return Err(RecoveryCommandError::Parse("nonzero uint48 generation"));
    }
    let (witness, genesis) = tokio::time::timeout(PREPARE_DEADLINE, async {
        let witness = authenticate_recovery(l1, engine, params, generation).await?;
        let genesis = build_recovery_genesis(l1, engine, params, generation).await?;
        Ok::<_, abci::recovery::RecoveryError>((witness, genesis))
    })
    .await
    .map_err(|_| UNAVAILABLE)??;
    let origin = verify_recovery_witness(&witness, params)?;
    match tokio::time::timeout(READ_DEADLINE, engine.historical_state_available(origin.el_hash))
        .await
    {
        Ok(Ok(true)) => {}
        Ok(Err(error)) if error.is_integrity_failure() => return Err(RecoveryCommandError::Invalid),
        _ => return Err(RecoveryCommandError::Missing("EL state at c")),
    }
    tokio::time::timeout(PREPARE_DEADLINE, check_recovery_canonicality(l1, params, &witness))
        .await
        .map_err(|_| UNAVAILABLE)??;
    let plan = RecoveryPlan {
        deployment: Deployment::from(params),
        witness: alloy_rlp::encode(&witness).into(),
        origin,
        genesis: genesis.to_json_pretty().into_bytes().into(),
    };
    plan.validate()?;
    Ok(plan)
}
