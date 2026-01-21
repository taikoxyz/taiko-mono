//! Embedded driver client for direct in-process communication via channels.

use alloy_primitives::U256;
use async_trait::async_trait;
use tokio::sync::{mpsc, watch};

use super::traits::{DriverClient, PreconfirmationInput};
use crate::error::{DriverApiError, Result};

/// A driver client that communicates directly with an embedded driver via channels.
#[derive(Clone)]
pub struct EmbeddedDriverClient {
    input_sender: mpsc::Sender<PreconfirmationInput>,
    canonical_proposal_id: watch::Receiver<u64>,
    preconf_tip: watch::Receiver<U256>,
}

impl EmbeddedDriverClient {
    /// Creates a new embedded driver client with the given channels.
    pub fn new(
        input_sender: mpsc::Sender<PreconfirmationInput>,
        canonical_proposal_id: watch::Receiver<u64>,
        preconf_tip: watch::Receiver<U256>,
    ) -> Self {
        Self { input_sender, canonical_proposal_id, preconf_tip }
    }

    #[cfg(test)]
    pub fn input_sender_capacity(&self) -> usize {
        self.input_sender.capacity()
    }
}

#[async_trait]
impl DriverClient for EmbeddedDriverClient {
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()> {
        self.input_sender
            .send(input)
            .await
            .map_err(|e| DriverApiError::ChannelClosed(e.to_string()))?;
        Ok(())
    }

    async fn wait_event_sync(&self) -> Result<()> {
        let mut rx = self.canonical_proposal_id.clone();
        let initial = *rx.borrow();

        if initial > 0 {
            return Ok(());
        }

        loop {
            if rx.changed().await.is_err() {
                // Sender dropped - allow graceful shutdown
                return Ok(());
            }
            if *rx.borrow() > initial {
                return Ok(());
            }
        }
    }

    async fn event_sync_tip(&self) -> Result<U256> {
        Ok(U256::from(*self.canonical_proposal_id.borrow()))
    }

    async fn preconf_tip(&self) -> Result<U256> {
        Ok(*self.preconf_tip.borrow())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use preconfirmation_types::{Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment};

    fn make_client() -> (
        EmbeddedDriverClient,
        mpsc::Receiver<PreconfirmationInput>,
        watch::Sender<u64>,
        watch::Sender<U256>,
    ) {
        let (input_tx, input_rx) = mpsc::channel::<PreconfirmationInput>(16);
        let (canonical_id_tx, canonical_id_rx) = watch::channel(0u64);
        let (preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);
        let client = EmbeddedDriverClient::new(input_tx, canonical_id_rx, preconf_tip_rx);
        (client, input_rx, canonical_id_tx, preconf_tip_tx)
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
        let client = EmbeddedDriverClient::new(input_tx, canonical_id_rx, preconf_tip_rx);

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
}
