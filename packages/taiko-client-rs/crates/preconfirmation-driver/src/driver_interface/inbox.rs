//! Inbox-backed reader implementation for L1 sync state.

use alloy_primitives::U256;
use alloy_provider::Provider;
use async_trait::async_trait;
use rpc::client::Client;

use crate::error::{DriverApiError, Result};

use super::traits::InboxReader;

/// Real implementation of InboxReader using the Inbox contract bindings.
#[derive(Clone)]
pub struct ContractInboxReader<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// RPC client bundle used for inbox/core-state and L2 custom table reads.
    client: Client<P>,
}

impl<P> ContractInboxReader<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Creates a new ContractInboxReader with the given RPC client.
    pub fn new(client: Client<P>) -> Self {
        Self { client }
    }
}

#[async_trait]
impl<P> InboxReader for ContractInboxReader<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Fetches the next proposal ID from the L1 Inbox contract.
    async fn get_next_proposal_id(&self) -> Result<u64> {
        Ok(self
            .client
            .shasta
            .inbox
            .getCoreState()
            .call()
            .await
            .map_err(DriverApiError::from)?
            .nextProposalId
            .to::<u64>())
    }

    /// Fetches the batch-to-last-block mapping for the given proposal ID.
    async fn get_last_block_id_by_batch_id(&self, proposal_id: u64) -> Result<Option<u64>> {
        Ok(self
            .client
            .last_block_id_by_batch_id(U256::from(proposal_id))
            .await
            .map_err(DriverApiError::from)?
            .map(|block_id| block_id.to::<u64>()))
    }

    /// Fetches the confirmed event-sync tip from `head_l1_origin`.
    async fn get_head_l1_origin_block_id(&self) -> Result<Option<u64>> {
        Ok(self
            .client
            .head_l1_origin()
            .await
            .map_err(DriverApiError::from)?
            .map(|head_l1_origin| head_l1_origin.block_id.to::<u64>()))
    }
}
