//! Integration tests for the preconfirmation driver node (`PreconfirmationDriverNode`).

use std::sync::{
    Arc,
    atomic::{AtomicU64, Ordering},
};

use alloy_primitives::U256;
use async_trait::async_trait;
use preconfirmation_driver::{
    DriverChannels, EmbeddedDriverClient, InboxReader, Result,
    driver_interface::{DriverClient, PreconfirmationInput},
    rpc::PreconfRpcServerConfig,
};
use preconfirmation_types::{Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment};
use tokio::sync::{mpsc, watch};

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
    let client = EmbeddedDriverClient::new(input_tx, canonical_id_rx, preconf_tip_rx, inbox_reader);
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
async fn test_embedded_driver_client_channel_communication() {
    let (client, mut input_rx, canonical_id_tx, preconf_tip_tx) = make_client();

    assert_eq!(client.preconf_tip().await.unwrap(), U256::ZERO);
    assert_eq!(client.event_sync_tip().await.unwrap(), U256::ZERO);

    canonical_id_tx.send(42).unwrap();
    preconf_tip_tx.send(U256::from(100)).unwrap();

    assert_eq!(client.event_sync_tip().await.unwrap(), U256::from(42));
    assert_eq!(client.preconf_tip().await.unwrap(), U256::from(100));

    client.submit_preconfirmation(make_test_input(5)).await.unwrap();

    let received = input_rx.recv().await.unwrap();
    assert_eq!(received.commitment.commitment.preconf.block_number, 5u64.into());
}

#[tokio::test]
async fn test_driver_channels_round_trip() {
    let (input_tx, input_rx) = mpsc::channel::<PreconfirmationInput>(16);
    let (canonical_id_tx, canonical_id_rx) = watch::channel(0u64);
    let (preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);

    let channels =
        DriverChannels { input_rx, canonical_proposal_id_tx: canonical_id_tx, preconf_tip_tx };

    let inbox_reader = MockInboxReader::new(0);
    let client = EmbeddedDriverClient::new(input_tx, canonical_id_rx, preconf_tip_rx, inbox_reader);

    channels.canonical_proposal_id_tx.send(100).unwrap();
    channels.preconf_tip_tx.send(U256::from(200)).unwrap();

    assert_eq!(client.event_sync_tip().await.unwrap(), U256::from(100));
    assert_eq!(client.preconf_tip().await.unwrap(), U256::from(200));
}

#[test]
fn test_rpc_server_config_defaults() {
    let config = PreconfRpcServerConfig::default();
    assert_eq!(config.listen_addr.port(), 8550);
    assert_eq!(config.listen_addr.ip().to_string(), "127.0.0.1");
}

#[tokio::test]
async fn test_wait_event_sync_returns_immediately_when_synced() {
    let (input_tx, _) = mpsc::channel::<PreconfirmationInput>(16);
    let (_, canonical_id_rx) = watch::channel(10u64);
    let (_, preconf_tip_rx) = watch::channel(U256::ZERO);
    let inbox_reader = MockInboxReader::new(0);
    let client = EmbeddedDriverClient::new(input_tx, canonical_id_rx, preconf_tip_rx, inbox_reader);

    client.wait_event_sync().await.unwrap();
}

#[tokio::test]
async fn test_submit_preconfirmation_closed_channel() {
    let (client, input_rx, _, _) = make_client();
    drop(input_rx);

    let result = client.submit_preconfirmation(make_test_input(1)).await;
    assert!(result.is_err());
}

#[tokio::test]
async fn test_canonical_id_updates_immediately_on_change() {
    let (client, _input_rx, canonical_id_tx, _preconf_tip_tx) = make_client();

    // Initial value
    assert_eq!(client.event_sync_tip().await.unwrap(), U256::ZERO);

    // Simulate driver sending update
    canonical_id_tx.send(42).unwrap();

    // Should be immediately available (no 100ms delay)
    assert_eq!(client.event_sync_tip().await.unwrap(), U256::from(42));

    // Multiple rapid updates
    canonical_id_tx.send(43).unwrap();
    canonical_id_tx.send(44).unwrap();
    canonical_id_tx.send(45).unwrap();

    // Latest value should be immediately available
    assert_eq!(client.event_sync_tip().await.unwrap(), U256::from(45));
}
