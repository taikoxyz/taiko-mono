//! Preconfirmation engine adapter used by the P2P sidecar.

use std::{collections::BTreeMap, sync::Arc};

use alloy::{eips::BlockNumberOrTag, primitives::B256, providers::Provider};
use alloy_rpc_types::Transaction as RpcTransaction;
use async_trait::async_trait;
use preconfirmation_types::SignedCommitment;
use rpc::{
    client::Client,
    engine::{EngineApplyOutcome, EngineError, EngineHead, PreconfEngine},
};
use tokio::sync::Mutex;

use crate::{
    p2p_sidecar::types::PendingPreconf,
    production::PreconfPayload,
    sync::{
        engine::{PreconfEngineConfig, build_execution_payload_input, uint256_to_u64},
        event::EventSyncer,
    },
};

/// Preconfirmation engine adapter that feeds payloads into the driver preconfirmation path.
pub struct SidecarPreconfEngine<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// RPC client used for engine interactions.
    rpc: Client<P>,
    /// Driver preconfirmation builder used to derive payload attributes.
    builder: crate::sync::engine::DriverPreconfEngine,
    /// Event syncer used to submit preconfirmation payloads.
    event_syncer: Arc<EventSyncer<P>>,
    /// Pending preconfirmation map keyed by block number.
    pending: Arc<Mutex<BTreeMap<u64, PendingPreconf>>>,
}

impl<P> SidecarPreconfEngine<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Construct a new sidecar preconfirmation engine.
    pub async fn new(
        rpc: Client<P>,
        event_syncer: Arc<EventSyncer<P>>,
        pending: Arc<Mutex<BTreeMap<u64, PendingPreconf>>>,
    ) -> Result<Self, EngineError> {
        // Default preconfirmation engine config for payload construction.
        let config = PreconfEngineConfig::default();
        // Driver preconfirmation builder to derive payload attributes.
        let builder = crate::sync::engine::DriverPreconfEngine::new(rpc.clone(), config).await?;
        Ok(Self { rpc, builder, event_syncer, pending })
    }

    /// Return a shared reference to the pending preconfirmation map.
    pub fn pending_map(&self) -> Arc<Mutex<BTreeMap<u64, PendingPreconf>>> {
        self.pending.clone()
    }
}

#[async_trait]
impl<P> PreconfEngine for SidecarPreconfEngine<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Return the current execution engine head from the RPC provider.
    async fn engine_head(&self) -> Result<EngineHead, EngineError> {
        // Latest L2 block from the RPC provider.
        let latest = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(|err| EngineError::Unavailable(err.to_string()))?;
        // Ensure the latest block exists.
        let latest =
            latest.ok_or_else(|| EngineError::Other("latest L2 block unavailable".to_string()))?;
        // Convert transactions into the expected envelope for header access.
        let block: alloy_rpc_types::Block<alloy_consensus::TxEnvelope> =
            latest.map_transactions(|tx: RpcTransaction| tx.into());
        Ok(EngineHead { block_number: block.header.number, block_hash: block.header.hash })
    }

    /// Report whether the execution engine has finished syncing.
    async fn is_synced(&self) -> Result<bool, EngineError> {
        // Sync status from the L2 provider.
        let status = self
            .rpc
            .l2_provider
            .syncing()
            .await
            .map_err(|err| EngineError::Unavailable(err.to_string()))?;
        Ok(matches!(status, alloy_rpc_types::SyncStatus::None))
    }

    /// Apply a preconfirmation commitment by injecting it into the preconfirmation path.
    async fn apply_commitment(
        &self,
        commitment: &SignedCommitment,
        txlist: Option<&[u8]>,
    ) -> Result<EngineApplyOutcome, EngineError> {
        // Commitment payload body.
        let preconf = &commitment.commitment.preconf;
        // Block number derived from the commitment.
        let block_number = uint256_to_u64(&preconf.block_number)?;
        // Flag indicating a zero txlist hash.
        let is_zero_hash = preconf.raw_tx_list_hash.as_ref().iter().all(|byte| *byte == 0);

        if preconf.eop && txlist.is_none() && is_zero_hash {
            return Ok(EngineApplyOutcome { block_number, block_hash: B256::ZERO });
        }

        // Built payload attributes + parent metadata for the commitment.
        let built = self.builder.build_preconf_payload(commitment, txlist).await?;
        // Execution payload input built from engine payload attributes.
        let payload_input =
            build_execution_payload_input(&self.rpc, &built.payload, built.parent_hash).await?;
        // Block hash from the execution payload.
        let block_hash = payload_input.execution_payload.block_hash;
        // Preconfirmation payload wrapper for driver ingestion.
        let preconf_payload = PreconfPayload::new(payload_input);
        // Submit the preconfirmation payload through the event syncer.
        self.event_syncer
            .submit_preconfirmation_payload(preconf_payload)
            .await
            .map_err(|err| EngineError::Other(err.to_string()))?;
        // Submission window end timestamp converted to u64.
        let submission_window_end = uint256_to_u64(&preconf.submission_window_end)?;
        // Pending preconfirmation entry inserted after successful submission.
        let pending_entry = PendingPreconf { block_hash, submission_window_end };
        // Pending map guard for mutation.
        let mut pending = self.pending.lock().await;
        // Track the pending preconfirmation by block number.
        pending.insert(block_number, pending_entry);
        Ok(EngineApplyOutcome { block_number, block_hash })
    }

    /// Handle an L1 reorg affecting the given anchor block number.
    async fn handle_reorg(&self, _anchor_block_number: u64) -> Result<(), EngineError> {
        // Pending map guard for clearing entries.
        let mut pending = self.pending.lock().await;
        // Clear all pending preconfirmations on reorg.
        pending.clear();
        Ok(())
    }
}
