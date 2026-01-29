//! Embedded driver client for direct in-process communication via channels.

use alloy_primitives::U256;
use alloy_provider::Provider;
use async_trait::async_trait;
use bindings::inbox::Inbox::InboxInstance;
use tokio::sync::{mpsc, watch};
use tracing::info;

use crate::error::{DriverApiError, Result};

use super::{
    PreconfirmationInput,
    traits::{DriverClient, InboxReader},
};

/// Real implementation of InboxReader using the Inbox contract bindings.
#[derive(Clone)]
pub struct ContractInboxReader<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// L1 Inbox contract instance.
    inbox: InboxInstance<P>,
}

impl<P> ContractInboxReader<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Creates a new ContractInboxReader with the given Inbox contract instance.
    pub fn new(inbox: InboxInstance<P>) -> Self {
        Self { inbox }
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
            .inbox
            .getCoreState()
            .call()
            .await
            .map_err(DriverApiError::from)?
            .nextProposalId
            .to::<u64>())
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
    /// Watch channel for receiving the latest canonical proposal ID from the driver.
    canonical_proposal_id_rx: watch::Receiver<u64>,
    /// Watch channel for receiving the latest preconfirmation tip from the driver.
    preconf_tip_rx: watch::Receiver<U256>,
    /// Inbox reader for checking L1 sync state.
    inbox_reader: I,
}

impl<I: InboxReader> EmbeddedDriverClient<I> {
    /// Creates a new embedded driver client with the given channels and inbox reader.
    pub fn new(
        input_tx: mpsc::Sender<PreconfirmationInput>,
        canonical_proposal_id_rx: watch::Receiver<u64>,
        preconf_tip_rx: watch::Receiver<U256>,
        inbox_reader: I,
    ) -> Self {
        Self { input_tx, canonical_proposal_id_rx, preconf_tip_rx, inbox_reader }
    }

    /// Returns a reference to the inbox reader.
    pub fn inbox_reader(&self) -> &I {
        &self.inbox_reader
    }

