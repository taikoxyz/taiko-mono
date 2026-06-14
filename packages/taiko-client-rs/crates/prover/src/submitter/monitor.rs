//! Background monitors: forced buffer aggregation and stale-cache cleanup
//! (Go `proof_submitter/proof_buffer_monitor.go`).

use std::{sync::Arc, time::Duration};

use rpc::{RpcClientError, client::ClientWithWallet};
use tokio::sync::mpsc::Sender;

use crate::{
    buffer::ProofBuffer, cache::ProofCache, raiko::ProofType, submitter::submitter::Pipeline,
};

/// Monitor tick interval (Go `monitorInterval` = 1 minute).
pub const MONITOR_INTERVAL: Duration = Duration::from_secs(60);

/// Spawn one forced-aggregation monitor per buffer plus one cache-cleanup
/// monitor. Each monitor ticks every `interval` until aborted.
pub fn spawn_monitors(pipeline: Arc<Pipeline>, rpc: Arc<ClientWithWallet>, interval: Duration) {
    for (proof_type, buffer) in pipeline.buffers() {
        tokio::spawn(monitor_buffer(pipeline.clone(), *proof_type, buffer.clone(), interval));
    }

    let flush_cache_tx = pipeline.flush_cache_sender();
    let caches: Vec<(ProofType, Arc<ProofCache>)> =
        pipeline.caches().iter().map(|(ty, cache)| (*ty, cache.clone())).collect();
    tokio::spawn(monitor_caches(rpc, caches, flush_cache_tx, interval));
}

/// Periodically force-aggregate a single buffer (Go `monitorProofBuffer`).
async fn monitor_buffer(
    pipeline: Arc<Pipeline>,
    proof_type: ProofType,
    buffer: Arc<ProofBuffer>,
    interval: Duration,
) {
    let mut ticker = tokio::time::interval(interval);
    ticker.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    loop {
        ticker.tick().await;
        pipeline.try_aggregate(&buffer, proof_type);
    }
}

/// Periodically prune finalized cache entries and nudge a flush
/// (Go `cleanUpStaleCacheAndFlush`).
async fn monitor_caches(
    rpc: Arc<ClientWithWallet>,
    caches: Vec<(ProofType, Arc<ProofCache>)>,
    flush_cache_tx: Sender<ProofType>,
    interval: Duration,
) {
    let mut ticker = tokio::time::interval(interval);
    ticker.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    loop {
        ticker.tick().await;
        let last_finalized = match read_last_finalized(&rpc).await {
            Ok(id) => id,
            Err(err) => {
                tracing::error!(%err, "failed to get core state in cache monitor");
                continue;
            }
        };
        for (proof_type, cache) in &caches {
            cache.prune_finalized(last_finalized);
            if !cache.is_empty() {
                let _ = flush_cache_tx.try_send(*proof_type);
            }
        }
    }
}

/// Read `lastFinalizedProposalId` for the cache monitor.
async fn read_last_finalized(rpc: &ClientWithWallet) -> Result<u64, RpcClientError> {
    Ok(rpc.core_state().await?.last_finalized_proposal_id)
}
