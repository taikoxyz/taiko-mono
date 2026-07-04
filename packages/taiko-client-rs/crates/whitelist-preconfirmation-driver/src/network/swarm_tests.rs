//! Two real libp2p swarms over loopback: publish on node A, validate + receive
//! on node B. No docker required; sockets are ephemeral (`127.0.0.1:0`).

use std::{collections::HashSet, sync::Arc, time::Duration};

use alloy_primitives::Address;
use arc_swap::ArcSwap;
use libp2p::Multiaddr;
use tokio::time::timeout;

use super::runtime::{NetworkCommand, NetworkConfig, NetworkEvent, WhitelistNetwork};
use crate::codec::{WhitelistExecutionPayloadEnvelope, tests::fixed_k_sign};

const CHAIN_ID: u64 = 167;

/// Loopback config bound to an ephemeral port; discovery off.
///
/// `enable_tcp` defaults to `true` (runtime.rs), so `..NetworkConfig::default()`
/// already enables the transport we need here.
fn loopback_config(pre_dial: Vec<Multiaddr>) -> NetworkConfig {
    NetworkConfig {
        listen_addr: "127.0.0.1:0".parse().expect("addr"),
        advertise_addr: None,
        bootnodes: Vec::new(),
        pre_dial_peers: pre_dial,
        enable_discovery: false,
        ..NetworkConfig::default()
    }
}

/// Waits for a node's confirmed listen addr and appends its `/p2p/` peer id.
async fn dialable_addr(node: &WhitelistNetwork) -> Multiaddr {
    let mut rx = node.listen_addr_rx.clone();
    let addr = timeout(Duration::from_secs(10), async {
        loop {
            if let Some(addr) = rx.borrow().clone() {
                return addr;
            }
            rx.changed().await.expect("watch alive");
        }
    })
    .await
    .expect("listener bound within 10s");
    addr.with(libp2p::multiaddr::Protocol::P2p(node.peer_id))
}

/// Builds a signed publishable envelope; returns (wire_signature, envelope,
/// signer address). Uses the Task 2.1 self-consistent signing convention: the
/// caller registers the *recovered* address, so no v-byte convention is assumed.
fn signed_envelope(block_number: u64) -> ([u8; 65], WhitelistExecutionPayloadEnvelope, Address) {
    // Reuse the existing fixture builder from codec tests for the payload body,
    // overriding block_number, with signature: None (the wire signature travels
    // in front of the payload).
    let mut envelope = crate::codec::tests::sample_envelope();
    envelope.execution_payload.block_number = block_number;
    envelope.signature = None;

    let payload_bytes = crate::codec::encode_envelope_ssz(&envelope);
    let prehash = crate::codec::block_signing_hash(CHAIN_ID, &payload_bytes);
    let signature: [u8; 65] = fixed_k_sign(prehash);
    let signer = crate::codec::recover_signer(prehash, &signature).expect("recoverable");
    (signature, envelope, signer)
}

/// Publish on A → gossip over real sockets → handler validation on B →
/// `UnsafePayload` event. The end-to-end proof the mesh + codec + signer gate
/// work together.
#[tokio::test(flavor = "multi_thread")]
async fn two_swarms_deliver_operator_signed_payload() {
    let (signature, envelope, signer) = signed_envelope(7);
    let operators: crate::operator_set::SharedOperatorSet =
        Arc::new(ArcSwap::from_pointee(HashSet::from([signer])));

    let node_a = WhitelistNetwork::spawn(CHAIN_ID, loopback_config(Vec::new()), operators.clone())
        .await
        .expect("spawn A");
    let addr_a = dialable_addr(&node_a).await;
    let mut node_b = WhitelistNetwork::spawn(CHAIN_ID, loopback_config(vec![addr_a]), operators)
        .await
        .expect("spawn B");

    // Publish repeatedly until the mesh forms and B validates+delivers. A single
    // publish can be dropped with `InsufficientPeers` before the mesh grafts, so
    // the retry loop is the sanctioned mesh-formation mitigation.
    let expected_hash = envelope.execution_payload.block_hash;
    let envelope = Arc::new(envelope);
    let received = timeout(Duration::from_secs(30), async {
        loop {
            node_a
                .command_tx
                .send(NetworkCommand::PublishUnsafePayload {
                    signature,
                    envelope: envelope.clone(),
                })
                .await
                .expect("command channel alive");
            match timeout(Duration::from_millis(500), node_b.event_rx.recv()).await {
                Ok(Some(NetworkEvent::UnsafePayload { payload, .. })) => return payload,
                Ok(Some(_)) | Err(_) => continue,
                Ok(None) => panic!("node B event channel closed"),
            }
        }
    })
    .await
    .expect("payload delivered within 30s");

    assert_eq!(received.envelope.execution_payload.block_hash, expected_hash);
    assert_eq!(received.envelope.execution_payload.block_number, 7);
}

/// A signature from a non-operator must be dropped by B's validation: no event
/// may surface. (Gossipsub Reject also penalizes A's score — that part is
/// libp2p's job; ours is that the importer never sees the payload.)
#[tokio::test(flavor = "multi_thread")]
async fn two_swarms_drop_non_operator_payload() {
    let (signature, envelope, _signer) = signed_envelope(9);
    // Empty operator set on the receiving side.
    let empty: crate::operator_set::SharedOperatorSet =
        Arc::new(ArcSwap::from_pointee(HashSet::new()));

    let node_a = WhitelistNetwork::spawn(CHAIN_ID, loopback_config(Vec::new()), empty.clone())
        .await
        .expect("spawn A");
    let addr_a = dialable_addr(&node_a).await;
    let mut node_b = WhitelistNetwork::spawn(CHAIN_ID, loopback_config(vec![addr_a]), empty)
        .await
        .expect("spawn B");

    let envelope = Arc::new(envelope);
    // Give the mesh ample time; keep publishing; assert NO event arrives.
    let outcome = timeout(Duration::from_secs(10), async {
        loop {
            node_a
                .command_tx
                .send(NetworkCommand::PublishUnsafePayload {
                    signature,
                    envelope: envelope.clone(),
                })
                .await
                .expect("command channel alive");
            if let Ok(Some(event)) =
                timeout(Duration::from_millis(500), node_b.event_rx.recv()).await
            {
                return event;
            }
        }
    })
    .await;
    assert!(outcome.is_err(), "non-operator payload must never reach the importer: {outcome:?}");
}
