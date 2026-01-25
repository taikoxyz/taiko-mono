//! E2E tests for P2P preconfirmation block production.

use std::{sync::Arc, time::Duration};

use alloy_consensus::{
    TxEnvelope,
    proofs::{calculate_receipt_root, calculate_transaction_root, calculate_withdrawals_root},
    transaction::SignerRecoverable,
};
use alloy_eips::BlockId;
use alloy_primitives::{Address, B64, B256, Bloom, U256};
use alloy_provider::Provider;
use alloy_rpc_types::{BlockNumberOrTag, TransactionReceipt, eth::Block as RpcBlock};
use anyhow::{Context, Result, anyhow, ensure};
use driver::{
    DriverConfig,
    sync::{SyncStage, event::EventSyncer},
};
use preconfirmation_driver::{DriverClient, PreconfirmationClient, PreconfirmationClientConfig};
use preconfirmation_net::{InMemoryStorage, LocalValidationAdapter, P2pNode};
use preconfirmation_types::{SignedCommitment, uint256_to_u256};
use protocol::shasta::{calculate_shasta_difficulty, encode_extra_data};
use rpc::client::{Client, ClientConfig};
use serial_test::serial;
use test_context::test_context;
use test_harness::{
    BeaconStubServer, PreconfTxList, ShastaEnv, TransferPayload, build_preconf_txlist,
    compute_next_block_base_fee, fetch_block_by_number,
    preconfirmation::{
        EventSyncerDriverClient, SafeTipDriverClient, StaticLookaheadResolver,
        build_publish_payloads_with_txs, derive_signer, test_p2p_config,
        wait_for_commitment_and_txlist, wait_for_peer_connected,
    },
    verify_anchor_block, wait_for_block_or_loop_error,
};
use tokio::{spawn, sync::oneshot};

// ============================================================================
// Block Validation Helper (test-specific)
// ============================================================================

