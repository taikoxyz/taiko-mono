//! Resume existing signatures before acquiring fresh proofs, with conservative nonce
//! reconciliation.
use super::{
    source::{ClaimSource, timeout_error},
    store::{ClaimJob, ClaimState, ClaimStore},
    tx::ClaimTransport,
};
use crate::{LanderError, Result};
use std::time::Duration;

/// One step's observable outcome; Included remains provisional.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ClaimOutcome {
    /// Another successful claim already set the on-chain bit; no new transaction was signed.
    AlreadyClaimed,
    /// Current durable transaction phase.
    State(ClaimState),
}

/// Execute a bounded step. Every send follows a durable Pending save, including first sends.
pub async fn step(
    store: &ClaimStore,
    source: &dyn ClaimSource,
    transport: &dyn ClaimTransport,
    deadline: Duration,
) -> Result<ClaimOutcome> {
    tokio::time::timeout(deadline, step_inner(store, source, transport))
        .await
        .map_err(|_| timeout_error())?
}

/// Preserve existing signed jobs before any proof preparation, including ring-entry expiration.
async fn step_inner(
    store: &ClaimStore,
    source: &dyn ClaimSource,
    transport: &dyn ClaimTransport,
) -> Result<ClaimOutcome> {
    let identity = store.identity();
    let old = store.load()?;
    if let Some(job) = old.as_ref().filter(|j| j.transaction.is_some()) {
        return reconcile(store, source, transport, job.clone()).await;
    }
    if source.claimed(identity.batch_id).await? {
        return Ok(ClaimOutcome::AlreadyClaimed);
    }
    let proof = source.prepare(identity.landing_tx, identity.batch_id).await?;
    identity.validate_receipt(&proof.receipt)?;
    let mut job =
        ClaimJob { state: ClaimState::Prepared, proof, transaction: None, inclusion: None };
    store.save(&job)?;
    let tx = transport.sign(identity, &job.proof).await?;
    tx.validate(identity, &job.proof)?;
    job.transaction = Some(tx);
    job.state = ClaimState::Signed;
    store.save(&job)?;
    reconcile(store, source, transport, job).await
}

/// Reconcile receipt, claimed bit, canonical hash and nonces before identical-byte retransmission.
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
    let claimed = source.claimed(store.identity().batch_id).await?;
    let receipt = transport.receipt(tx.hash).await?;
    if let Some(receipt) = receipt {
        if receipt.transaction_hash != tx.hash {
            return Err(LanderError::Safety("claim receipt identity mismatch".into()));
        }
        if source.canonical_hash(receipt.block_number).await? == receipt.block_hash {
            if !receipt.success {
                return Err(LanderError::Safety(
                    "claim transaction reverted; signed nonce retained for operator review".into(),
                ));
            }
            if !claimed {
                return Err(LanderError::Safety(
                    "successful claim receipt without canonical claimed bit".into(),
                ));
            }
            job.state = ClaimState::Included;
            job.inclusion = Some(receipt);
            store.save(&job)?;
            if source.transaction_finalized(&receipt).await? {
                job.state = ClaimState::Finalized;
                store.save(&job)?;
            }
            return Ok(ClaimOutcome::State(job.state));
        }
    }
    // A disappearing or orphaned receipt must never discard the signed transaction.
    if job.inclusion.is_some() {
        job.state = ClaimState::Pending;
        job.inclusion = None;
        store.save(&job)?;
    }
    let nonce = transport.nonce().await?;
    nonce.validate()?;
    if claimed {
        return Err(LanderError::Safety("reward already claimed but this transaction has no canonical receipt; retain nonce for operator reconciliation".into()));
    }
    if nonce.confirmed > tx.nonce {
        return Err(LanderError::Safety(
            "claim nonce consumed without its canonical receipt; no automatic replacement".into(),
        ));
    }
    let known = transport.known(tx.hash).await?;
    if nonce.confirmed < tx.nonce || nonce.pending > tx.nonce || known {
        return Ok(ClaimOutcome::State(job.state));
    }
    job.state = ClaimState::Pending;
    store.save(&job)?;
    transport.broadcast(&tx).await?;
    Ok(ClaimOutcome::State(ClaimState::Pending))
}
