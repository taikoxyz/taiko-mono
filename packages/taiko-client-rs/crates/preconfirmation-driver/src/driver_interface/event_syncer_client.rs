//! Event syncer-backed driver client for runner integration.

use std::{sync::Arc, time::Duration};

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::U256;
use alloy_provider::Provider;
use async_trait::async_trait;
use bindings::inbox::Inbox::InboxInstance;
use driver::{
    DriverError, PreconfPayload,
    sync::{ConfirmedSyncSnapshot, event::EventSyncer},
};
use preconfirmation_types::uint256_to_u256;
use tracing::info;

use crate::{
    Result,
    driver_interface::{DriverClient, PreconfirmationInput},
    error::{DriverApiError, PreconfirmationClientError},
};

use super::{
    BlockHeaderProvider,
    payload::build_taiko_payload_attributes,
    traits::{DEFAULT_WAIT_EVENT_SYNC_POLL_INTERVAL, wait_for_confirmed_sync},
};

/// Provides L2 tip lookups for the driver client.
#[async_trait]
pub trait TipProvider: Send + Sync {
    /// Returns the L2 latest tip block number.
    async fn latest_tip(&self) -> Result<U256>;
}

async fn latest_block_by_tag<P>(provider: &P) -> Result<U256>
where
    P: Provider + Send + Sync,
{
    let block = provider
        .get_block_by_number(BlockNumberOrTag::Latest)
        .await
        .map_err(DriverApiError::from)?
        .ok_or(DriverApiError::MissingLatestBlock)?;
    Ok(U256::from(block.number()))
}

#[async_trait]
impl<P> TipProvider for P
where
    P: Provider + Send + Sync,
{
    /// Get the current L2 latest tip block number.
    async fn latest_tip(&self) -> Result<U256> {
        latest_block_by_tag(self).await
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

    /// Return strict confirmed-sync state derived from inbox core state + custom tables.
    async fn confirmed_sync_snapshot(
        &self,
    ) -> std::result::Result<ConfirmedSyncSnapshot, DriverError>;
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

    /// Return strict confirmed-sync state derived from inbox core state + custom tables.
    async fn confirmed_sync_snapshot(
        &self,
    ) -> std::result::Result<ConfirmedSyncSnapshot, DriverError> {
        EventSyncer::confirmed_sync_snapshot(self).await.map_err(DriverError::from)
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
    wait_event_sync_poll_interval: Duration,
}

impl<E, P> EventSyncerDriverClient<E, P>
where
    E: PreconfirmationIngress + 'static,
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build a driver client from the provided components and poll interval.
    pub fn new_with_components_and_poll_interval(
        event_syncer: Arc<E>,
        inbox: InboxInstance<P>,
        l2_provider: Arc<dyn L2Provider + Send + Sync>,
        wait_event_sync_poll_interval: Duration,
    ) -> Self {
        Self { event_syncer, inbox, l2_provider, wait_event_sync_poll_interval }
    }

    /// Build a driver client from the provided components.
    pub fn new_with_components(
        event_syncer: Arc<E>,
        inbox: InboxInstance<P>,
        l2_provider: Arc<dyn L2Provider + Send + Sync>,
    ) -> Self {
        Self::new_with_components_and_poll_interval(
            event_syncer,
            inbox,
            l2_provider,
            DEFAULT_WAIT_EVENT_SYNC_POLL_INTERVAL,
        )
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
        Self::new_with_components_and_poll_interval(
            event_syncer,
            client.shasta.inbox,
            l2_provider,
            DEFAULT_WAIT_EVENT_SYNC_POLL_INTERVAL,
        )
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
                PreconfirmationClientError::DriverInterface(DriverApiError::Driver(err))
            })?;

        info!(block_number, proposal_id, "submitted preconfirmation payload");
        Ok(())
    }

    /// Wait for the event syncer to catch up with L1 inbox events.
    async fn wait_event_sync(&self) -> Result<()> {
        info!("starting wait for driver to sync with L1 inbox events");
        wait_for_confirmed_sync(
            || async {
                self.event_syncer.confirmed_sync_snapshot().await.map_err(DriverApiError::Driver)
            },
            self.wait_event_sync_poll_interval,
        )
        .await?;
        info!("driver event sync complete");
        Ok(())
    }

    /// Get the current event syncer tip block number.
    async fn event_sync_tip(&self) -> Result<U256> {
        self.event_syncer
            .confirmed_sync_snapshot()
            .await
            .map_err(DriverApiError::Driver)?
            .event_sync_tip()
            .map(U256::from)
            .ok_or(DriverApiError::EventSyncTipUnknown.into())
    }

    /// Get the current preconfirmation tip block number.
    async fn preconf_tip(&self) -> Result<U256> {
        self.l2_provider.latest_tip().await
    }
}

