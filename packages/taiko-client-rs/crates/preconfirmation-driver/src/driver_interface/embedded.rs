//! Embedded driver client for direct in-process communication via channels.

use std::sync::Arc;
use std::time::Duration;

use alloy_primitives::U256;
use alloy_provider::Provider;
use async_trait::async_trait;
use rpc::client::Client;
use tokio::sync::{Mutex, mpsc, watch};
use tracing::{info, warn};

use crate::error::{DriverApiError, Result};

use super::{
    PreconfirmationInput,
    traits::{
        DEFAULT_WAIT_EVENT_SYNC_POLL_INTERVAL, DriverClient, InboxReader, wait_for_confirmed_sync,
    },
};

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

/// A driver client that communicates directly with an embedded driver via channels.
///
/// This client bypasses JSON-RPC serialization overhead by using Tokio channels
/// for direct in-process communication with the driver.
///
/// The `I` type parameter represents the inbox reader implementation, which allows
/// the client to check L1 Inbox state for sync alignment.
#[derive(Clone)]
pub struct EmbeddedDriverClient<I: InboxReader> {
    /// Channel for sending preconfirmation inputs to the driver.
    input_tx: mpsc::Sender<PreconfirmationInput>,
    /// Watch channel for receiving the latest preconfirmation tip from the driver.
    preconf_tip_rx: watch::Receiver<U256>,
    /// Inbox reader for checking L1 sync state.
    inbox_reader: I,
    /// Poll interval for `wait_event_sync`.
    wait_event_sync_poll_interval: Duration,
    /// Cached next_proposal_id for fallback during transient L1 failures.
    /// Only the L1 contract call is cached — L2 engine calls are always executed live.
    cached_next_proposal_id: Arc<Mutex<Option<u64>>>,
}

impl<I: InboxReader> EmbeddedDriverClient<I> {
    /// Creates a new embedded driver client with the given channels and inbox reader.
    pub fn new(
        input_tx: mpsc::Sender<PreconfirmationInput>,
        preconf_tip_rx: watch::Receiver<U256>,
        inbox_reader: I,
    ) -> Self {
        Self::new_with_poll_interval(
            input_tx,
            preconf_tip_rx,
            inbox_reader,
            DEFAULT_WAIT_EVENT_SYNC_POLL_INTERVAL,
        )
    }

    /// Creates a new embedded driver client with a custom `wait_event_sync` poll interval.
    pub fn new_with_poll_interval(
        input_tx: mpsc::Sender<PreconfirmationInput>,
        preconf_tip_rx: watch::Receiver<U256>,
        inbox_reader: I,
        wait_event_sync_poll_interval: Duration,
    ) -> Self {
        Self {
            input_tx,
            preconf_tip_rx,
            inbox_reader,
            wait_event_sync_poll_interval,
            cached_next_proposal_id: Arc::new(Mutex::new(None)),
        }
    }

    /// Returns a reference to the inbox reader.
    pub fn inbox_reader(&self) -> &I {
        &self.inbox_reader
    }

    async fn next_proposal_id_with_cache(&self) -> Result<u64> {
        match self.inbox_reader.get_next_proposal_id().await {
            Ok(id) => {
                *self.cached_next_proposal_id.lock().await = Some(id);
                Ok(id)
            }
            Err(err) => {
                let cached = self.cached_next_proposal_id.lock().await;
                if let Some(cached_id) = *cached {
                    warn!(
                        error = %err,
                        cached_next_proposal_id = cached_id,
                        "L1 unreachable for next_proposal_id, using cached value"
                    );
                    Ok(cached_id)
                } else {
                    Err(err)
                }
            }
        }
    }

    async fn confirmed_sync_snapshot_with_cached_target(
        &self,
    ) -> Result<driver::sync::ConfirmedSyncSnapshot> {
        let target_proposal_id = self.next_proposal_id_with_cache().await?.saturating_sub(1);
        driver::sync::build_confirmed_sync_snapshot(
            target_proposal_id,
            |target| self.inbox_reader.get_last_block_id_by_batch_id(target),
            || self.inbox_reader.get_head_l1_origin_block_id(),
        )
        .await
    }
}

