//! E2E tests for P2P preconfirmation block production.

use std::{
    io::Write,
    net::{IpAddr, Ipv4Addr, SocketAddr},
    sync::Arc,
    time::Duration,
};

use alethia_reth_consensus::eip4396::{
    SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee,
};
use alloy_consensus::{
    EthereumTypedTransaction, SignableTransaction, TxEip1559, TxEnvelope,
    proofs::{calculate_receipt_root, calculate_transaction_root, calculate_withdrawals_root},
    transaction::SignerRecoverable,
};
use alloy_eips::{BlockId, BlockNumberOrTag, eip2718::Encodable2718};
use alloy_primitives::{Address, B64, B256, Bloom, Bytes, TxKind, U256};
use alloy_provider::Provider;
use alloy_rlp::encode as rlp_encode;
use alloy_rpc_types::{TransactionReceipt, eth::Block as RpcBlock};
use alloy_signer::Signer;
use alloy_signer_local::PrivateKeySigner;
use anyhow::{Context, Result, anyhow, ensure};
use driver::{
    DriverConfig,
    derivation::pipeline::shasta::anchor::{AnchorTxConstructor, AnchorV4Input},
    jsonrpc::DriverRpcServer,
    sync::{SyncStage, event::EventSyncer},
};
use flate2::{Compression, write::ZlibEncoder};
use preconfirmation_client::{
    DriverClient, PreconfirmationClient, PreconfirmationClientConfig,
    codec::ZlibTxListCodec,
    driver_interface::{JsonRpcDriverClient, JsonRpcDriverClientConfig},
    subscription::PreconfirmationEvent,
};
use preconfirmation_net::{InMemoryStorage, LocalValidationAdapter, P2pConfig, P2pNode};
use preconfirmation_types::{
    Bytes20, Bytes32, MAX_TXLIST_BYTES, PreconfCommitment, Preconfirmation, RawTxListGossip,
    SignedCommitment, TxListBytes, address_to_bytes20, keccak256_bytes, sign_commitment,
    u256_to_uint256, uint256_to_u256,
};
use protocol::shasta::{calculate_shasta_difficulty, encode_extra_data};
use rpc::client::{Client, ClientConfig, read_jwt_secret};
use secp256k1::SecretKey;
use serial_test::serial;
use test_context::test_context;
use test_harness::{
    BeaconStubServer, PRIORITY_FEE_GWEI, ShastaEnv, init_tracing,
    preconfirmation::{SafeTipDriverClient, StaticLookaheadResolver},
    verify_anchor_block,
};
use tokio::{spawn, sync::oneshot, time::sleep};

/// Creates a local-only P2P config for tests (ephemeral ports, discovery disabled).
fn test_p2p_config() -> P2pConfig {
    let localhost_ephemeral = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0);
    let chain_id =
        std::env::var("L2_CHAIN_ID").ok().and_then(|v| v.parse().ok()).unwrap_or(167_001);

    P2pConfig {
        chain_id,
        listen_addr: localhost_ephemeral,
        discovery_listen: localhost_ephemeral,
        enable_discovery: false,
        ..P2pConfig::default()
    }
}

/// Signed transfer transaction with expected hash and sender for assertions.
struct TransferPayload {
    raw_bytes: Bytes,
    hash: B256,
    from: Address,
}

/// Computes the expected base fee for the next block using EIP-4396 rules.
async fn compute_next_block_base_fee<P>(provider: &P, parent_block_number: u64) -> Result<u64>
where
    P: Provider + Send + Sync,
{
    let get_block = |n| async move {
        provider
            .get_block_by_number(BlockNumberOrTag::Number(n))
            .await?
            .ok_or_else(|| anyhow!("missing block {n}"))
    };

    let parent_block = get_block(parent_block_number).await?;
    let parent_header = parent_block.header.inner;

    if parent_header.number == 0 {
        return Ok(SHASTA_INITIAL_BASE_FEE);
    }

    let grandparent = get_block(parent_block_number.saturating_sub(1)).await?;
    parent_header.base_fee_per_gas.ok_or_else(|| anyhow!("parent base fee missing"))?;

    let time_delta = parent_header.timestamp.saturating_sub(grandparent.header.inner.timestamp);
    Ok(calculate_next_block_eip4396_base_fee(&parent_header, time_delta))
}

