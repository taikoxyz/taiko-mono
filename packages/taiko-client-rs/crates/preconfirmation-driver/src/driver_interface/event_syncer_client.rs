//! Event syncer-backed driver client for runner integration.

use std::sync::Arc;

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::U256;
use alloy_provider::Provider;
use async_trait::async_trait;
use bindings::inbox::Inbox::InboxInstance;
use driver::{DriverError, PreconfPayload, sync::event::EventSyncer};
use preconfirmation_types::uint256_to_u256;
use tracing::info;

use crate::{
    Result,
    driver_interface::{DriverClient, PreconfirmationInput},
    error::{DriverApiError, PreconfirmationClientError},
};

use super::{BlockHeaderProvider, payload::build_taiko_payload_attributes};

/// Provides L2 tip lookups for the driver client.
#[async_trait]
pub trait TipProvider: Send + Sync {
    /// Returns the L2 safe tip block number.
    async fn safe_tip(&self) -> Result<U256>;
    /// Returns the L2 latest tip block number.
    async fn latest_tip(&self) -> Result<U256>;
}

async fn block_by_tag<P>(provider: &P, tag: BlockNumberOrTag) -> Result<U256>
where
    P: Provider + Send + Sync,
{
    let block = provider.get_block_by_number(tag).await.map_err(DriverApiError::from)?.ok_or_else(
        || match tag {
            BlockNumberOrTag::Safe => DriverApiError::MissingSafeBlock,
            BlockNumberOrTag::Latest => DriverApiError::MissingLatestBlock,
            _ => DriverApiError::MissingLatestBlock,
        },
    )?;
    Ok(U256::from(block.number()))
}

#[async_trait]
impl<P> TipProvider for P
where
    P: Provider + Send + Sync,
{
    /// Get the current L2 safe tip block number.
    async fn safe_tip(&self) -> Result<U256> {
        block_by_tag(self, BlockNumberOrTag::Safe).await
    }

    /// Get the current L2 latest tip block number.
    async fn latest_tip(&self) -> Result<U256> {
        block_by_tag(self, BlockNumberOrTag::Latest).await
    }
}

/// Combined provider interface for L2 header + tip lookups.
pub trait L2Provider: BlockHeaderProvider + TipProvider {}

impl<T> L2Provider for T where T: BlockHeaderProvider + TipProvider {}

/// Minimal interface needed from the driver event syncer.
#[async_trait]
pub trait PreconfirmationIngress: Send + Sync {
    /// Submit a preconfirmation payload to the ingress queue.
    async fn submit_preconfirmation_payload(
        &self,
        payload: PreconfPayload,
    ) -> std::result::Result<(), DriverError>;

    /// Subscribe to canonical proposal id updates.
    fn subscribe_proposal_id(&self) -> tokio::sync::watch::Receiver<u64>;
}

#[async_trait]
impl<P> PreconfirmationIngress for EventSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Submit a preconfirmation payload to the ingress queue.
    async fn submit_preconfirmation_payload(
        &self,
        payload: PreconfPayload,
    ) -> std::result::Result<(), DriverError> {
        self.submit_preconfirmation_payload(payload).await
    }

    /// Subscribe to canonical proposal id updates.
    fn subscribe_proposal_id(&self) -> tokio::sync::watch::Receiver<u64> {
        self.subscribe_proposal_id()
    }
}

/// Driver client that submits payloads directly to an in-process EventSyncer.
pub struct EventSyncerDriverClient<E, P>
where
    E: PreconfirmationIngress + 'static,
    P: Provider + Clone + Send + Sync + 'static,
{
    event_syncer: Arc<E>,
    inbox: InboxInstance<P>,
    l2_provider: Arc<dyn L2Provider + Send + Sync>,
}

impl<E, P> EventSyncerDriverClient<E, P>
where
    E: PreconfirmationIngress + 'static,
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build a driver client from the provided components.
    pub fn new_with_components(
        event_syncer: Arc<E>,
        inbox: InboxInstance<P>,
        l2_provider: Arc<dyn L2Provider + Send + Sync>,
    ) -> Self {
        Self { event_syncer, inbox, l2_provider }
    }
}

impl<P> EventSyncerDriverClient<EventSyncer<P>, P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build a driver client from an EventSyncer and RPC client bundle.
    pub fn from_client(event_syncer: Arc<EventSyncer<P>>, client: rpc::client::Client<P>) -> Self {
        let l2_provider = client.l2_provider.clone();
        let l2_provider: Arc<dyn L2Provider + Send + Sync> = Arc::new(l2_provider);
        Self::new_with_components(event_syncer, client.shasta.inbox, l2_provider)
    }
}

