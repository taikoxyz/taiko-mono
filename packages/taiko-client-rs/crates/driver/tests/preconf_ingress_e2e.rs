//! End-to-end preconfirmation ingress: payloads submitted through
//! `submit_preconfirmation_payload` must materialize as L2 blocks — including
//! payloads whose txlist carries a legacy (type-0) transaction, the exact
//! shape that froze mainnet (PR #21906).
//!
//! These are the first tests to exercise the driver's
//! `EventSyncer::submit_preconfirmation_payload` ingress path end-to-end: no
//! existing test ever calls it. The setup block (beacon stub, `DriverConfig`
//! with `preconfirmation_enabled = true`, `EventSyncer::new` + spawned run loop,
//! `wait_preconf_ingress_ready`) mirrors `proposer_driver_e2e.rs` verbatim
//! (adjusted names only); `build_preconf_attrs` mirrors the whitelist driver's
//! `build_driver_payload` (payload.rs) field-for-field by routing through the
//! same public `protocol::shasta::build_payload_attributes_with_id` builder.

use std::{sync::Arc, time::Duration};

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_consensus::TxEnvelope;
use alloy_eips::eip2718::Decodable2718;
use alloy_primitives::{Address, B256, Bytes, U256};
use alloy_provider::Provider;
use anyhow::{Result, ensure};
use driver::{
    DriverConfig,
    production::PreconfPayload,
    sync::{SyncStage, event::EventSyncer},
};
use protocol::{
    codec::ZlibTxListCodec,
    shasta::{PayloadAttributesInput, build_payload_attributes_with_id, calculate_shasta_mix_hash},
};
use rpc::client::Client;
use serial_test::serial;
use test_context::test_context;
use test_harness::{
    BeaconStubServer, ShastaEnv,
    blocks::{fetch_block_by_number, wait_for_block},
    transactions::{build_mixed_preconf_txlist, build_preconf_txlist},
};
use tokio::spawn;
use tracing::warn;

/// Compressed/decompressed txlist size caps used by the whitelist ingress path
/// (`crates/whitelist-preconfirmation-driver/src/codec.rs`): 6 blobs compressed,
/// 8 MiB decompressed. Reused here only to round-trip-check the encoded list.
const MAX_COMPRESSED_TX_LIST_BYTES: usize = 131_072 * 6;
const MAX_DECOMPRESSED_TX_LIST_BYTES: usize = 8 * 1024 * 1024;

/// Builds preconf payload attributes the way the whitelist driver's
/// `build_driver_payload` does (`whitelist-preconfirmation-driver/src/payload.rs`).
///
/// `build_driver_payload` reads its per-block fields off a gossiped
/// `ExecutionPayloadV1` and forwards them through
/// `protocol::shasta::build_payload_attributes_with_id`. This test has no
/// gossiped payload, so it computes each equivalent from the parent block plus
/// the chosen values and routes through the *same* public builder — that is what
/// keeps the field mapping (timestamps carried into both `payload_attributes`
/// and `block_metadata`, `mix_hash := prev_randao`, `extra_data`, zeroed
/// `l1_origin` except `block_id`, `anchor_transaction: None`, `signature`
/// zeroed) identical to production line-for-line rather than hand-transcribed.
///
/// Field ↔ `ExecutionPayloadV1` mapping (see `payload.rs::build_driver_payload`):
/// - `fee_recipient`   → `execution_payload.fee_recipient` (beneficiary / suggested fee recipient)
/// - `timestamp`       → `execution_payload.timestamp` (the *new* block's timestamp; the caller
///   passes `parent.timestamp + 1` so it strictly increases as the engine requires — a real
///   gossiped payload's timestamp is likewise > parent's)
/// - `mix_hash`        → `execution_payload.prev_randao`
/// - `gas_limit`       → `execution_payload.gas_limit`
/// - `tx_list_rlp`     → decompressed RLP list of `execution_payload.transactions[0]`
/// - `extra_data`      → `execution_payload.extra_data`
/// - `base_fee`        → `execution_payload.base_fee_per_gas`
/// - `block_number`    → `execution_payload.block_number` (also the l1_origin `block_id`)
///
/// The local-build defaults match `payload.rs` on the non-gossip path
/// (`WhitelistApiService::build_driver_payload`, `payload_build.rs`):
/// `parent_beacon_block_root: None`, `is_forced_inclusion: false`,
/// `signature: [0u8; 65]`.
#[allow(clippy::too_many_arguments)]
fn build_preconf_attrs(
    block_number: u64,
    timestamp: u64,
    fee_recipient: Address,
    gas_limit: u64,
    base_fee: u64,
    parent_hash: B256,
    mix_hash: B256,
    extra_data: Bytes,
    raw_txs: &[Bytes],
) -> Result<TaikoPayloadAttributes> {
    // Decompressed RLP list: legacy verbatim, typed txs wrapped as RLP byte
    // strings — exactly what alloy produces when RLP-encoding a `Vec<TxEnvelope>`
    // and byte-identical to the go-ethereum `types.Transactions` shape the
    // production `ZlibTxListCodec` emits (see protocol/src/codec.rs
    // `encode_transaction_list`). This is the same content
    // `build_driver_payload` receives from `decompress_tx_list`.
    let envs: Vec<TxEnvelope> = raw_txs
        .iter()
        .map(|b| TxEnvelope::decode_2718(&mut b.as_ref()).expect("valid raw tx"))
        .collect();
    let tx_list_rlp = alloy_rlp::encode(&envs);

    // CI-runnable guard against the PR #21906 bug class: the RLP list we hand the
    // engine must round-trip through the *production* codec that the whitelist
    // ingress path uses to decode gossiped lists. If a legacy tx were mis-encoded
    // this would fail here (cheaply, in CI) rather than silently stalling ingress.
    let codec = ZlibTxListCodec::new_with_limits(
        MAX_COMPRESSED_TX_LIST_BYTES,
        MAX_DECOMPRESSED_TX_LIST_BYTES,
    );
    let raw_vecs: Vec<Vec<u8>> = raw_txs.iter().map(|b| b.to_vec()).collect();
    let compressed = codec.encode(&raw_vecs).expect("production codec must encode the txlist");
    let decoded = codec.decode(&compressed).expect("production codec must decode the txlist");
    assert_eq!(decoded, raw_vecs, "txlist must round-trip through the production ZlibTxListCodec");

    // Field-for-field mirror of `build_driver_payload` via the same public builder.
    Ok(build_payload_attributes_with_id(
        PayloadAttributesInput {
            beneficiary: fee_recipient,
            timestamp,
            mix_hash,
            gas_limit,
            tx_list: Some(Bytes::from(tx_list_rlp)),
            extra_data,
            base_fee_per_gas: U256::from(base_fee),
            block_number,
            // build_driver_payload passes l1_block_height/hash as None (local build).
            l1_block_height: None,
            l1_block_hash: None,
            is_forced_inclusion: false,
            signature: [0u8; 65],
            parent_beacon_block_root: None,
            anchor_transaction: None,
        },
        &parent_hash,
    ))
}

