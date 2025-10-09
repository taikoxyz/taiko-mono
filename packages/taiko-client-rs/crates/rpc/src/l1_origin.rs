//! Public L1 origin RPC helpers for the execution engine.

use std::borrow::Cow;

use alethia_reth::payload::attributes::RpcL1Origin;
use alloy_primitives::U256;
use alloy_provider::Provider;

pub type L1Origin = RpcL1Origin;

use crate::{client::Client, error::Result};

/// Engine RPC method names used for L1 origin queries.
#[derive(Debug, Clone, Copy)]
pub enum TaikoOriginMethod {
    /// `taiko_l1OriginByID`
    L1OriginById,
    /// `taiko_headL1Origin`
    HeadL1Origin,
    /// `taiko_lastL1OriginByBatchID`
    LastL1OriginByBatchId,
}

impl TaikoOriginMethod {
    /// Return the RPC method string for the variant.
    pub const fn as_str(&self) -> &'static str {
        match self {
            Self::L1OriginById => "taiko_l1OriginByID",
            Self::HeadL1Origin => "taiko_headL1Origin",
            Self::LastL1OriginByBatchId => "taiko_lastL1OriginByBatchID",
        }
    }
}

impl<P: Provider + Clone> Client<P> {
    /// Fetch the L1 origin payload for the given block id via the public engine API.
    pub async fn l1_origin_by_id(&self, block_id: U256) -> Result<Option<L1Origin>> {
        self.l2_provider
            .raw_request(Cow::Borrowed(TaikoOriginMethod::L1OriginById.as_str()), (block_id,))
            .await
            .map_err(Into::into)
    }

    /// Fetch the latest head L1 origin pointer from the public engine API.
    pub async fn head_l1_origin(&self) -> Result<Option<L1Origin>> {
        self.l2_provider
            .raw_request(Cow::Borrowed(TaikoOriginMethod::HeadL1Origin.as_str()), ())
            .await
            .map_err(Into::into)
    }

    /// Fetch the last L1 origin associated with the given batch id via the public engine API.
    pub async fn last_l1_origin_by_batch_id(&self, proposal_id: U256) -> Result<Option<L1Origin>> {
        self.l2_provider
            .raw_request(
                Cow::Borrowed(TaikoOriginMethod::LastL1OriginByBatchId.as_str()),
                (proposal_id,),
            )
            .await
            .map_err(Into::into)
    }
}
