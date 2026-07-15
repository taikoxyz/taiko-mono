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
use alloy::consensus::BlobTransactionSidecarVariant;
use alloy_consensus::{TxEnvelope, transaction::Recovered};
use alloy_eips::eip2718::{Decodable2718, Encodable2718};
use alloy_primitives::{Address, B256, Bytes, U256};
use alloy_provider::Provider;
use alloy_rpc_types::{Log, Transaction as RpcTransaction};
use alloy_sol_types::SolEvent;
use anyhow::{Context, Result, anyhow, ensure};
use bindings::inbox::Inbox::Proposed;
use driver::{
    DriverConfig,
    production::PreconfPayload,
    sync::{SyncStage, event::EventSyncer},
};
use proposer::{
    proposer::EngineBuildContext,
    transaction_builder::{BuiltProposalTx, ShastaProposalTransactionBuilder},
};
use protocol::{
    codec::ZlibTxListCodec,
    shasta::{PayloadAttributesInput, build_payload_attributes_with_id, calculate_shasta_mix_hash},
};
use rpc::client::{Client, ClientConfig};
use serial_test::serial;
use test_context::test_context;
use test_harness::{
    BeaconStubServer, ShastaEnv,
    blocks::{fetch_block_by_number, wait_for_block},
    transactions::{build_mixed_preconf_txlist, build_preconf_txlist},
};
use tokio::{spawn, task::JoinHandle};
use tracing::warn;

/// Spin up a preconf-ingress-enabled `EventSyncer` for `config` against `beacon`,
/// spawn its run loop, and block until ingress readiness latches.
///
/// This folds the ~15-line setup block that all four test sites in this file
/// otherwise copy-paste (`DriverConfig` with `preconfirmation_enabled = true`,
/// `Client::new`, `Arc<EventSyncer::new>`, spawned `run()`, and
/// `wait_preconf_ingress_ready`). It returns the driver `Client` too because most
/// callers need it afterward (head reads, proposal-processing waits, L1-origin
/// lookups); sites that do not simply bind it to `_`.
async fn start_syncer(
    config: ClientConfig,
    beacon: &BeaconStubServer,
) -> Result<(Arc<EventSyncer>, Client, JoinHandle<()>)> {
    let driver_config = DriverConfig::new(
        config,
        Duration::from_millis(50),
        beacon.endpoint().clone(),
        None,
        None,
        true,
    );
    let driver_client = Client::new(driver_config.client.clone()).await?;
    let event_syncer = Arc::new(EventSyncer::new(&driver_config, driver_client.clone()).await?);
    let handle = {
        let syncer = event_syncer.clone();
        spawn(async move {
            if let Err(err) = syncer.run().await {
                warn!(?err, "event syncer exited");
            }
        })
    };
    event_syncer.wait_preconf_ingress_ready().await?;
    Ok((event_syncer, driver_client, handle))
}

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
    // ingress path uses to decode gossiped lists. If a legacy tx were encoded
    // incorrectly this would fail here (cheaply, in CI) rather than silently stalling ingress.
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
    // Preconf-ingress-enabled syncer against L2 node 0 (see `start_syncer`).
    let beacon_stub = BeaconStubServer::start().await?;
    let (event_syncer, _driver_client, syncer_handle) =
        start_syncer(env.client_config.clone(), &beacon_stub).await?;

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

    event_syncer
        .submit_preconfirmation_payload(PreconfPayload::new(attrs, parent.header.hash))
        .await?;

    let block =
        wait_for_block(&env.client.l2_provider, block_number, Duration::from_secs(30)).await?;
    assert_eq!(block.header.number, block_number, "head must advance to block N+1");
    assert!(
        event_syncer.is_preconf_ingress_ready(),
        "ingress must stay ready after a successful injection"
    );

    syncer_handle.abort();
    // Bounded join so the aborted syncer actually stops before the beacon stub shuts down;
    // otherwise it leaks as a zombie retrying blob derivation against a dead stub, contending
    // the shared serialized devnet and wedging later tests.
    let _ = tokio::time::timeout(Duration::from_secs(5), syncer_handle).await;
    beacon_stub.shutdown().await?;

    Ok(())
}