    /// Returns the capacity of the input tx channel (for testing purposes).
    #[cfg(test)]
    pub fn input_tx_capacity(&self) -> usize {
        self.input_tx.capacity()
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
    /// - If `nextProposalId == 0`, returns Ok immediately (no proposals to sync)
    /// - Otherwise, waits until `canonical_proposal_id >= nextProposalId - 1`
    /// - If the watch channel is closed, returns a channel closed error
    async fn wait_event_sync(&self) -> Result<()> {
        info!("starting wait for driver to sync with L1 inbox events");

        let mut canonical_proposal_id_rx = self.canonical_proposal_id_rx.clone();

        loop {
            let canonical_id = *canonical_proposal_id_rx.borrow();
            let next_proposal_id = self.inbox_reader.get_next_proposal_id().await?;

            info!(
                canonical_proposal_id = canonical_id,
                next_proposal_id = next_proposal_id,
                "checking sync state"
            );

            // No proposals to sync - return immediately.
            if next_proposal_id <= 1 {
                info!("sync complete (no proposals)");
                return Ok(());
            }

            // Check if we've caught up.
            if canonical_id >= next_proposal_id.saturating_sub(1) {
                info!("driver event sync complete");
                return Ok(());
            }

            // Wait for the canonical proposal ID to change.
            if canonical_proposal_id_rx.changed().await.is_err() {
                return Err(DriverApiError::ChannelClosed(
                    "canonical proposal id watch channel closed".to_string(),
                )
                .into());
            }
        }
    }

    /// Returns the current canonical proposal ID as a U256.
    async fn event_sync_tip(&self) -> Result<U256> {
        Ok(U256::from(*self.canonical_proposal_id_rx.borrow()))
    }

    /// Returns the current preconfirmation tip block number.
    async fn preconf_tip(&self) -> Result<U256> {
        Ok(*self.preconf_tip_rx.borrow())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::PreconfirmationClientError;
    use preconfirmation_types::{Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment};
    use std::sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    };

    /// Mock inbox reader for testing.
    #[derive(Clone)]
    struct MockInboxReader {
        next_proposal_id: Arc<AtomicU64>,
    }

    impl MockInboxReader {
        fn new(next_proposal_id: u64) -> Self {
            Self { next_proposal_id: Arc::new(AtomicU64::new(next_proposal_id)) }
        }
    }

    #[async_trait]
    impl InboxReader for MockInboxReader {
        async fn get_next_proposal_id(&self) -> Result<u64> {
            Ok(self.next_proposal_id.load(Ordering::SeqCst))
        }
    }

    fn make_client() -> (
        EmbeddedDriverClient<MockInboxReader>,
        mpsc::Receiver<PreconfirmationInput>,
        watch::Sender<u64>,
        watch::Sender<U256>,
    ) {
        let (input_tx, input_rx) = mpsc::channel::<PreconfirmationInput>(16);
        let (canonical_id_tx, canonical_id_rx) = watch::channel(0u64);
        let (preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);
        let inbox_reader = MockInboxReader::new(0);
        let client =
            EmbeddedDriverClient::new(input_tx, canonical_id_rx, preconf_tip_rx, inbox_reader);
        (client, input_rx, canonical_id_tx, preconf_tip_tx)
    }

    fn make_client_with_inbox(
        next_proposal_id: u64,
    ) -> (
        EmbeddedDriverClient<MockInboxReader>,
        mpsc::Receiver<PreconfirmationInput>,
        watch::Sender<u64>,
        watch::Sender<U256>,
        MockInboxReader,
    ) {
        let (input_tx, input_rx) = mpsc::channel::<PreconfirmationInput>(16);
        let (canonical_id_tx, canonical_id_rx) = watch::channel(0u64);
        let (preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);
        let inbox_reader = MockInboxReader::new(next_proposal_id);
        let client = EmbeddedDriverClient::new(
            input_tx,
            canonical_id_rx.clone(),
            preconf_tip_rx.clone(),
            inbox_reader.clone(),
        );
        (client, input_rx, canonical_id_tx, preconf_tip_tx, inbox_reader)
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
        let (client, _, canonical_id_tx, _) = make_client();
        canonical_id_tx.send(42).unwrap();

        assert_eq!(client.event_sync_tip().await.unwrap(), U256::from(42));

        canonical_id_tx.send(100).unwrap();
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
        let (_, canonical_id_rx) = watch::channel(10u64);
        let (_, preconf_tip_rx) = watch::channel(U256::ZERO);
        let inbox_reader = MockInboxReader::new(0);
        let client =
            EmbeddedDriverClient::new(input_tx, canonical_id_rx, preconf_tip_rx, inbox_reader);

        client.wait_event_sync().await.unwrap();
    }

    #[tokio::test]
    async fn test_wait_event_sync_waits_for_change() {
        let (client, _, canonical_id_tx, _) = make_client();

        tokio::spawn(async move {
            tokio::time::sleep(std::time::Duration::from_millis(10)).await;
            canonical_id_tx.send(1).unwrap();
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
        let (client, _, _, _, _) = make_client_with_inbox(0);
        client.wait_event_sync().await.unwrap();
    }

    #[tokio::test]
    async fn test_wait_event_sync_waits_until_synced_with_l1() {
        let (client, _, canonical_id_tx, _, _) = make_client_with_inbox(5);

        let client_clone = client.clone();
        let wait_handle = tokio::spawn(async move { client_clone.wait_event_sync().await });

        tokio::time::sleep(std::time::Duration::from_millis(10)).await;

        canonical_id_tx.send(4).unwrap();

        tokio::time::timeout(std::time::Duration::from_millis(100), wait_handle)
            .await
            .expect("wait_event_sync should complete")
            .expect("join should succeed")
            .expect("wait_event_sync should return Ok");
    }

    #[tokio::test]
    async fn test_wait_event_sync_errors_when_channel_closed() {
        let (input_tx, _) = mpsc::channel::<PreconfirmationInput>(16);
        let (canonical_id_tx, canonical_id_rx) = watch::channel(0u64);
        let (_, preconf_tip_rx) = watch::channel(U256::ZERO);
        let inbox_reader = MockInboxReader::new(10);
        let client =
            EmbeddedDriverClient::new(input_tx, canonical_id_rx, preconf_tip_rx, inbox_reader);

        let client_clone = client.clone();
        let wait_handle = tokio::spawn(async move { client_clone.wait_event_sync().await });

        tokio::time::sleep(std::time::Duration::from_millis(10)).await;

        drop(canonical_id_tx);

        let err = tokio::time::timeout(std::time::Duration::from_millis(100), wait_handle)
            .await
            .expect("wait_event_sync should complete")
            .expect("join should succeed")
            .expect_err("wait_event_sync should return error when channel closed");

        assert!(matches!(err, PreconfirmationClientError::DriverInterface(_)));
    }

    #[tokio::test]
    async fn test_wait_event_sync_already_synced_with_l1() {
        let (input_tx, _) = mpsc::channel::<PreconfirmationInput>(16);
        let (_, canonical_id_rx) = watch::channel(5u64);
        let (_, preconf_tip_rx) = watch::channel(U256::ZERO);
        let inbox_reader = MockInboxReader::new(5);
        let client =
            EmbeddedDriverClient::new(input_tx, canonical_id_rx, preconf_tip_rx, inbox_reader);

        client.wait_event_sync().await.unwrap();
    }
}