/// Validates the produced block against the preconfirmation commitment.
///
/// This performs extensive validation including header fields, transaction roots,
/// receipt roots, and EIP-4844 field absence. Kept test-local as it's specific
/// to the detailed assertions needed in this particular E2E test.
async fn assert_block_fields<P>(
    provider: &P,
    block: &RpcBlock<TxEnvelope>,
    commitment: &SignedCommitment,
    basefee_sharing_pctg: u8,
    transfers: &[TransferPayload],
) -> Result<()>
where
    P: Provider + Send + Sync,
{
    let header = &block.header.inner;
    let block_number = header.number;
    let preconf = &commitment.commitment.preconf;

    let parent_block = fetch_block_by_number(provider, block_number.saturating_sub(1)).await?;
    let parent_header = &parent_block.header.inner;

    let expected_mix_hash = calculate_shasta_difficulty(
        B256::from(parent_header.difficulty.to_be_bytes::<32>()),
        block_number,
    );
    let expected_base_fee = compute_next_block_base_fee(provider, block_number.saturating_sub(1))
        .await
        .context("computing base fee")?;
    let expected_extra =
        encode_extra_data(basefee_sharing_pctg, uint256_to_u256(&preconf.proposal_id).to::<u64>());

    // Verify header fields.
    ensure!(block.header.hash == header.hash_slow(), "header hash mismatch");
    ensure!(header.parent_hash == parent_block.header.hash, "parent hash mismatch");
    ensure!(
        header.ommers_hash == alloy_consensus::constants::EMPTY_OMMER_ROOT_HASH,
        "ommers hash mismatch"
    );
    ensure!(
        header.beneficiary == Address::from_slice(preconf.coinbase.as_ref()),
        "beneficiary mismatch"
    );
    ensure!(header.state_root != B256::ZERO, "state root missing");
    ensure!(header.difficulty == U256::ZERO, "difficulty should be zero");
    ensure!(
        header.number == uint256_to_u256(&preconf.block_number).to::<u64>(),
        "block number mismatch"
    );
    ensure!(
        header.gas_limit == uint256_to_u256(&preconf.gas_limit).to::<u64>(),
        "gas limit mismatch"
    );
    ensure!(
        header.timestamp == uint256_to_u256(&preconf.timestamp).to::<u64>(),
        "timestamp mismatch"
    );
    ensure!(header.extra_data == expected_extra, "extra data mismatch");
    ensure!(header.mix_hash == expected_mix_hash, "mix hash mismatch");
    ensure!(header.nonce == B64::ZERO, "nonce mismatch");
    ensure!(header.base_fee_per_gas == Some(expected_base_fee), "base fee mismatch");

    if let Some(withdrawals_root) = header.withdrawals_root {
        ensure!(withdrawals_root == calculate_withdrawals_root(&[]), "withdrawals root mismatch");
    }

    // Verify EIP-4844 fields are absent.
    ensure!(header.blob_gas_used.is_none(), "blob gas used should be none");
    ensure!(header.excess_blob_gas.is_none(), "excess blob gas should be none");
    ensure!(header.parent_beacon_block_root.is_none(), "parent beacon root should be none");
    ensure!(header.requests_hash.is_none(), "requests hash should be none");

    // Verify transactions.
    let txs = block
        .transactions
        .as_transactions()
        .ok_or_else(|| anyhow!("expected full transactions"))?;
    ensure!(txs.len() == transfers.len() + 1, "expected anchor + {} transfer(s)", transfers.len());

    for (idx, expected) in transfers.iter().enumerate() {
        let tx = &txs[idx + 1];
        ensure!(*tx.hash() == expected.hash, "transfer tx hash mismatch at index {idx}");
        ensure!(tx.recover_signer()? == expected.from, "transfer signer mismatch at index {idx}");
    }

    ensure!(
        header.transactions_root == calculate_transaction_root(txs),
        "transactions root mismatch"
    );

    // Verify receipts.
    let receipts = provider
        .get_block_receipts(BlockId::Number(BlockNumberOrTag::Number(block_number)))
        .await?
        .ok_or_else(|| anyhow!("missing receipts for block {block_number}"))?;

    let primitive_receipts: Vec<_> = receipts
        .iter()
        .cloned()
        .map(|r: TransactionReceipt| r.into_primitives_receipt().inner)
        .collect();
    ensure!(
        header.receipts_root == calculate_receipt_root(&primitive_receipts),
        "receipts root mismatch"
    );

    let (logs_bloom, gas_used) =
        receipts.iter().try_fold((Bloom::ZERO, 0u64), |(bloom, gas), receipt| -> Result<_> {
            let receipt_bloom = receipt
                .inner
                .as_receipt_with_bloom()
                .ok_or_else(|| anyhow!("receipt missing bloom"))?;
            Ok((bloom | receipt_bloom.logs_bloom, gas.saturating_add(receipt.gas_used)))
        })?;
    ensure!(header.logs_bloom == logs_bloom, "logs bloom mismatch");
    ensure!(header.gas_used == gas_used, "gas used mismatch");

    // Verify withdrawals.
    if let Some(withdrawals) = block.withdrawals.as_ref() {
        ensure!(withdrawals.is_empty(), "expected no withdrawals");
        if let Some(root) = header.withdrawals_root {
            ensure!(root == calculate_withdrawals_root(withdrawals), "withdrawals root mismatch");
        }
    }

    // Cross-check block retrieval by hash.
    let by_hash = provider
        .get_block_by_hash(block.header.hash)
        .full()
        .await?
        .map(|b| b.map_transactions(TxEnvelope::from))
        .ok_or_else(|| anyhow!("missing block by hash"))?;

    ensure!(by_hash.header.state_root == header.state_root, "state root mismatch by hash");
    ensure!(by_hash.header.size == block.header.size, "block size mismatch");
    ensure!(
        by_hash.header.total_difficulty == block.header.total_difficulty,
        "total difficulty mismatch"
    );

    if let Some(size) = block.header.size {
        ensure!(size > U256::ZERO, "block size should be non-zero");
    }

    Ok(())
}

// ============================================================================
// Test
// ============================================================================

