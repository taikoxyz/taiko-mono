//! Minimal example showing how to start two P2P services, publish a commitment, and issue a
//! req/resp query. This is intentionally simple and uses random local TCP ports; it is meant as
//! scaffolding for higher-level clients (e.g., taiko-client-rs) rather than a production node.

use preconfirmation_service::{LookaheadResolver, NetworkConfig, P2pService};
use preconfirmation_types::{
    Bytes20, Bytes32, PreconfCommitment, Preconfirmation, SignedCommitment, Uint256,
    sign_commitment,
};
use secp256k1::SecretKey;
use tokio::time::{Duration, sleep};

/// Lookahead resolver that returns a fixed signer for all slots.
struct StaticLookaheadResolver {
    /// Expected signer returned for every lookup.
    signer: alloy_primitives::Address,
}

impl LookaheadResolver for StaticLookaheadResolver {
    /// Returns the configured signer for any submission window.
    fn signer_for_timestamp(
        &self,
        _submission_window_end: &Uint256,
    ) -> Result<alloy_primitives::Address, String> {
        Ok(self.signer)
    }

    /// Echoes the provided slot end unchanged.
    fn expected_slot_end(&self, submission_window_end: &Uint256) -> Result<Uint256, String> {
        Ok(submission_window_end.clone())
    }
}

// Helper to build a dummy signed commitment (signature bytes zeroed for demo only).
fn dummy_commitment() -> SignedCommitment {
    let commitment = PreconfCommitment {
        preconf: Preconfirmation {
            eop: true,
            block_number: Uint256::from(1u64),
            timestamp: Uint256::from(1u64),
            gas_limit: Uint256::from(1u64),
            coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            anchor_block_number: Uint256::from(1u64),
            raw_tx_list_hash: Bytes32::try_from(vec![0u8; 32]).unwrap(),
            parent_preconfirmation_hash: Bytes32::try_from(vec![0u8; 32]).unwrap(),
            submission_window_end: Uint256::from(1u64),
            prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            proposal_id: Uint256::from(1u64),
        },
        slasher_address: Bytes20::try_from(vec![0u8; 20]).unwrap(),
    };
    let sk = SecretKey::from_slice(&[7u8; 32]).expect("secret key");
    let signature = sign_commitment(&commitment, &sk).expect("sign");
    SignedCommitment { commitment, signature }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Two services on random localhost ports.
    let mut cfg1 = NetworkConfig::for_chain(167_000);
    cfg1.listen_addr.set_port(0);
    cfg1.enable_discovery = false;

    let cfg2 = cfg1.clone();

    let sk = SecretKey::from_slice(&[7u8; 32]).expect("secret key");
    let signer = preconfirmation_types::public_key_to_address(
        &secp256k1::PublicKey::from_secret_key(&secp256k1::Secp256k1::new(), &sk),
    );
    let lookahead = std::sync::Arc::new(StaticLookaheadResolver { signer });

    let mut svc1 = P2pService::start(cfg1, lookahead.clone())?;
    let mut svc2 = P2pService::start(cfg2, lookahead)?;

    // Publish a commitment from svc1 (it will also receive it locally).
    let commit = dummy_commitment();
    svc1.publish_commitment(commit.clone()).await?;

    // Drive a bit to let gossip propagate.
    sleep(Duration::from_millis(200)).await;

    // Issue blocking req/resp helpers from svc1 (driver picks a connected peer).
    let commitments = svc1.request_commitments_blocking(Uint256::from(0u64), 1, None).await?;
    println!("commitments response: {commitments:?}");

    let head = svc1.request_head_blocking(None).await?;
    println!("head response: {head:?}");

    // Consume a couple of remaining events just to show flow.
    for _ in 0..3 {
        if let Some(ev) = svc2.next_event().await {
            println!("svc2 event: {ev:?}");
        }
        if let Some(ev) = svc1.next_event().await {
            println!("svc1 event: {ev:?}");
        }
        sleep(Duration::from_millis(100)).await;
    }

    svc1.shutdown().await;
    svc2.shutdown().await;
    Ok(())
}