/// Smoke: one preconf payload through the ingress advances the head by one.
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn preconf_ingress_injects_block_smoke(env: &mut ShastaEnv) -> Result<()> {
    // --- setup mirrored from proposer_driver_e2e.rs: beacon stub, DriverConfig
    // with preconfirmation_enabled = true, EventSyncer::new, spawn run loop,
    // wait_preconf_ingress_ready ---
    let beacon_stub = BeaconStubServer::start().await?;
    let mut driver_config = DriverConfig::new(
        env.client_config.clone(),
        Duration::from_millis(50),
        beacon_stub.endpoint().clone(),
        None,
        None,
    );
    driver_config.preconfirmation_enabled = true;
    let driver_client = Client::new(driver_config.client.clone()).await?;
    let event_syncer = Arc::new(EventSyncer::new(&driver_config, driver_client.clone()).await?);
    let syncer_handle = {
        let syncer = event_syncer.clone();
        spawn(async move {
            if let Err(err) = syncer.run().await {
                warn!(?err, "event syncer exited");
            }
        })
    };
    event_syncer.wait_preconf_ingress_ready().await?;

    let parent_number = env.client.l2_provider.get_block_number().await?;
    let parent = fetch_block_by_number(&env.client.l2_provider, parent_number).await?;
    let block_number = parent.header.number + 1;
    // Base fee for block N+1 under EIP-4396, derived exactly as the harness
    // txlist builders do (compute_next_block_base_fee, from parent number N).
    let base_fee = test_harness::transactions::compute_next_block_base_fee(
        &env.client.l2_provider,
        parent.header.number,
    )
    .await?;

    // build_preconf_txlist already prepends the anchor: raw_tx_bytes == [anchor,
    // ..transfers]. (The brief's separate `vec![anchor_tx]` prepend would double
    // the anchor given the Task 2.4 builders, so we feed raw_tx_bytes directly.)
    let txlist =
        build_preconf_txlist(&env.client, parent.header.hash, block_number, base_fee).await?;

    let attrs = build_preconf_attrs(
        block_number,
        // New block timestamp: parent + 1, the minimal strictly-increasing value
        // the engine accepts (a real gossiped payload's timestamp is also > parent's).
        parent.header.timestamp + 1,
        env.l2_suggested_fee_recipient,
        parent.header.gas_limit,
        base_fee,
        parent.header.hash,
        // mix_hash mirrors the local-build path (payload_build.rs::derive_prev_randao):
        // calculate_shasta_mix_hash(parent_mix_hash, block_number), with
        // parent_mix_hash reconstructed from the parent header difficulty.
        calculate_shasta_mix_hash(
            B256::from(parent.header.difficulty.to_be_bytes::<32>()),
            block_number,
        ),
        // extra_data: the engine carries this through into the block header
        // (it is not engine-validated); reuse the parent's own extra_data, which
        // already encodes the devnet basefee-sharing percentage. This mirrors the
        // harness `fork_to` helper, which reuses a block's extra_data verbatim.
        parent.header.extra_data.clone(),
        &txlist.raw_tx_bytes,
    )?;

    event_syncer.submit_preconfirmation_payload(PreconfPayload::new(attrs)).await?;

    let block =
        wait_for_block(&env.client.l2_provider, block_number, Duration::from_secs(30)).await?;
    assert_eq!(block.header.number, block_number, "head must advance to block N+1");
    assert!(
        event_syncer.is_preconf_ingress_ready(),
        "ingress must stay ready after a successful injection"
    );

    syncer_handle.abort();
    beacon_stub.shutdown().await?;

    Ok(())
}