/// Tests P2P preconfirmation block production end-to-end.
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn p2p_preconfirmation_produces_block(env: &mut ShastaEnv) -> Result<()> {
    let beacon_server = BeaconStubServer::start().await?;

    // Configure and start the driver with preconfirmation enabled.
    let mut driver_config = DriverConfig::new(
        ClientConfig {
            l1_provider_source: env.l1_source.clone(),
            l2_provider_url: env.l2_http_0.clone(),
            l2_auth_provider_url: env.l2_auth_0.clone(),
            jwt_secret: env.jwt_secret.clone(),
            inbox_address: env.inbox_address,
        },
        Duration::from_millis(50),
        beacon_server.endpoint().clone(),
        None,
        None,
    );
    driver_config.preconfirmation_enabled = true;

    let rpc_client = Client::new(driver_config.client.clone()).await?;
    let event_syncer = Arc::new(EventSyncer::new(&driver_config, rpc_client.clone()).await?);
    let event_handle = spawn({
        let syncer = event_syncer.clone();
        async move { syncer.run().await }
    });

    event_syncer
        .wait_preconf_ingress_ready()
        .await
        .ok_or_else(|| anyhow!("preconfirmation ingress disabled"))?;

    // Set up driver client with safe-tip fallback.
    let embedded_client = EventSyncerDriverClient::new(event_syncer.clone(), rpc_client.clone());
    let driver_client = SafeTipDriverClient::new(Arc::new(embedded_client));

    // Derive signer from deterministic secret key.
    let (signer_sk, signer) = derive_signer(1);

    // Determine target block number.
    let submission_window_end = U256::from(1000u64);
    let event_sync_tip = driver_client.event_sync_tip().await?;
    let preconf_tip = driver_client.preconf_tip().await?;
    let commitment_block = event_sync_tip.max(preconf_tip) + U256::ONE;
    let commitment_block_num = commitment_block.to::<u64>();

    // Derive preconfirmation metadata from parent block.
    let parent_block =
        fetch_block_by_number(&env.client.l2_provider, commitment_block_num.saturating_sub(1))
            .await?;
    let parent_header = &parent_block.header.inner;
    let preconf_timestamp = parent_header.timestamp.saturating_add(1);
    let preconf_gas_limit = parent_header.gas_limit;
    let preconf_base_fee = compute_next_block_base_fee(
        &env.client.l2_provider,
        commitment_block_num.saturating_sub(1),
    )
    .await?;

    // Set up P2P nodes: external publisher and internal subscriber.
    let (mut ext_handle, ext_node) = P2pNode::new_with_validator_and_storage(
        test_p2p_config(),
        Box::new(LocalValidationAdapter::new(None)),
        Arc::new(InMemoryStorage::default()),
    )?;
    let ext_node_handle = spawn(async move { ext_node.run().await });

    let mut int_cfg = PreconfirmationClientConfig::new_with_resolver(
        test_p2p_config(),
        Arc::new(StaticLookaheadResolver::new(signer, submission_window_end)),
    );
    int_cfg.p2p.pre_dial_peers = vec![ext_handle.dialable_addr().await?];

    let internal_client = PreconfirmationClient::new(int_cfg, driver_client)?;
    let mut events = internal_client.subscribe();

    let mut event_loop = internal_client.sync_and_catchup().await?;
    let (event_loop_tx, mut event_loop_rx) = oneshot::channel::<anyhow::Result<()>>();
    let event_loop_handle = spawn(async move {
        let _ = event_loop_tx.send(event_loop.run().await.map_err(Into::into));
    });

    // Wait for peer connection.
    wait_for_peer_connected(&mut events).await;
    ext_handle.wait_for_peer_connected().await?;

    // Build anchor + test transfers using helper.
    let PreconfTxList { raw_tx_bytes, transfers } = build_preconf_txlist(
        &env.client,
        parent_block.header.hash,
        commitment_block_num,
        preconf_base_fee,
    )
    .await?;

    let (txlist, signed_commitment) = build_publish_payloads_with_txs(
        &signer_sk,
        signer,
        submission_window_end,
        commitment_block,
        preconf_timestamp,
        preconf_gas_limit,
        raw_tx_bytes,
    )?;

    // Publish over P2P.
    ext_handle.publish_raw_txlist(txlist).await?;
    ext_handle.publish_commitment(signed_commitment.clone()).await?;
    wait_for_commitment_and_txlist(&mut events).await;

    // Wait for block production or event loop failure.
    let produced_block = wait_for_block_or_loop_error(
        &env.client.l2_provider,
        commitment_block_num,
        Duration::from_secs(30),
        &mut event_loop_rx,
        "preconfirmation event loop",
    )
    .await?;

    // Verify block contents.
    let inbox_config = env.client.shasta.inbox.getConfig().call().await?;
    assert_block_fields(
        &env.client.l2_provider,
        &produced_block,
        &signed_commitment,
        inbox_config.basefeeSharingPctg,
        &transfers,
    )
    .await?;

    verify_anchor_block(&env.client, env.taiko_anchor_address)
        .await
        .context("verifying anchor block")?;

    // Cleanup background tasks.
    event_loop_handle.abort();
    ext_node_handle.abort();
    event_handle.abort();
    beacon_server.shutdown().await?;

    Ok(())
}