// --- L1 proposal-path helpers, copied verbatim from proposer_driver_e2e.rs ---
// (each `tests/*.rs` file is its own crate, so these cannot be shared by `use`;
// the copies below are line-for-line identical to that file so the derivation
// side of this test exercises the exact same proposal flow.)

/// Builds a walletless proposer client (copied from proposer_driver_e2e.rs).
async fn proposer_client(env: &ShastaEnv) -> Result<Client> {
    Client::new(env.client_config.clone()).await.map_err(Into::into)
}

/// Decodes the proposal id from a `Proposed` log (copied from proposer_driver_e2e.rs).
fn decode_proposal_id(log: &Log) -> Result<u64> {
    Proposed::decode_raw_log(log.topics(), log.data().data.as_ref())
        .map(|event| event.id.to::<u64>())
        .map_err(|err| anyhow!("decode proposal log failed: {err}"))
}

/// Submits a proposal transaction through a wallet-backed L1 provider and returns
/// the proposal id and log (copied from proposer_driver_e2e.rs). The wallet lives
/// only in this test helper: the production `Client` is walletless.
async fn submit_proposal(env: &ShastaEnv, request: BuiltProposalTx) -> Result<(u64, Log)> {
    let wallet_provider = env
        .client_config
        .l1_provider_source
        .to_provider_with_wallet(env.l1_proposer_private_key)
        .await?;
    let pending_tx = wallet_provider.send_transaction(request.to_transaction_request()).await?;
    let receipt = pending_tx.get_receipt().await?;
    ensure!(receipt.status(), "proposal transaction failed");
    let proposal_log: Log = receipt
        .logs()
        .iter()
        .find(|log| log.address() == env.inbox_address)
        .cloned()
        .context("missing Proposed log in receipt")?;
    let proposal_id = decode_proposal_id(&proposal_log)?;
    Ok((proposal_id, proposal_log))
}

/// Waits for the event syncer to process a specific proposal using confirmed-sync
/// state polling (copied from proposer_driver_e2e.rs).
async fn wait_for_proposal_processed(
    event_syncer: &EventSyncer,
    driver_client: &Client,
    expected_proposal_id: u64,
    l2_head_before: u64,
    timeout: Duration,
) -> Result<u64> {
    let deadline = tokio::time::Instant::now() + timeout;

    loop {
        let target_block = driver_client
            .last_certain_block_id_by_batch_id(U256::from(expected_proposal_id))
            .await?
            .map(|block_number| block_number.to::<u64>());
        let confirmed_head = event_syncer.confirmed_sync_snapshot().await?.event_sync_tip();
        if let (Some(target_block), Some(head_block)) = (target_block, confirmed_head) &&
            head_block >= target_block
        {
            let l2_head = driver_client.l2_provider.get_block_number().await?;
            if l2_head < l2_head_before {
                warn!(
                    l2_head_before,
                    l2_head, "L2 head moved backward while waiting for proposal processing"
                );
            }
            if l2_head >= target_block {
                return Ok(l2_head);
            }
        };

        let remaining = deadline.saturating_duration_since(tokio::time::Instant::now());
        if remaining.is_zero() {
            return Err(anyhow!("timed out waiting for proposal {expected_proposal_id}"));
        }

        tokio::time::sleep(Duration::from_millis(100)).await;
    }
}

/// Returns the blob sidecar needed by beacon-based derivation
/// (copied from proposer_driver_e2e.rs).
fn built_proposal_sidecar(request: &BuiltProposalTx) -> BlobTransactionSidecarVariant {
    request.blob_sidecar()
}

