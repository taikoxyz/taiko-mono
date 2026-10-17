//! Reconcile one immutable signature against coherent canonical snapshots before replaying it.
use super::{
    source::{ClaimSource, timeout_error},
    store::{ClaimJob, ClaimState, ClaimStore},
    tx::{ClaimTransport, VaultFailure},
};
use crate::{LanderError, Result, tx::NonceState};
use std::time::Duration;

/// One step's observable outcome; Included remains provisional.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ClaimOutcome {
    /// Canonical state shows the reward consumed; an existing signed attempt remains retained.
    AlreadyClaimed,
    /// Current durable transaction phase.
    State(ClaimState),
}

/// Bound ordinary reconciliation independently of the source's longer finality budget.
/// Validated Finalized journals are terminal and need no network requests or rewrites.
pub async fn step(
    store: &ClaimStore,
    source: &dyn ClaimSource,
    transport: &dyn ClaimTransport,
    deadline: Duration,
) -> Result<ClaimOutcome> {
    let old = store.load()?;
    if old.as_ref().is_some_and(|job| job.state == ClaimState::Finalized) {
        return Ok(ClaimOutcome::State(ClaimState::Finalized));
    }
    let result = tokio::time::timeout(deadline, step_inner(store, source, transport, old))
        .await
        .map_err(|_| timeout_error())??;
    if result != ClaimOutcome::State(ClaimState::Included) {
        return Ok(result);
    }
    let mut job = store.load()?.ok_or_else(|| LanderError::Journal("missing claim job".into()))?;
    let inclusion =
        job.inclusion.ok_or_else(|| LanderError::Journal("missing inclusion".into()))?;
    // Even a timeout retains completed discovery pages and a candidate hint. These never
    // authorize finality without a fresh proof and full ancestry authentication.
    let finalized = source.transaction_finalized(&inclusion, &mut job.discovery).await;
    if matches!(finalized, Ok(true)) {
        job.state = ClaimState::Finalized;
    }
    store.save(&job)?;
    finalized?;
    Ok(ClaimOutcome::State(job.state))
}

/// Resume signed jobs before acquiring any fresh calldata proof or nonce.
async fn step_inner(
    store: &ClaimStore,
    source: &dyn ClaimSource,
    transport: &dyn ClaimTransport,
    old: Option<ClaimJob>,
) -> Result<ClaimOutcome> {
    let identity = store.identity();
    if let Some(job) = old.filter(|j| j.transaction.is_some()) {
        return reconcile(store, source, transport, job).await;
    }
    if source.claimed(identity.batch_id).await? {
        return Ok(ClaimOutcome::AlreadyClaimed);
    }
    let proof = source.prepare(identity.landing_tx, identity.batch_id).await?;
    identity.validate_receipt(&proof.receipt)?;
    let mut job = ClaimJob {
        state: ClaimState::Prepared,
        proof,
        transaction: None,
        inclusion: None,
        discovery: None,
    };
    store.save(&job)?;
    let tx = match transport.sign(identity, &job.proof).await {
        Ok(tx) => tx,
        Err(error) if VaultFailure::is_already_claimed(&error) => {
            if source.claimed(identity.batch_id).await? {
                return Ok(ClaimOutcome::AlreadyClaimed);
            }
            return Err(error);
        }
        Err(error) => return Err(error),
    };
    tx.validate(identity, &job.proof)?;
    job.transaction = Some(tx);
    job.state = ClaimState::Signed;
    store.save(&job)?;
    reconcile(store, source, transport, job).await
}

/// Facts acquired around one hash-pinned canonical snapshot.
struct Observation {
    /// Confirmed nonce at the snapshot and advisory pending nonce.
    nonce: NonceState,
    /// Canonical own receipt, if any, no newer than the chosen snapshot.
    receipt: Option<crate::tx::LandingReceipt>,
    /// Claimed at the receipt block, or at the snapshot when no own receipt exists.
    claimed: bool,
}