#[async_trait]
impl<I: InboxReader + 'static> DriverClient for EmbeddedDriverClient<I> {
    /// Sends a preconfirmation input to the driver via the channel.
    ///
    /// Returns an error if the rx has been dropped.
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()> {
        self.input_tx
            .send(input)
            .await
            .map_err(|e| DriverApiError::ChannelClosed(e.to_string()))?;
        Ok(())
    }

    /// Waits until the driver has synced with L1 Inbox events.
    ///
    /// This method checks the L1 Inbox contract to determine the target sync state:
    /// - If `nextProposalId - 1 == 0`, returns Ok immediately.
    /// - Otherwise, readiness requires both:
    ///   - `lastBlockIDByBatchID(nextProposalId - 1)` exists
    ///   - `head_l1_origin` exists and `head >= target_block`.
    ///
    /// The L1 target proposal read uses the same cached fallback as `event_sync_tip()` so a
    /// transient L1 outage during startup does not break readiness once a target has been seen.
    async fn wait_event_sync(&self) -> Result<()> {
        info!("starting wait for driver to sync with L1 inbox events");
        wait_for_confirmed_sync(
            || self.confirmed_sync_snapshot_with_cached_target(),
            self.wait_event_sync_poll_interval,
        )
        .await?;
        info!("driver event sync complete");
        Ok(())
    }

    /// Returns the current confirmed event-sync L2 block number.
    ///
    /// The L1 contract call (`get_next_proposal_id`) is attempted first. On failure,
    /// the last known proposal ID is used so that a transient L1 outage does not stall
    /// gossip processing. Local L2 engine calls are always executed and their errors
    /// propagated immediately.
    async fn event_sync_tip(&self) -> Result<U256> {
        let snapshot = self.confirmed_sync_snapshot_with_cached_target().await?;
        super::traits::resolve_event_sync_tip(&snapshot)
    }

    /// Returns the current preconfirmation tip block number.
    async fn preconf_tip(&self) -> Result<U256> {
        Ok(*self.preconf_tip_rx.borrow())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use preconfirmation_types::{Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment};
    use std::sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    };

    const NONE_SENTINEL: u64 = u64::MAX;

    /// Mock inbox reader for testing.
    #[derive(Clone)]
    struct MockInboxReader {
        next_proposal_id: Arc<AtomicU64>,
        target_block: Arc<AtomicU64>,
        head_l1_origin_block_id: Arc<AtomicU64>,
    }

    impl MockInboxReader {
        fn new(
            next_proposal_id: u64,
            target_block: Option<u64>,
            head_l1_origin: Option<u64>,
        ) -> Self {
            Self {
                next_proposal_id: Arc::new(AtomicU64::new(next_proposal_id)),
                target_block: Arc::new(AtomicU64::new(target_block.unwrap_or(NONE_SENTINEL))),
                head_l1_origin_block_id: Arc::new(AtomicU64::new(
                    head_l1_origin.unwrap_or(NONE_SENTINEL),
                )),
            }
        }

        fn set_next_proposal_id(&self, value: u64) {
            self.next_proposal_id.store(value, Ordering::SeqCst);
        }

        fn set_target_block(&self, value: Option<u64>) {
            self.target_block.store(value.unwrap_or(NONE_SENTINEL), Ordering::SeqCst);
        }

        fn set_head_l1_origin(&self, value: Option<u64>) {
            self.head_l1_origin_block_id.store(value.unwrap_or(NONE_SENTINEL), Ordering::SeqCst);
        }

        fn read_optional(value: u64) -> Option<u64> {
            (value != NONE_SENTINEL).then_some(value)
        }
    }

    #[async_trait]
    impl InboxReader for MockInboxReader {
        async fn get_next_proposal_id(&self) -> Result<u64> {
            Ok(self.next_proposal_id.load(Ordering::SeqCst))
        }

        async fn get_last_block_id_by_batch_id(&self, _proposal_id: u64) -> Result<Option<u64>> {
            Ok(Self::read_optional(self.target_block.load(Ordering::SeqCst)))
        }

        async fn get_head_l1_origin_block_id(&self) -> Result<Option<u64>> {
            Ok(Self::read_optional(self.head_l1_origin_block_id.load(Ordering::SeqCst)))
        }
    }

    fn make_client() -> (
        EmbeddedDriverClient<MockInboxReader>,
        mpsc::Receiver<PreconfirmationInput>,
        MockInboxReader,
        watch::Sender<U256>,
    ) {
        let (input_tx, input_rx) = mpsc::channel::<PreconfirmationInput>(16);
        let (preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);
        let inbox_reader = MockInboxReader::new(0, None, Some(0));
        let client = EmbeddedDriverClient::new_with_poll_interval(
            input_tx,
            preconf_tip_rx,
            inbox_reader.clone(),
            Duration::from_millis(10),
        );
        (client, input_rx, inbox_reader, preconf_tip_tx)
    }

    fn make_test_input(block_number: u64) -> PreconfirmationInput {
        let preconf = Preconfirmation { block_number: block_number.into(), ..Default::default() };
        let commitment = SignedCommitment {
            commitment: PreconfCommitment { preconf, ..Default::default() },
            signature: Bytes65::try_from(vec![0u8; 65]).expect("signature"),
        };
        PreconfirmationInput::new(commitment, None, None)
    }

    #[tokio::test]
    async fn test_event_sync_tip() {
        let (client, _, inbox_reader, _) = make_client();
        inbox_reader.set_head_l1_origin(Some(42));

        assert_eq!(client.event_sync_tip().await.unwrap(), U256::from(42));

        inbox_reader.set_head_l1_origin(Some(100));
        assert_eq!(client.event_sync_tip().await.unwrap(), U256::from(100));
    }

    #[tokio::test]
    async fn test_preconf_tip() {
        let (client, _, _, preconf_tip_tx) = make_client();
        preconf_tip_tx.send(U256::from(500)).unwrap();

        assert_eq!(client.preconf_tip().await.unwrap(), U256::from(500));

        preconf_tip_tx.send(U256::from(600)).unwrap();
        assert_eq!(client.preconf_tip().await.unwrap(), U256::from(600));
    }

    #[tokio::test]
    async fn test_wait_event_sync_returns_immediately_when_synced() {
        let (input_tx, _) = mpsc::channel::<PreconfirmationInput>(16);
        let (_, preconf_tip_rx) = watch::channel(U256::ZERO);
        let inbox_reader = MockInboxReader::new(0, None, None);
        let client = EmbeddedDriverClient::new(input_tx, preconf_tip_rx, inbox_reader);

        client.wait_event_sync().await.unwrap();
    }

    #[tokio::test]
    async fn test_wait_event_sync_waits_until_head_reaches_target_block() {
        let (client, _, inbox_reader, _) = make_client();
        inbox_reader.set_next_proposal_id(5);
        inbox_reader.set_target_block(Some(12));
        inbox_reader.set_head_l1_origin(Some(11));

        tokio::spawn(async move {
            tokio::time::sleep(std::time::Duration::from_millis(10)).await;
            inbox_reader.set_head_l1_origin(Some(12));
        });

        client.wait_event_sync().await.unwrap();
    }

    #[tokio::test]
    async fn test_submit_preconfirmation() {
        let (client, mut input_rx, _, _) = make_client();
        let input = make_test_input(5);

        client.submit_preconfirmation(input).await.unwrap();

        let received = input_rx.recv().await.unwrap();
        assert_eq!(received.commitment.commitment.preconf.block_number, 5u64.into());
    }

    #[tokio::test]
    async fn test_submit_preconfirmation_closed_channel() {
        let (client, input_rx, _, _) = make_client();
        drop(input_rx);

        let result = client.submit_preconfirmation(make_test_input(1)).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_wait_event_sync_returns_ok_when_no_proposals() {
        let (input_tx, _) = mpsc::channel::<PreconfirmationInput>(16);
        let (_, preconf_tip_rx) = watch::channel(U256::ZERO);
        let inbox_reader = MockInboxReader::new(0, None, None);
        let client = EmbeddedDriverClient::new(input_tx, preconf_tip_rx, inbox_reader);
        client.wait_event_sync().await.unwrap();
    }

    #[tokio::test]
    async fn test_wait_event_sync_stays_pending_when_sync_data_is_missing() {
        let (client, _, inbox_reader, _) = make_client();
        inbox_reader.set_next_proposal_id(5);
        inbox_reader.set_target_block(None);
        inbox_reader.set_head_l1_origin(Some(12));

        let wait_result =
            tokio::time::timeout(std::time::Duration::from_millis(80), client.wait_event_sync())
                .await;
        assert!(wait_result.is_err(), "wait should remain pending while target block is missing");
    }

    #[tokio::test]
    async fn test_event_sync_tip_falls_back_to_zero_when_head_l1_origin_missing() {
        let (client, _, inbox_reader, preconf_tip_tx) = make_client();
        inbox_reader.set_head_l1_origin(None);

        let tip = client.event_sync_tip().await.expect("should fall back to zero on genesis");
        assert_eq!(tip, U256::ZERO);

        preconf_tip_tx.send(U256::from(42)).unwrap();
        let tip = client.event_sync_tip().await.expect("genesis returns zero despite preconf tip");
        assert_eq!(tip, U256::ZERO);
    }

    /// Mock inbox reader that can simulate L1 failures on get_next_proposal_id.
    #[derive(Clone)]
    struct FailableInboxReader {
        inner: MockInboxReader,
        fail_l1: Arc<std::sync::atomic::AtomicBool>,
    }

    impl FailableInboxReader {
        fn new(next_proposal_id: u64, head_l1_origin: Option<u64>) -> Self {
            Self {
                inner: MockInboxReader::new(next_proposal_id, Some(100), head_l1_origin),
                fail_l1: Arc::new(std::sync::atomic::AtomicBool::new(false)),
            }
        }

        fn set_fail_l1(&self, fail: bool) {
            self.fail_l1.store(fail, Ordering::SeqCst);
        }
    }

    #[async_trait]
    impl InboxReader for FailableInboxReader {
        async fn get_next_proposal_id(&self) -> Result<u64> {
            if self.fail_l1.load(Ordering::SeqCst) {
                Err(crate::error::DriverApiError::EventSyncTipUnknown.into())
            } else {
                self.inner.get_next_proposal_id().await
            }
        }

        async fn get_last_block_id_by_batch_id(&self, proposal_id: u64) -> Result<Option<u64>> {
            self.inner.get_last_block_id_by_batch_id(proposal_id).await
        }

        async fn get_head_l1_origin_block_id(&self) -> Result<Option<u64>> {
            self.inner.get_head_l1_origin_block_id().await
        }
    }

    #[tokio::test]
    async fn test_event_sync_tip_uses_cache_on_l1_failure() {
        let inbox_reader = FailableInboxReader::new(5, Some(42));
        let (input_tx, _) = mpsc::channel::<PreconfirmationInput>(16);
        let (_, preconf_tip_rx) = watch::channel(U256::ZERO);
        let client = EmbeddedDriverClient::new_with_poll_interval(
            input_tx,
            preconf_tip_rx,
            inbox_reader.clone(),
            Duration::from_millis(10),
        );

        // First call succeeds and populates the cache.
        let tip = client.event_sync_tip().await.unwrap();
        assert_eq!(tip, U256::from(42));

        // Simulate L1 failure — should fall back to cached proposal ID.
        inbox_reader.set_fail_l1(true);
        let tip = client.event_sync_tip().await.unwrap();
        assert_eq!(tip, U256::from(42));

        // L1 recovers — should use fresh value again.
        inbox_reader.set_fail_l1(false);
        inbox_reader.inner.set_head_l1_origin(Some(99));
        let tip = client.event_sync_tip().await.unwrap();
        assert_eq!(tip, U256::from(99));
    }

    #[tokio::test]
    async fn test_event_sync_tip_propagates_error_when_cache_cold() {
        let inbox_reader = FailableInboxReader::new(5, Some(42));
        let (input_tx, _) = mpsc::channel::<PreconfirmationInput>(16);
        let (_, preconf_tip_rx) = watch::channel(U256::ZERO);
        let client = EmbeddedDriverClient::new_with_poll_interval(
            input_tx,
            preconf_tip_rx,
            inbox_reader.clone(),
            Duration::from_millis(10),
        );

        // L1 fails before any successful call — no cache, should propagate error.
        inbox_reader.set_fail_l1(true);
        let result = client.event_sync_tip().await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_wait_event_sync_uses_cache_on_l1_failure() {
        let inbox_reader = FailableInboxReader::new(5, Some(99));
        let (input_tx, _) = mpsc::channel::<PreconfirmationInput>(16);
        let (_, preconf_tip_rx) = watch::channel(U256::ZERO);
        let client = EmbeddedDriverClient::new_with_poll_interval(
            input_tx,
            preconf_tip_rx,
            inbox_reader.clone(),
            Duration::from_millis(10),
        );

        let wait_client = client.clone();
        let wait_handle = tokio::spawn(async move { wait_client.wait_event_sync().await });

        tokio::time::sleep(Duration::from_millis(15)).await;
        inbox_reader.set_fail_l1(true);
        inbox_reader.inner.set_head_l1_origin(Some(100));

        let result = tokio::time::timeout(Duration::from_millis(120), wait_handle)
            .await
            .expect("wait_event_sync should complete before timeout")
            .expect("wait_event_sync task should not panic");
        assert!(
            result.is_ok(),
            "cached target should keep wait_event_sync alive during L1 outages"
        );
    }
}