#[cfg(test)]
mod tests {
    use std::{
        sync::{
            Arc,
            atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering},
        },
        time::Duration,
    };

    use alloy_primitives::{Address, U256};
    use alloy_provider::ProviderBuilder;
    use alloy_rpc_types::Header as RpcHeader;
    use alloy_transport::mock::Asserter;
    use driver::sync::ConfirmedSyncSnapshot;

    use super::{EventSyncerDriverClient, PreconfirmationIngress, TipProvider};
    use crate::{
        driver_interface::{DriverClient, PreconfirmationInput},
        error::DriverApiError,
    };
    use preconfirmation_types::{
        Bytes32, Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment,
    };

    struct StubL2Provider {
        latest: U256,
    }

    #[async_trait::async_trait]
    impl TipProvider for StubL2Provider {
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
        ready: Arc<AtomicBool>,
        tip: Arc<AtomicU64>,
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

        async fn confirmed_sync_snapshot(
            &self,
        ) -> std::result::Result<ConfirmedSyncSnapshot, driver::DriverError> {
            let tip = self.tip.load(Ordering::SeqCst);
            let head_l1_origin_block_id = (tip != u64::MAX).then_some(tip);
            let target_block =
                if self.ready.load(Ordering::SeqCst) { Some(0) } else { Some(u64::MAX - 1) };
            Ok(ConfirmedSyncSnapshot::new(1, target_block, head_l1_origin_block_id))
        }
    }

    #[tokio::test]
    async fn event_syncer_driver_client_reads_tip_provider() {
        let asserter = Asserter::new();
        let provider = ProviderBuilder::new().connect_mocked_client(asserter);
        let inbox = bindings::inbox::Inbox::InboxInstance::new(Address::ZERO, provider.clone());

        let client = EventSyncerDriverClient::new_with_components(
            Arc::new(FakeIngress {
                submits: Arc::new(AtomicUsize::new(0)),
                ready: Arc::new(AtomicBool::new(true)),
                tip: Arc::new(AtomicU64::new(7)),
            }),
            inbox,
            Arc::new(StubL2Provider { latest: U256::from(12) }),
        );

        assert_eq!(client.event_sync_tip().await.unwrap(), U256::from(7));
        assert_eq!(client.preconf_tip().await.unwrap(), U256::from(12));
    }

    #[tokio::test]
    async fn event_syncer_driver_client_returns_error_when_tip_unknown() {
        let asserter = Asserter::new();
        let provider = ProviderBuilder::new().connect_mocked_client(asserter);
        let inbox = bindings::inbox::Inbox::InboxInstance::new(Address::ZERO, provider);

        let client = EventSyncerDriverClient::new_with_components(
            Arc::new(FakeIngress {
                submits: Arc::new(AtomicUsize::new(0)),
                ready: Arc::new(AtomicBool::new(false)),
                tip: Arc::new(AtomicU64::new(u64::MAX)),
            }),
            inbox,
            Arc::new(StubL2Provider { latest: U256::ZERO }),
        );

        let err = client
            .event_sync_tip()
            .await
            .expect_err("unknown event sync tip should return explicit error");
        assert!(matches!(
            err,
            crate::PreconfirmationClientError::DriverInterface(DriverApiError::EventSyncTipUnknown)
        ));
    }

    struct NoopL2Provider;

    #[async_trait::async_trait]
    impl TipProvider for NoopL2Provider {
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
            Arc::new(FakeIngress {
                submits: submits.clone(),
                ready: Arc::new(AtomicBool::new(true)),
                tip: Arc::new(AtomicU64::new(0)),
            }),
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

    #[tokio::test]
    async fn event_syncer_driver_client_waits_until_confirmed_sync_ready() {
        let asserter = Asserter::new();
        let provider = ProviderBuilder::new().connect_mocked_client(asserter);
        let inbox = bindings::inbox::Inbox::InboxInstance::new(Address::ZERO, provider.clone());

        let ready = Arc::new(AtomicBool::new(false));
        let client = EventSyncerDriverClient::new_with_components_and_poll_interval(
            Arc::new(FakeIngress {
                submits: Arc::new(AtomicUsize::new(0)),
                ready: ready.clone(),
                tip: Arc::new(AtomicU64::new(5)),
            }),
            inbox,
            Arc::new(NoopL2Provider),
            Duration::from_millis(10),
        );

        let wait_handle = tokio::spawn(async move { client.wait_event_sync().await });

        tokio::time::sleep(Duration::from_millis(20)).await;
        ready.store(true, Ordering::SeqCst);

        tokio::time::timeout(Duration::from_millis(500), wait_handle)
            .await
            .expect("wait_event_sync should complete")
            .expect("wait handle should join")
            .expect("wait_event_sync should return ok");
    }
}
