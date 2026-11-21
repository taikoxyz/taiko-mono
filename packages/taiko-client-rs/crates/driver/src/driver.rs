//! High level driver orchestration.

use std::path::Path;

use alloy_primitives::B256;
use tracing::{info, instrument};

use crate::{config::DriverConfig, error::Result, sync::SyncPipeline};
use rpc::client::Client;

/// Final confirmed Unzen block and the finalized L1 snapshot proving proposal closure.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct UnzenOrigin {
    /// Number of the finalized L1 block whose timestamp reached the Etna fork.
    pub finalized_l1_number: u64,
    /// Hash used to pin the closing Inbox core-state read.
    pub finalized_l1_hash: B256,
    /// Height of the last confirmed block of the closing Unzen proposal.
    pub height: u64,
    /// Canonical local execution hash at `height`.
    pub hash: B256,
}

/// Shasta driver responsible for keeping an execution engine in sync with protocol state.
pub struct Driver {
    /// Static configuration loaded at startup.
    cfg: DriverConfig,
    /// RPC client wrapper shared with derivation and sync subsystems.
    rpc: Client,
}

impl Driver {
    /// Construct a driver instance from the provided configuration.
    #[instrument(skip(cfg))]
    pub async fn new(cfg: DriverConfig) -> Result<Self> {
        let rpc = Client::new(cfg.client.clone()).await?;

        Ok(Self { cfg, rpc })
    }

    /// Start the driver until completion.
    #[instrument(skip(self))]
    pub async fn run(&self) -> Result<()> {
        info!(?self.cfg, "starting driver sync pipeline");
        let pipeline = SyncPipeline::new(self.cfg.clone(), self.rpc.clone()).await?;
        pipeline.run().await?;
        Ok(())
    }

    /// Derive Unzen proposals until finalized L1 proves the fork has closed its proposal stream.
    ///
    /// The closing core-state read is pinned to that finalized L1 hash. This mode disables
    /// preconfirmation ingress and returns only between completed serial proposal batches, so
    /// no driver-owned Engine write remains in flight when the caller starts Etna. The caller
    /// exclusively owns `receipt_path`; completion is durably recorded there before returning.
    pub async fn run_until_etna(
        &self,
        fork_timestamp: u64,
        receipt_path: impl AsRef<Path>,
    ) -> Result<UnzenOrigin> {
        let receipt_path = receipt_path.as_ref();
        loop {
            match crate::sync::handoff::try_etna_origin(
                &self.rpc,
                fork_timestamp,
                receipt_path,
                None,
            )
            .await
            {
                Ok(Some(origin)) => return Ok(origin),
                Ok(None) => break,
                Err(
                    error @ (crate::sync::SyncError::InvalidEtnaHandoff(_) |
                    crate::sync::SyncError::EtnaReceipt(_)),
                ) => return Err(error.into()),
                Err(error) => {
                    tracing::warn!(%error, "finalized Unzen closure is unavailable; retrying startup");
                    tokio::time::sleep(
                        self.cfg.retry_interval.max(std::time::Duration::from_secs(1)),
                    )
                    .await;
                }
            }
        }
        let mut cfg = self.cfg.clone();
        cfg.preconfirmation_enabled = false;
        let pipeline = SyncPipeline::new(cfg, self.rpc.clone()).await?;
        pipeline.run_until_etna(fork_timestamp, receipt_path).await
    }

    /// Access the underlying RPC client (primarily for tests).
    pub fn rpc_client(&self) -> &Client {
        &self.rpc
    }
}