/// Builds and signs an EIP-1559 transfer transaction.
async fn build_signed_transfer<P>(
    provider: &P,
    block_number: u64,
    private_key: &str,
    to: Address,
    value: U256,
) -> Result<TransferPayload>
where
    P: Provider + Send + Sync,
{
    let signer: PrivateKeySigner = private_key.parse()?;
    let from = signer.address();

    let nonce = provider
        .get_transaction_count(from)
        .block_id(BlockId::Number(BlockNumberOrTag::Pending))
        .await?;
    let chain_id = provider.get_chain_id().await?;
    let base_fee = compute_next_block_base_fee(provider, block_number.saturating_sub(1)).await?;

    let tx = TxEip1559 {
        chain_id,
        nonce,
        max_fee_per_gas: PRIORITY_FEE_GWEI + u128::from(base_fee),
        max_priority_fee_per_gas: PRIORITY_FEE_GWEI,
        gas_limit: 21_000,
        to: TxKind::Call(to),
        value,
        ..Default::default()
    };

    let signature = signer.sign_hash(&tx.signature_hash()).await?;
    let envelope = TxEnvelope::new_unhashed(EthereumTypedTransaction::Eip1559(tx), signature);

    Ok(TransferPayload { raw_bytes: envelope.encoded_2718().into(), hash: *envelope.hash(), from })
}

/// Constructs the anchor transaction bytes for a preconfirmation block.
async fn build_anchor_tx_bytes<P>(
    client: &Client<P>,
    parent_hash: B256,
    block_number: u64,
    base_fee: u64,
) -> Result<Bytes>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    let anchor_block_number = client.l1_provider.get_block_number().await?;
    let anchor_block = client
        .l1_provider
        .get_block_by_number(BlockNumberOrTag::Number(anchor_block_number))
        .await?
        .ok_or_else(|| anyhow!("missing L1 anchor block {anchor_block_number}"))?;

    let constructor = AnchorTxConstructor::new(client.clone()).await?;
    let tx = constructor
        .assemble_anchor_v4_tx(
            parent_hash,
            AnchorV4Input {
                anchor_block_number,
                anchor_block_hash: anchor_block.header.hash,
                anchor_state_root: anchor_block.header.inner.state_root,
                l2_height: block_number,
                base_fee: U256::from(base_fee),
            },
        )
        .await?;

    Ok(tx.encoded_2718().into())
}

/// Assembles a compressed txlist and signed commitment for P2P gossip.
fn build_publish_payloads(
    signer_sk: &SecretKey,
    signer: Address,
    submission_window_end: U256,
    block_number: U256,
    timestamp: u64,
    gas_limit: u64,
    raw_tx_bytes: Vec<Bytes>,
) -> Result<(RawTxListGossip, SignedCommitment)> {
    // Encode and compress the transaction list.
    let tx_list_items: Vec<Vec<u8>> = raw_tx_bytes.iter().map(|tx| tx.to_vec()).collect();
    let tx_list = rlp_encode(&tx_list_items);

    let first_byte = *tx_list.first().ok_or_else(|| anyhow!("empty tx list encoding"))?;
    ensure!(first_byte >= 0xc0, "tx list is not an RLP list (first byte 0x{first_byte:02x})");

    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(&tx_list)?;
    let compressed = encoder.finish()?;

    let txlist_bytes = TxListBytes::try_from(compressed)
        .map_err(|(_, err)| anyhow!("txlist bytes error: {err}"))?;

    // Verify round-trip decoding.
    let codec = ZlibTxListCodec::new(MAX_TXLIST_BYTES);
    let decoded = codec.decode(txlist_bytes.as_ref()).context("decode txlist before publishing")?;
    ensure!(decoded.len() == raw_tx_bytes.len(), "decoded txlist length mismatch");

    let raw_tx_list_hash = Bytes32::try_from(keccak256_bytes(txlist_bytes.as_ref()).to_vec())
        .map_err(|(_, err)| anyhow!("txlist hash error: {err}"))?;

    let txlist =
        RawTxListGossip { raw_tx_list_hash: raw_tx_list_hash.clone(), txlist: txlist_bytes };

    let preconf = Preconfirmation {
        eop: false,
        block_number: u256_to_uint256(block_number),
        timestamp: u256_to_uint256(U256::from(timestamp)),
        gas_limit: u256_to_uint256(U256::from(gas_limit)),
        proposal_id: u256_to_uint256(block_number),
        coinbase: address_to_bytes20(signer),
        submission_window_end: u256_to_uint256(submission_window_end),
        raw_tx_list_hash,
        ..Default::default()
    };

    let commitment = PreconfCommitment { preconf, slasher_address: Bytes20::default() };
    let signature = sign_commitment(&commitment, signer_sk)?;

    Ok((txlist, SignedCommitment { commitment, signature }))
}