/// Nonces precede receipt lookup; successful receipts use their own exact state for the bit.
async fn observe(
    source: &dyn ClaimSource,
    transport: &dyn ClaimTransport,
    batch_id: alloy_primitives::B256,
    hash: alloy_primitives::B256,
) -> Result<Observation> {
    let snapshot = source.snapshot().await?;
    let nonce = transport.nonce_at(snapshot.hash).await?;
    let receipt = transport.receipt(hash).await?;
    let receipt = match receipt {
        Some(r) if r.transaction_hash != hash => {
            return Err(LanderError::Safety("claim receipt identity mismatch".into()))
        }
        Some(r) if r.block_number > snapshot.number => {
            return Err(LanderError::Unavailable("claim mined after reconciliation snapshot".into()))
        }
        Some(r) if source.canonical_hash(r.block_number).await? == r.block_hash => Some(r),
        _ => None,
    };
    let block = receipt.filter(|r| r.success).map_or(snapshot.hash, |r| r.block_hash);
    let claimed = source.claimed_at(batch_id, block).await?;
    if let Some(r) = receipt &&
        source.canonical_hash(r.block_number).await? != r.block_hash
    {
        return Err(LanderError::Unavailable(
            "claim inclusion changed during reconciliation".into(),
        ));
    }
    if source.canonical_hash(snapshot.number).await? != snapshot.hash {
        return Err(LanderError::Unavailable("claim snapshot changed during reconciliation".into()));
    }
    Ok(Observation { nonce, receipt, claimed })
}

/// Retry one contradictory acquisition before reporting a stable nonce/receipt conflict.
async fn reconcile(
    store: &ClaimStore,
    source: &dyn ClaimSource,
    transport: &dyn ClaimTransport,
    mut job: ClaimJob,
) -> Result<ClaimOutcome> {
    let tx = job
        .transaction
        .clone()
        .ok_or_else(|| LanderError::Journal("missing signed claim".into()))?;
    for attempt in 0..2 {
        let observation = observe(source, transport, store.identity().batch_id, tx.hash).await;
        let Observation { nonce, receipt, claimed } = match observation {
            Err(LanderError::Unavailable(_)) if attempt == 0 => continue,
            other => other?,
        };
        if let Some(receipt) = receipt {
            if !receipt.success {
                if claimed {
                    return Ok(ClaimOutcome::AlreadyClaimed);
                }
                return Err(LanderError::Reverted("claim transaction reverted; nonce consumed, original intent retained for operator review".into()));
            }
            if !claimed {
                if attempt == 0 {
                    continue;
                }
                return Err(LanderError::Safety(
                    "successful claim receipt without canonical claimed bit".into(),
                ));
            }
            if job.inclusion != Some(receipt) {
                job.discovery = None;
            }
            job.state = ClaimState::Included;
            job.inclusion = Some(receipt);
            store.save(&job)?;
            return Ok(ClaimOutcome::State(job.state));
        }
        if claimed {
            if attempt == 0 {
                continue;
            }
            return Ok(ClaimOutcome::AlreadyClaimed);
        }
        if nonce.pending < nonce.confirmed || nonce.confirmed > tx.nonce {
            if attempt == 0 {
                continue;
            }
            nonce.validate()?;
            return Err(LanderError::Safety(
                "claim nonce consumed without its canonical receipt; no automatic replacement"
                    .into(),
            ));
        }
        if job.inclusion.is_some() {
            job.state = ClaimState::Pending;
            job.inclusion = None;
            job.discovery = None;
            store.save(&job)?;
        }
        if nonce.confirmed < tx.nonce ||
            nonce.pending > tx.nonce ||
            transport.known(tx.hash).await?
        {
            return Ok(ClaimOutcome::State(job.state));
        }
        job.state = ClaimState::Pending;
        store.save(&job)?;
        transport.broadcast(&tx).await?;
        return Ok(ClaimOutcome::State(ClaimState::Pending));
    }
    unreachable!("two acquisition attempts always return")
}
