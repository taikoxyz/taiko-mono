//! Minimal integration-style smoke test for the P2P SDK using in-memory storage and
//! the real async runtime. Network IO is minimized by driving synthetic events
//! through the SDK mapping layer.

use p2p::{P2pSdk, P2pSdkConfig};
use preconfirmation_service::NetworkEvent;
use preconfirmation_types::{
    Bytes32, PreconfCommitment, Preconfirmation, RawTxListGossip, SignedCommitment,
    keccak256_bytes, preconfirmation_hash, sign_commitment,
};
use tokio::time::Duration;

/// Build a tiny txlist and matching (unsigned) commitment for testing.
fn build_tx_and_commitment() -> (RawTxListGossip, SignedCommitment) {
    let mut txlist = preconfirmation_types::TxListBytes::default();
    let _ = txlist.push(1u8);
    let hash = keccak256_bytes(txlist.as_ref());
    let tx = RawTxListGossip {
        raw_tx_list_hash: Bytes32::try_from(hash.as_slice().to_vec()).unwrap(),
        txlist,
    };

    let mut preconf = Preconfirmation::default();
    preconf.raw_tx_list_hash = tx.raw_tx_list_hash.clone();
    let commitment = PreconfCommitment { preconf, ..Default::default() };

    // Build a deterministic but valid signature so validation passes end-to-end.
    let sk = secp256k1::SecretKey::from_slice(&[7u8; 32]).unwrap();
    let signature = sign_commitment(&commitment, &sk).expect("signing succeeds");

    let signed = SignedCommitment { commitment, signature };
    (tx, signed)
}

#[tokio::test]
/// Smoke-test publishing and processing a txlist+commitment through the SDK.
async fn smoke_publish_and_process() {
    let mut sdk = P2pSdk::start(P2pSdkConfig::default()).await.unwrap();
    let (tx, signed) = build_tx_and_commitment();

    // Publish helpers validate and store.
    sdk.publish_txlist_and_commitment(tx.clone(), signed.clone()).await.unwrap();

    // Feed a synthetic gossip commitment back through the pipeline.
    let mapped = sdk
        .process_event_test(NetworkEvent::GossipSignedCommitment {
            from: libp2p::PeerId::random(),
            msg: Box::new(signed.clone()),
        })
        .await;
    // Duplicate should be dropped thanks to message-id cache.
    assert!(mapped.is_none());

    // Derive commitment hash to ensure helper still works.
    let hash = preconfirmation_hash(&signed.commitment.preconf).unwrap();
    assert!(!hash.as_slice().iter().all(|b| *b == 0));

    // Allow background tasks to drain.
    tokio::time::sleep(Duration::from_millis(50)).await;
}