/// Waits for a peer connection event.
async fn wait_for_peer_connected(
    events: &mut tokio::sync::broadcast::Receiver<PreconfirmationEvent>,
) {
    loop {
        match events.recv().await {
            Ok(PreconfirmationEvent::PeerConnected(_)) => return,
            Ok(_) => continue,
            Err(err) => panic!("preconfirmation event stream closed: {err}"),
        }
    }
}

/// Waits for both a commitment and its transaction list to be received.
async fn wait_for_commitment_and_txlist(
    events: &mut tokio::sync::broadcast::Receiver<PreconfirmationEvent>,
) {
    let mut saw_commitment = false;
    let mut saw_txlist = false;

    while !(saw_commitment && saw_txlist) {
        match events.recv().await {
            Ok(PreconfirmationEvent::NewCommitment(_)) => saw_commitment = true,
            Ok(PreconfirmationEvent::NewTxList(_)) => saw_txlist = true,
            Ok(_) => continue,
            Err(err) => panic!("preconfirmation event stream closed: {err}"),
        }
    }
}

fn map_block_transactions(block: RpcBlock) -> RpcBlock<TxEnvelope> {
    block.map_transactions(TxEnvelope::from)
}

/// Fetches a block by number with full transaction details.
async fn fetch_block_by_number<P>(provider: &P, block_number: u64) -> Result<RpcBlock<TxEnvelope>>
where
    P: Provider + Send + Sync,
{
    provider
        .get_block_by_number(BlockNumberOrTag::Number(block_number))
        .full()
        .await?
        .map(map_block_transactions)
        .ok_or_else(|| anyhow!("missing block {block_number}"))
}

/// Polls for a block until it appears or timeout expires.
async fn wait_for_block<P>(
    provider: &P,
    block_number: u64,
    timeout: Duration,
) -> Result<RpcBlock<TxEnvelope>>
where
    P: Provider + Send + Sync,
{
    let deadline = tokio::time::Instant::now() + timeout;

    loop {
        if tokio::time::Instant::now() >= deadline {
            return Err(anyhow!("timed out waiting for block {block_number}"));
        }

        if let Ok(Some(block)) =
            provider.get_block_by_number(BlockNumberOrTag::Number(block_number)).full().await
        {
            return Ok(map_block_transactions(block));
        }

        sleep(Duration::from_millis(200)).await;
    }
}

/// Validates the produced block against the preconfirmation commitment.
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
        .map(map_block_transactions)
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