#[async_trait]
impl<E, P> DriverClient for EventSyncerDriverClient<E, P>
where
    E: PreconfirmationIngress + 'static,
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Submit a preconfirmation commitment payload to the driver.
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()> {
        let preconf = &input.commitment.commitment.preconf;
        let block_number = uint256_to_u256(&preconf.block_number).to::<u64>();
        let proposal_id = uint256_to_u256(&preconf.proposal_id).to::<u64>();

        if input.should_skip_driver_submission() {
            tracing::debug!(block_number, proposal_id, "skipping EOP-only preconfirmation");
            return Ok(());
        }

        let config = self.inbox.getConfig().call().await.map_err(DriverApiError::from)?;
        let payload = build_taiko_payload_attributes(
            &input,
            config.basefeeSharingPctg,
            self.l2_provider.as_ref(),
        )
        .await?;

        self.event_syncer
            .submit_preconfirmation_payload(PreconfPayload::new(payload))
            .await
            .map_err(|err| {
                PreconfirmationClientError::DriverInterface(DriverApiError::ChannelClosed(
                    err.to_string(),
                ))
            })?;

        info!(block_number, proposal_id, "submitted preconfirmation payload");
        Ok(())
    }

    /// Wait for the event syncer to catch up with L1 inbox events.
    async fn wait_event_sync(&self) -> Result<()> {
        info!("starting wait for driver to sync with L1 inbox events");

        let mut rx = self.event_syncer.subscribe_proposal_id();
        loop {
            let last = *rx.borrow();
            let core_state =
                self.inbox.getCoreState().call().await.map_err(DriverApiError::from)?;
            let next = core_state.nextProposalId.to::<u64>();

            tracing::debug!(
                last_canonical_proposal_id = last,
                next_proposal_id = next,
                "checking sync"
            );

            if next == 0 {
                info!("sync complete (no proposals)");
                return Ok(());
            }

            let target = next.saturating_sub(1);
            if last >= target {
                info!("driver event sync complete");
                return Ok(());
            }

            if rx.changed().await.is_err() {
                return Err(DriverApiError::ChannelClosed(
                    "proposal id watch channel closed".to_string(),
                )
                .into());
            }
        }
    }

    /// Get the current event syncer tip block number.
    async fn event_sync_tip(&self) -> Result<U256> {
        self.l2_provider.safe_tip().await
    }

    /// Get the current preconfirmation tip block number.
    async fn preconf_tip(&self) -> Result<U256> {
        self.l2_provider.latest_tip().await
    }
}

#[cfg(test)]
mod tests {
    use std::sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    };

    use alloy_primitives::{Address, U256};
    use alloy_provider::ProviderBuilder;
    use alloy_rpc_types::Header as RpcHeader;
    use alloy_transport::mock::Asserter;

    use super::{EventSyncerDriverClient, PreconfirmationIngress, TipProvider};
    use crate::{
        driver_interface::{DriverClient, PreconfirmationInput},
        error::DriverApiError,
    };
    use preconfirmation_types::{
        Bytes32, Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment,
    };

    struct StubL2Provider {
        safe: U256,
        latest: U256,
    }

    #[async_trait::async_trait]
    impl TipProvider for StubL2Provider {
        async fn safe_tip(&self) -> crate::Result<U256> {
            Ok(self.safe)
        }

        async fn latest_tip(&self) -> crate::Result<U256> {
            Ok(self.latest)
        }
    }

    #[async_trait::async_trait]
    impl super::BlockHeaderProvider for StubL2Provider {
        async fn header_by_number(&self, block_number: u64) -> crate::Result<RpcHeader> {
            Err(DriverApiError::MissingBlock { block_number }.into())
        }
    }

    struct FakeIngress {
        submits: Arc<AtomicUsize>,
    }

    #[async_trait::async_trait]
    impl PreconfirmationIngress for FakeIngress {
        async fn submit_preconfirmation_payload(
            &self,
            _payload: driver::PreconfPayload,
        ) -> std::result::Result<(), driver::DriverError> {
            self.submits.fetch_add(1, Ordering::SeqCst);
            Ok(())
        }

        fn subscribe_proposal_id(&self) -> tokio::sync::watch::Receiver<u64> {
            let (_tx, rx) = tokio::sync::watch::channel(0u64);
            rx
        }
    }

    #[tokio::test]
    async fn event_syncer_driver_client_reads_tip_provider() {
        let asserter = Asserter::new();
        let provider = ProviderBuilder::new().connect_mocked_client(asserter);
        let inbox = bindings::inbox::Inbox::InboxInstance::new(Address::ZERO, provider.clone());

        let client = EventSyncerDriverClient::new_with_components(
            Arc::new(FakeIngress { submits: Arc::new(AtomicUsize::new(0)) }),
            inbox,
            Arc::new(StubL2Provider { safe: U256::from(10), latest: U256::from(12) }),
        );

        assert_eq!(client.event_sync_tip().await.unwrap(), U256::from(10));
        assert_eq!(client.preconf_tip().await.unwrap(), U256::from(12));
    }

    struct NoopL2Provider;

    #[async_trait::async_trait]
    impl TipProvider for NoopL2Provider {
        async fn safe_tip(&self) -> crate::Result<U256> {
            Ok(U256::ZERO)
        }

        async fn latest_tip(&self) -> crate::Result<U256> {
            Ok(U256::ZERO)
        }
    }

    #[async_trait::async_trait]
    impl super::BlockHeaderProvider for NoopL2Provider {
        async fn header_by_number(&self, block_number: u64) -> crate::Result<RpcHeader> {
            Err(DriverApiError::MissingBlock { block_number }.into())
        }
    }

    #[tokio::test]
    async fn event_syncer_driver_client_skips_eop_only_submission() {
        let asserter = Asserter::new();
        let provider = ProviderBuilder::new().connect_mocked_client(asserter);
        let inbox = bindings::inbox::Inbox::InboxInstance::new(Address::ZERO, provider.clone());

        let submits = Arc::new(AtomicUsize::new(0));
        let client = EventSyncerDriverClient::new_with_components(
            Arc::new(FakeIngress { submits: submits.clone() }),
            inbox,
            Arc::new(NoopL2Provider),
        );

        let zero_hash = Bytes32::try_from(vec![0u8; 32]).expect("zero hash");
        let preconf =
            Preconfirmation { eop: true, raw_tx_list_hash: zero_hash, ..Default::default() };
        let commitment = SignedCommitment {
            commitment: PreconfCommitment { preconf, ..Default::default() },
            signature: Bytes65::try_from(vec![0u8; 65]).expect("signature"),
        };
        let input = PreconfirmationInput::new(commitment, None, None);

        client.submit_preconfirmation(input).await.unwrap();
        assert_eq!(submits.load(Ordering::SeqCst), 0);
    }
}