/// The two decode paths (L1 blob derivation vs preconf ingress) historically
/// diverged — that asymmetry caused the mainnet freeze. This pins them to
/// byte-identical blocks: derive block N from an L1 proposal on node 0, then
/// feed the SAME block as a preconf payload to node 1 and require the same
/// block hash.
///
/// Every replay input comes straight off node 0's DERIVED block, matching the
/// production ingress path (`whitelist-preconfirmation-driver/src/importer/
/// ingress.rs::request_response_block_to_envelope`) field-for-field:
/// `fee_recipient := beneficiary`, `prev_randao := mix_hash` (passed through,
/// NOT recomputed), `gas_limit`, `timestamp` (the block's OWN timestamp, not
/// parent+1), `extra_data`, `base_fee_per_gas`, and the tx list = the block's
/// own transactions re-`encoded_2718()` (the anchor is already element 0 of the
/// block body, so it is carried through with no manual prepend).
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn preconf_and_l1_derivation_agree_on_block(env: &mut ShastaEnv) -> Result<()> {
    // --- Node 0: standard L1 proposal -> derivation, with a NON-EMPTY txlist.
    // The proposal `build()` takes typed user transactions (Vec<Vec<TxEnvelope>>,
    // no anchor — the deriver injects its own anchor). We reuse the harness'
    // mixed-txlist builder for a deterministic legacy + EIP-1559 pair, then feed
    // ONLY its transfers (decoded to TxEnvelope) into the proposal; its
    // raw_tx_bytes[0] anchor is intentionally dropped so the anchor is not
    // double-counted (see ShastaProposalTransactionBuilder::build). ---
    let beacon_stub = BeaconStubServer::start().await?;
    let proposer = proposer_client(env).await?;

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

    // Mixed (legacy + EIP-1559) transfers targeting block N+1 at `base_fee`.
    let mixed =
        build_mixed_preconf_txlist(&env.client, parent.header.hash, block_number, base_fee).await?;
    // The proposal carries only the USER transactions. `build()` takes
    // `Vec<Vec<alloy_rpc_types::Transaction>>` and converts each to a TxEnvelope
    // for the manifest via `Into` (transaction_builder.rs), so wrap each decoded
    // transfer envelope in a minimal RPC `Transaction` (only `inner` is read;
    // the block metadata fields are discarded by that `Into`). raw_tx_bytes[0]
    // (the anchor) is deliberately excluded — the deriver injects its own anchor.
    let proposal_txs: Vec<RpcTransaction> = mixed
        .transfers
        .iter()
        .map(|transfer| {
            let envelope = TxEnvelope::decode_2718(&mut transfer.raw_bytes.as_ref())
                .expect("valid transfer tx");
            RpcTransaction {
                inner: Recovered::new_unchecked(envelope, transfer.from),
                block_hash: None,
                block_number: None,
                transaction_index: None,
                effective_gas_price: None,
            }
        })
        .collect();

    // Build a single-block proposal (one inner Vec = one L2 block) with the
    // mixed txlist and inject its sidecar into the beacon stub.
    let builder =
        ShastaProposalTransactionBuilder::new(proposer.clone(), env.l2_suggested_fee_recipient);
    let (build_ctx, _) = EngineBuildContext::from_chain_heads(&proposer).await?;
    let request = builder.build(vec![proposal_txs], build_ctx).await?;
    beacon_stub.set_default_blob_sidecar(built_proposal_sidecar(&request));

    // Start the node-0 driver/event-syncer (see `start_syncer`).
    let (event_syncer, driver_client, syncer_handle) =
        start_syncer(env.client_config.clone(), &beacon_stub).await?;

    // --- Node 1: a SECOND syncer, wired to l2_ws_1/l2_auth_1 (clone
    // env.client_config, swap only the two L2 urls) so it holds an inbox view
    // independent of node 0's L2. ShastaEnv already reset BOTH L2 nodes to the same
    // base block, so node 1's parent state matches node 0's pre-derivation parent.
    // A second beacon stub satisfies DriverConfig's beacon requirement; crucially it
    // is left FRESH and BLOB-LESS, so node 1's L1 scanner can never derive proposal N
    // (see below). Started BEFORE the proposal is submitted — this is what makes the
    // "which path built block N" question decidable rather than a race. ---
    //
    // WHY BEFORE THE PROPOSAL (the ordering is load-bearing):
    // Node 1's ingress-readiness gate (`confirmed_sync_snapshot` ->
    // `ConfirmedSyncSnapshot::is_ready`, driver/src/sync/confirmed_sync.rs:32-41) is
    // "immediately ready" only while `target_proposal_id == 0`. Once proposal N lands
    // on the shared L1, `target_proposal_id >= 1` and readiness would additionally
    // require node 1's OWN L2 to have derived proposal N. But node 1's beacon stub
    // serves no blobs, so its derivation of N retries forever (unbounded
    // ExponentialBackoff, event.rs) and `wait_preconf_ingress_ready()` would hang
    // deterministically. Starting node 1 here, at `target_proposal_id == 0`, latches
    // readiness the instant it probes — before N exists.
    //
    // WHY THE RACE IS NOW STRUCTURALLY IMPOSSIBLE (not merely improbable):
    //  - Readiness cannot regress: the only reset is the scanner stream ending, which is
    //    unreachable while the scanner is parked retrying `process_log_batch` for the un-derivable
    //    proposal N. So readiness, once latched pre-proposal, holds.
    //  - Node 1 can NEVER derive block N: derivation needs the proposal's blobs, and node 1's
    //    beacon stub has none. Its scanner sees the `Proposed` log after submission and
    //    warn-retries in the background, but each backoff releases the router lock, so the ingress
    //    replay still acquires it and injects. The blob-less stub IS the independent inbox view —
    //    node 1's ONLY route to block N is the preconf ingress this test exists to pin.
    // The `is_preconf_block()` discriminator after `wait_for_block` therefore stays as
    // belt-and-braces, not as the sole guard against a live race.
    let node1_config = ClientConfig {
        l2_provider_url: env.l2_ws_1.clone(),
        l2_auth_provider_url: env.l2_auth_1.clone(),
        ..env.client_config.clone()
    };
    let beacon_stub_node1 = BeaconStubServer::start().await?;
    let (event_syncer_node1, driver_client_node1, syncer_handle_node1) =
        start_syncer(node1_config, &beacon_stub_node1).await?;
    let node1_provider = driver_client_node1.l2_provider.clone();

    let l2_head_before = driver_client.l2_provider.get_block_number().await?;
    let (proposal_id, _log) = submit_proposal(env, request).await?;
    wait_for_proposal_processed(
        &event_syncer,
        &driver_client,
        proposal_id,
        l2_head_before,
        Duration::from_secs(30),
    )
    .await?;

    // Fetch the full derived block N from node 0 (with transaction bodies).
    let derived = fetch_block_by_number(&env.client.l2_provider, block_number).await?;
    ensure!(
        derived.header.number == block_number,
        "derived block number must match the proposed block number"
    );

    // Rebuild the payload attrs FROM node 0's derived block. `tx_list` is the RLP
    // list of the derived block's OWN transactions (anchor included, taken from
    // the block body); every header-relevant field mirrors the production
    // ingress path (see ingress.rs mapping in this test's doc comment).
    let raw: Vec<Bytes> = derived
        .transactions
        .as_transactions()
        .map(|txs| txs.iter().map(|tx| tx.encoded_2718().into()).collect())
        .unwrap_or_default();
    ensure!(!raw.is_empty(), "derived block must carry at least the anchor transaction");

    let attrs = build_preconf_attrs(
        derived.header.number,
        // The derived block's OWN timestamp — NOT parent+1. The proposal path
        // stamps this from the manifest, and the replay must reproduce it
        // exactly for the block hash to match.
        derived.header.timestamp,
        derived.header.beneficiary,
        derived.header.gas_limit,
        derived.header.base_fee_per_gas.expect("post-london derived block has a base fee"),
        parent.header.hash,
        // prev_randao := the derived block's mix_hash, passed through verbatim
        // (production ingress does `prev_randao: block.header.mix_hash`); do NOT
        // recompute via calculate_shasta_mix_hash here.
        derived.header.mix_hash,
        derived.header.extra_data.clone(),
        &raw,
    )?;

    event_syncer_node1
        .submit_preconfirmation_payload(PreconfPayload::new(attrs, parent.header.hash))
        .await?;

    let injected =
        wait_for_block(&node1_provider, derived.header.number, Duration::from_secs(30)).await?;

    // BELT-AND-BRACES (the setup already makes ingress the only possible producer of
    // block N on node 1 — see the node-1 comment: readiness latched pre-proposal and
    // node 1's blob-less stub can never derive N): confirm block N came from the
    // PRECONF INGRESS path, not L1 derivation. The definitive discriminator is the
    // L1-origin record's `l1_block_height`, queried via the exact RPC the driver
    // itself uses (`taiko_l1OriginByID`, rpc::l1_origin):
    //   - ingress writes `l1_block_height: None` (build_driver_payload /
    //     build_payload_attributes_with_id pass `l1_block_height: None`; then sync_l1_origin
    //     persists that origin verbatim), and
    //   - L1 derivation writes a REAL, non-zero L1 block height (the height of the L1 block that
    //     included the proposal).
    // `RpcL1Origin::is_preconf_block()` encodes exactly this test
    // (`l1_block_height.is_none() || == Some(0)`). It runs BEFORE the hash assertion so
    // that, in the impossible event the structural guarantee is ever broken by a
    // refactor, the failure reads as "wrong path" rather than a bare hash mismatch.
    let injected_origin = driver_client_node1
        .l1_origin_by_id(U256::from(derived.header.number))
        .await?
        .context("node 1 must have an L1-origin record for the injected block")?;
    assert!(
        injected_origin.is_preconf_block(),
        "block {} on node 1 must come from preconf INGRESS (l1_block_height=None), not L1 \
         derivation of the shared proposal; got l1_block_height={:?} — a broken structural \
         guarantee means the block hash below would prove nothing",
        derived.header.number,
        injected_origin.l1_block_height,
    );

    // Mismatch-debugging guidance (per the brief): if the hashes differ, print
    // both headers field-by-field BEFORE touching the test. A mismatch is either
    // a missing/incorrect attrs field (fix the test's mapping to match the
    // production ingress path) or a REAL path divergence (stop and report) — the
    // very asymmetry this test exists to catch. Do NOT weaken the assertion.
    if injected.header.hash != derived.header.hash {
        warn!(?derived.header, ?injected.header, "derived vs injected header mismatch");
    }
    assert_eq!(
        injected.header.hash, derived.header.hash,
        "preconf ingress and L1 derivation must produce byte-identical blocks"
    );

    syncer_handle.abort();
    syncer_handle_node1.abort();
    // Bounded joins so both aborted syncers actually stop before their beacon stubs shut
    // down; otherwise they leak as zombies retrying blob derivation against dead stubs,
    // contending the shared serialized devnet and wedging later tests.
    let _ = tokio::time::timeout(Duration::from_secs(5), syncer_handle).await;
    let _ = tokio::time::timeout(Duration::from_secs(5), syncer_handle_node1).await;
    beacon_stub.shutdown().await?;
    beacon_stub_node1.shutdown().await?;

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
    // Same preconf-ingress-enabled syncer setup as the smoke test (see `start_syncer`).
    let beacon_stub = BeaconStubServer::start().await?;
    let (event_syncer, _driver_client, syncer_handle) =
        start_syncer(env.client_config.clone(), &beacon_stub).await?;

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

    event_syncer
        .submit_preconfirmation_payload(PreconfPayload::new(attrs, parent.header.hash))
        .await?;

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
        block_tx_hashes.len() > txlist.transfers.len(),
        "block must contain the anchor plus every transfer"
    );

    syncer_handle.abort();
    // Bounded join so the aborted syncer actually stops before the beacon stub shuts down;
    // otherwise it leaks as a zombie retrying blob derivation against a dead stub, contending
    // the shared serialized devnet and wedging later tests.
    let _ = tokio::time::timeout(Duration::from_secs(5), syncer_handle).await;
    beacon_stub.shutdown().await?;

    Ok(())
}