/// Regression: a preconf txlist containing a LEGACY (type-0) transaction must
/// survive ingress -> engine and land all its transactions in the block.
///
/// This is the PR #21906 shape: a Go peer gossips a txlist mixing a legacy
/// transaction with EIP-1559 ones; the decoder must accept it rather than
/// stalling ingress.
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn preconf_payload_with_legacy_tx_is_injected(env: &mut ShastaEnv) -> Result<()> {
    // --- same setup block as the smoke test (mirrored from proposer_driver_e2e.rs) ---
    let beacon_stub = BeaconStubServer::start().await?;
    let mut driver_config = DriverConfig::new(
        env.client_config.clone(),
        Duration::from_millis(50),
        beacon_stub.endpoint().clone(),
        None,
        None,
    );
    driver_config.preconfirmation_enabled = true;
    let driver_client = Client::new(driver_config.client.clone()).await?;
    let event_syncer = Arc::new(EventSyncer::new(&driver_config, driver_client.clone()).await?);
    let syncer_handle = {
        let syncer = event_syncer.clone();
        spawn(async move {
            if let Err(err) = syncer.run().await {
                warn!(?err, "event syncer exited");
            }
        })
    };
    event_syncer.wait_preconf_ingress_ready().await?;

    let parent_number = env.client.l2_provider.get_block_number().await?;
    let parent = fetch_block_by_number(&env.client.l2_provider, parent_number).await?;
    let block_number = parent.header.number + 1;
    let base_fee = test_harness::transactions::compute_next_block_base_fee(
        &env.client.l2_provider,
        parent.header.number,
    )
    .await?;

    // raw_tx_bytes == [anchor, legacy transfer, eip1559 transfer]; the anchor is
    // already element 0 (see build_mixed_preconf_txlist), so no manual prepend.
    let txlist =
        build_mixed_preconf_txlist(&env.client, parent.header.hash, block_number, base_fee).await?;
    // The legacy transfer's canonical encoding is a bare RLP list, whose first
    // byte is >= 0xc0. The anchor + eip1559 txs are typed (first byte < 0x80),
    // so this asserts the fixture genuinely carries a legacy tx.
    assert!(
        txlist.raw_tx_bytes.iter().any(|tx| tx[0] >= 0xc0),
        "fixture must actually contain a legacy tx"
    );

    let attrs = build_preconf_attrs(
        block_number,
        // New block timestamp: parent + 1, the minimal strictly-increasing value
        // the engine accepts (a real gossiped payload's timestamp is also > parent's).
        parent.header.timestamp + 1,
        env.l2_suggested_fee_recipient,
        parent.header.gas_limit,
        base_fee,
        parent.header.hash,
        calculate_shasta_mix_hash(
            B256::from(parent.header.difficulty.to_be_bytes::<32>()),
            block_number,
        ),
        parent.header.extra_data.clone(),
        &txlist.raw_tx_bytes,
    )?;

    event_syncer.submit_preconfirmation_payload(PreconfPayload::new(attrs)).await?;

    let block =
        wait_for_block(&env.client.l2_provider, block_number, Duration::from_secs(30)).await?;
    let block_tx_hashes: Vec<B256> = block
        .transactions
        .as_transactions()
        .map(|txs| txs.iter().map(|tx| *tx.hash()).collect())
        .unwrap_or_default();
    for transfer in &txlist.transfers {
        assert!(
            block_tx_hashes.contains(&transfer.hash),
            "transfer {} (incl. the legacy one) must be in the block",
            transfer.hash
        );
    }

    // Sanity: the block should carry the anchor plus both transfers.
    ensure!(
        block_tx_hashes.len() >= txlist.transfers.len() + 1,
        "block must contain the anchor plus every transfer"
    );

    syncer_handle.abort();
    beacon_stub.shutdown().await?;

    Ok(())
}
