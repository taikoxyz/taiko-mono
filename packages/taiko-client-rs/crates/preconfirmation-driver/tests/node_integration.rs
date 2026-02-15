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

const NONE_SENTINEL: u64 = u64::MAX;

/// Mock inbox reader for testing.
#[derive(Clone)]
struct MockInboxReader {
    next_proposal_id: Arc<AtomicU64>,
    target_block: Arc<AtomicU64>,
    head_l1_origin_block_id: Arc<AtomicU64>,
}

impl MockInboxReader {
    fn new(next_proposal_id: u64, target_block: Option<u64>, head_l1_origin: Option<u64>) -> Self {
        Self {
            next_proposal_id: Arc::new(AtomicU64::new(next_proposal_id)),
            target_block: Arc::new(AtomicU64::new(target_block.unwrap_or(NONE_SENTINEL))),
            head_l1_origin_block_id: Arc::new(AtomicU64::new(
                head_l1_origin.unwrap_or(NONE_SENTINEL),
            )),
        }
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
        Ok(MockInboxReader::read_optional(self.target_block.load(Ordering::SeqCst)))
    }

    async fn get_head_l1_origin_block_id(&self) -> Result<Option<u64>> {
        Ok(MockInboxReader::read_optional(self.head_l1_origin_block_id.load(Ordering::SeqCst)))
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
    let client = EmbeddedDriverClient::new(input_tx, preconf_tip_rx, inbox_reader.clone());
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
async fn test_embedded_driver_client_channel_communication() {
    let (client, mut input_rx, inbox_reader, preconf_tip_tx) = make_client();

    assert_eq!(client.preconf_tip().await.unwrap(), U256::ZERO);
    assert_eq!(client.event_sync_tip().await.unwrap(), U256::ZERO);

    inbox_reader.set_head_l1_origin(Some(90));
    preconf_tip_tx.send(U256::from(100)).unwrap();

    assert_eq!(client.event_sync_tip().await.unwrap(), U256::from(90));
    assert_eq!(client.preconf_tip().await.unwrap(), U256::from(100));

    client.submit_preconfirmation(make_test_input(5)).await.unwrap();

    let received = input_rx.recv().await.unwrap();
    assert_eq!(received.commitment.commitment.preconf.block_number, 5u64.into());
}

#[tokio::test]
async fn test_driver_channels_round_trip() {
    let (input_tx, input_rx) = mpsc::channel::<PreconfirmationInput>(16);
    let (preconf_tip_tx, preconf_tip_rx) = watch::channel(U256::ZERO);

    let channels = DriverChannels { input_rx, preconf_tip_tx };

    let inbox_reader = MockInboxReader::new(5, Some(150), Some(150));
    let client = EmbeddedDriverClient::new(input_tx, preconf_tip_rx, inbox_reader);

    channels.preconf_tip_tx.send(U256::from(200)).unwrap();

    assert_eq!(client.event_sync_tip().await.unwrap(), U256::from(150));
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
    let (_, preconf_tip_rx) = watch::channel(U256::ZERO);
    let inbox_reader = MockInboxReader::new(0, None, None);
    let client = EmbeddedDriverClient::new(input_tx, preconf_tip_rx, inbox_reader);

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
async fn test_event_sync_tip_errors_when_head_l1_origin_missing() {
    let (client, _input_rx, inbox_reader, _preconf_tip_tx) = make_client();
    inbox_reader.set_head_l1_origin(None);

    let err = client.event_sync_tip().await.unwrap_err();
    assert!(matches!(
        err,
        preconfirmation_driver::PreconfirmationClientError::DriverInterface(
            preconfirmation_driver::DriverApiError::EventSyncTipUnknown
        )
    ));
}