/// Tests P2P preconfirmation block production end-to-end.
#[test_context(ShastaEnv)]
#[serial]
#[tokio::test(flavor = "multi_thread")]
async fn p2p_preconfirmation_produces_block(env: &mut ShastaEnv) -> Result<()> {
    init_tracing("info");

    let beacon_server = BeaconStubServer::start().await?;
    let jwt_secret =
        read_jwt_secret(env.jwt_secret.clone()).ok_or_else(|| anyhow!("missing jwt secret"))?;
    let l1_http = std::env::var("L1_HTTP")?;

    // Configure and start the driver with preconfirmation enabled.
    let mut driver_config = DriverConfig::new(
        ClientConfig {
            l1_provider_source: env.l1_source.clone(),
            l2_provider_url: env.l2_http.clone(),
            l2_auth_provider_url: env.l2_auth.clone(),
            jwt_secret: env.jwt_secret.clone(),
            inbox_address: env.inbox_address,
        },
        Duration::from_millis(50),
        beacon_server.endpoint().clone(),
        None,
        None,
    );
    driver_config.preconfirmation_enabled = true;

    let driver_client = Client::new(driver_config.client.clone()).await?;
    let event_syncer = Arc::new(EventSyncer::new(&driver_config, driver_client.clone()).await?);
    let event_handle = spawn({
        let syncer = event_syncer.clone();
        async move { syncer.run().await }
    });

    event_syncer
        .wait_preconf_ingress_ready()
        .await
        .ok_or_else(|| anyhow!("preconfirmation ingress disabled"))?;

    let rpc_server =
        DriverRpcServer::start("127.0.0.1:0".parse()?, jwt_secret, event_syncer).await?;

    // Set up driver client with safe-tip fallback.
    let driver_client_cfg = JsonRpcDriverClientConfig::with_http_endpoint(
        rpc_server.http_url().parse()?,
        env.jwt_secret.clone(),
        l1_http.parse()?,
        env.l2_http.to_string().parse()?,
        env.inbox_address,
    );
    let driver_client =
        SafeTipDriverClient::new(JsonRpcDriverClient::new(driver_client_cfg).await?);

    // Derive signer from deterministic secret key.
    let signer_sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
    let signer = preconfirmation_types::public_key_to_address(
        &secp256k1::PublicKey::from_secret_key(&secp256k1::Secp256k1::new(), &signer_sk),
    );

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
    let (event_loop_tx, mut event_loop_rx) = oneshot::channel();
    let event_loop_handle = spawn(async move {
        let _ = event_loop_tx.send(event_loop.run().await);
    });

    // Wait for peer connection.
    wait_for_peer_connected(&mut events).await;
    ext_handle.wait_for_peer_connected().await?;

    // Build anchor transaction.
    let anchor_tx = build_anchor_tx_bytes(
        &env.client,
        parent_block.header.hash,
        commitment_block_num,
        preconf_base_fee,
    )
    .await?;

    // Build transfer transactions, funding test account if needed.
    let test_key = std::env::var("TEST_ACCOUNT_PRIVATE_KEY")?;
    let test_signer: PrivateKeySigner = test_key.parse()?;
    let test_address = test_signer.address();
    let test_balance = env.client.l2_provider.get_balance(test_address).await?;

    let mut transfers = Vec::new();
    if test_balance.is_zero() {
        let funder_key = std::env::var("PRIVATE_KEY")?;
        let funder_signer: PrivateKeySigner = funder_key.parse()?;
        let funder_balance = env.client.l2_provider.get_balance(funder_signer.address()).await?;
        let fund_amount = U256::from(1_000_000_000_000_000_000u128); // 1 ETH
        ensure!(funder_balance > fund_amount, "funder balance too low to seed test account");

        transfers.push(
            build_signed_transfer(
                &env.client.l2_provider,
                commitment_block_num,
                &funder_key,
                test_address,
                fund_amount,
            )
            .await?,
        );
    }

    transfers.push(
        build_signed_transfer(
            &env.client.l2_provider,
            commitment_block_num,
            &test_key,
            Address::repeat_byte(0x11),
            U256::from(1u64),
        )
        .await?,
    );

    // Build transaction list: anchor first, then transfers.
    let mut txlist_transactions = vec![anchor_tx];
    txlist_transactions.extend(transfers.iter().map(|t| t.raw_bytes.clone()));

    let (txlist, signed_commitment) = build_publish_payloads(
        &signer_sk,
        signer,
        submission_window_end,
        commitment_block,
        preconf_timestamp,
        preconf_gas_limit,
        txlist_transactions,
    )?;

    // Publish over P2P.
    ext_handle.publish_raw_txlist(txlist).await?;
    ext_handle.publish_commitment(signed_commitment.clone()).await?;
    wait_for_commitment_and_txlist(&mut events).await;

    // Wait for block production or event loop failure.
    let produced_block = tokio::select! {
        block = wait_for_block(&env.client.l2_provider, commitment_block_num, Duration::from_secs(30)) => block?,
        result = &mut event_loop_rx => {
            let err_msg = match result {
                Ok(Ok(())) => "preconfirmation event loop exited unexpectedly",
                Ok(Err(err)) => return Err(anyhow!("preconfirmation event loop error: {err}")),
                Err(_) => "preconfirmation event loop handle dropped",
            };
            return Err(anyhow!(err_msg));
        }
    };

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
    rpc_server.stop().await;
    beacon_server.shutdown().await?;

    Ok(())
}
