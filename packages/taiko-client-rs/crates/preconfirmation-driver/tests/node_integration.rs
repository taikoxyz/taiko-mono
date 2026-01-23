//! Integration tests for the preconfirmation driver node (`PreconfirmationNode`).

use alloy_primitives::U256;
use preconfirmation_driver::{
    DriverChannels, EmbeddedDriverClient,
    driver_interface::{DriverClient, PreconfirmationInput},
    rpc::PreconfRpcServerConfig,
};
use preconfirmation_types::{Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment};
use tokio::sync::{mpsc, watch};

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

    let channels = DriverChannels {
        input_receiver: input_rx,
        canonical_proposal_id_sender: canonical_id_tx,
        preconf_tip_sender: preconf_tip_tx,
    };

    let client = EmbeddedDriverClient::new(input_tx, canonical_id_rx, preconf_tip_rx);

    channels.canonical_proposal_id_sender.send(100).unwrap();
    channels.preconf_tip_sender.send(U256::from(200)).unwrap();

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
    let client = EmbeddedDriverClient::new(input_tx, canonical_id_rx, preconf_tip_rx);

    client.wait_event_sync().await.unwrap();
}

#[tokio::test]
async fn test_submit_preconfirmation_closed_channel() {
    let (client, input_rx, _, _) = make_client();
    drop(input_rx);

    let result = client.submit_preconfirmation(make_test_input(1)).await;
    assert!(result.is_err());
}

// Placeholder tests for future E2E scenarios
#[tokio::test]
#[ignore = "requires full driver setup"]
async fn test_node_startup_with_embedded_driver() {
    todo!("implement when driver embedding is complete");
}

#[tokio::test]
#[ignore = "requires full driver setup"]
async fn test_rpc_api_through_node() {
    todo!("implement when RPC API is fully connected");
}

#[tokio::test]
#[ignore = "requires full driver setup"]
async fn test_node_graceful_shutdown() {
    todo!("implement shutdown test");
}
