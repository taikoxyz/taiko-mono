//! Public L1 origin RPC helpers for the execution engine.

use alethia_reth_primitives::payload::attributes::RpcL1Origin;
use alloy_primitives::U256;
use alloy_provider::Provider;

/// Public alias for execution-engine L1 origin payloads.
pub type L1Origin = RpcL1Origin;

/// Engine-compatible transport wrapper for [`RpcL1Origin`].
pub(crate) use alethia_reth_primitives::payload::attributes::EngineRpcL1Origin;

use crate::{client::Client, error::Result};

impl<P: Provider + Clone> Client<P> {
    /// Fetch the L1 origin payload for the given block id via the public engine API.
    pub async fn l1_origin_by_id(&self, block_id: U256) -> Result<Option<L1Origin>> {
        Self::request_l1_origin(&self.l2_provider, "taiko_l1OriginByID", (block_id,)).await
    }

    /// Fetch the latest head L1 origin pointer from the public engine API.
    pub async fn head_l1_origin(&self) -> Result<Option<L1Origin>> {
        Self::request_l1_origin(&self.l2_provider, "taiko_headL1Origin", ())
            .await
    }
}
