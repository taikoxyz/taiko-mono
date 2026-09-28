//! Local cross-client regression using the existing two-node reth harness.

use super::*;
use alloy::{
    consensus::SidecarBuilder,
    network::TransactionBuilder4844,
    rpc::types::{TransactionInput, TransactionRequest},
};
use alloy_consensus::TxEnvelope;
use alloy_eips::{eip2718::Encodable2718, eip7594::BlobTransactionSidecarVariant};
use alloy_primitives::hex;
use alloy_rlp::{Encodable, Header};
use flate2::{Compression, write::ZlibEncoder};
use protocol::shasta::{BlobCoder, manifest::DerivationSourceManifest};
use std::{
    io::Write,
    process::{Child, Command, Stdio},
};

struct GoDriverProcess {
    child: Child,
}

impl GoDriverProcess {
    fn check_running(&mut self) -> Result<()> {
        ensure!(self.child.try_wait()?.is_none(), "Go driver exited during parity test");
        Ok(())
    }

    fn shutdown(mut self) -> Result<()> {
        if self.child.try_wait()?.is_none() {
            self.child.kill()?;
        }
        self.child.wait()?;
        Ok(())
    }
}

impl Drop for GoDriverProcess {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

async fn start_go_driver(env: &ShastaEnv, beacon: &BeaconStubServer) -> Result<GoDriverProcess> {
    let binary = std::env::var("TAIKO_GO_DRIVER_BIN")
        .context("run script/test_derivation_parity.sh to build the Go driver")?;
    let child = Command::new(binary)
        .arg("driver")
        .args(["--l1.ws", &std::env::var("HARNESS_L1_WS")?])
        .args(["--l2.ws", &std::env::var("L2_WS_1")?])
        .args(["--l2.auth", &std::env::var("L2_AUTH_1")?])
        .args(["--jwtSecret", &std::env::var("JWT_SECRET")?])
        .args(["--inbox", &env.inbox_address.to_string()])
        .args(["--taikoAnchor", &env.taiko_anchor_address.to_string()])
        .args(["--l1.beacon", beacon.endpoint().as_str()])
        .args(["--p2p.sync=false", "--p2p.disable=true", "--preconfirmation.serverPort=0"])
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .spawn()
        .context("starting Go driver")?;
    Ok(GoDriverProcess { child })
}

fn rlp_list(contents: &[u8]) -> Vec<u8> {
    let mut out = Vec::new();
    Header { list: true, payload_length: contents.len() }.encode(&mut out);
    out.extend_from_slice(contents);
    out
}

fn fixture_tx_list(name: &str) -> Result<Vec<u8>> {
    let corpus: serde_json::Value = serde_json::from_str(include_str!(
        "../../../../../../testdata/derivation_vectors/manifest_cases.json"
    ))?;
    let v = corpus["cases"]
        .as_array()
        .context("missing fixture cases")?
        .iter()
        .find(|v| v["name"] == name)
        .context("missing transaction fixture")?;
    Ok(hex::decode(v["engine_tx_list_hex"].as_str().context("missing transaction list")?)?)
}

// Keep current chain metadata valid while replacing only the transaction encoding or
// stream termination under test. Reusing fixed fixture timestamps would mask F9.
fn proposal_variant(
    base: BuiltProposalTx,
    case: &str,
) -> Result<(TransactionRequest, BlobTransactionSidecarVariant)> {
    let BlobTransactionSidecarVariant::Eip4844(original) = base.blob_sidecar() else {
        anyhow::bail!("unexpected proposal sidecar variant");
    };
    let data = BlobCoder::decode_blobs(&original.blobs).context("decode test sidecar")?.concat();
    let manifest = DerivationSourceManifest::decompress_and_decode(&data, 0)?;
    ensure!(manifest.blocks.len() == 1, "expected one template block");
    let block = &manifest.blocks[0];
    let mut fields = Vec::new();
    block.timestamp.encode(&mut fields);
    block.coinbase.encode(&mut fields);
    block.anchor_block_number.encode(&mut fields);
    block.gas_limit.encode(&mut fields);
    if case.starts_with("type") || case.starts_with("blob") {
        fields.extend_from_slice(&fixture_tx_list(case)?);
    } else {
        fields.push(0xc0);
    }
    let raw = rlp_list(&rlp_list(&rlp_list(&fields)));
    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(&raw)?;
    let compressed = if case == "nonfinal_stream" {
        encoder.flush()?;
        encoder.get_ref().clone()
    } else {
        let mut compressed = encoder.finish()?;
        if case == "trailer_missing_1" {
            compressed.pop();
        }
        compressed
    };
    let mut payload = vec![0u8; 64];
    payload[31] = 1;
    payload[32..64].copy_from_slice(&U256::from(compressed.len()).to_be_bytes::<32>());
    payload.extend_from_slice(&compressed);
    let sidecar: alloy_consensus::BlobTransactionSidecar =
        SidecarBuilder::<BlobCoder>::from_slice(&payload).build()?;
    ensure!(sidecar.blobs.len() == original.blobs.len(), "template blob reference changed");
    let original_request = base.to_transaction_request();
    let request = TransactionRequest {
        to: original_request.to,
        input: TransactionInput::both(
            original_request.input.into_input().context("missing proposal calldata")?,
        ),
        value: Some(U256::ZERO),
        ..Default::default()
    }
    .with_blob_sidecar(sidecar.clone());
    Ok((request, BlobTransactionSidecarVariant::Eip4844(sidecar)))
}

async fn submit_raw_proposal(
    env: &ShastaEnv,
    request: TransactionRequest,
) -> Result<(u64, alloy_primitives::Address)> {
    let wallet = env
        .client_config
        .l1_provider_source
        .to_provider_with_wallet(env.l1_proposer_private_key)
        .await?;
    let receipt = wallet.send_transaction(request).await?.get_receipt().await?;
    ensure!(receipt.status(), "proposal reverted");
    let log = receipt
        .logs()
        .iter()
        .find(|log| log.address() == env.inbox_address)
        .context("missing proposal event")?;
    Ok((decode_proposal_id(log)?, receipt.from))
}

async fn enqueue_invalid_forced_source(
    env: &ShastaEnv,
    proposer: &Client,
    beacon: &BeaconStubServer,
) -> Result<()> {
    let (mut request, sidecar) =
        proposal_variant(build_empty_proposal(env, proposer).await?, "type2_parity_2")?;
    let reference = bindings::inbox::LibBlobs::BlobReference {
        blobStartIndex: 0,
        numBlobs: 1,
        offset: alloy_primitives::aliases::U24::ZERO,
    };
    let fee = proposer.shasta.inbox.getCurrentForcedInclusionFee().call().await?;
    request.input = TransactionInput::both(
        proposer.shasta.inbox.saveForcedInclusion(reference).calldata().clone(),
    );
    request.value = Some(U256::from(fee) * U256::from(1_000_000_000u64));
    let wallet = env
        .client_config
        .l1_provider_source
        .to_provider_with_wallet(env.l1_proposer_private_key)
        .await?;
    let receipt = wallet.send_transaction(request).await?.get_receipt().await?;
    ensure!(receipt.status(), "forced inclusion submission reverted");
    let block = proposer
        .l1_provider
        .get_block_by_number(receipt.block_number.context("missing forced-inclusion block")?.into())
        .await?
        .context("missing forced-inclusion header")?;
    beacon.add_blob_sidecar(BeaconStubServer::timestamp_to_slot(block.header.timestamp), sidecar);
    Ok(())
}

async fn wait_for_go_proposal(
    go: &mut GoDriverProcess,
    client: &Client,
    proposal_id: u64,
    prior: u64,
) -> Result<u64> {
    let deadline = tokio::time::Instant::now() + Duration::from_secs(120);
    loop {
        go.check_running()?;
        if let Some(number) =
            client.last_certain_block_id_by_batch_id(U256::from(proposal_id)).await?
        {
            let height = number.to::<u64>();
            if height > prior && client.l2_provider.get_block_number().await? >= height {
                return Ok(height);
            }
        }
        ensure!(tokio::time::Instant::now() < deadline, "Go proposal {proposal_id} timed out");
        tokio::time::sleep(Duration::from_millis(100)).await;
    }
}

async fn assert_block_parity(
    rust: &Client,
    go: &Client,
    height: u64,
    anchor: alloy_primitives::Address,
    expected_coinbase: alloy_primitives::Address,
) -> Result<()> {
    let rust_block = rust
        .l2_provider
        .get_block_by_number(height.into())
        .full()
        .await?
        .context("missing Rust block")?;
    let go_block = go
        .l2_provider
        .get_block_by_number(height.into())
        .full()
        .await?
        .context("missing Go block")?;
    ensure!(
        rust_block.header.hash == go_block.header.hash,
        "block hash mismatch at {height}: Rust {} Go {}",
        rust_block.header.hash,
        go_block.header.hash
    );
    ensure!(
        rust_block.header.beneficiary == expected_coinbase,
        "unexpected source fallback/retention at {height}"
    );
    let encoded = |block: &alloy_rpc_types::Block| -> Result<Vec<Vec<u8>>> {
        Ok(block
            .transactions
            .as_transactions()
            .context("expected full transactions")?
            .iter()
            .cloned()
            .map(|tx| TxEnvelope::from(tx).encoded_2718())
            .collect())
    };
    ensure!(encoded(&rust_block)? == encoded(&go_block)?, "transaction bytes differ at {height}");
    ensure!(rust_block.transactions.len() == 1, "expected an anchor-only block at {height}");
    let anchor_hash = rust_block.transactions.hashes().next().context("missing anchor")?;
    for client in [rust, go] {
        let receipt = client
            .l2_provider
            .get_transaction_receipt(anchor_hash)
            .await?
            .context("missing anchor receipt")?;
        ensure!(receipt.to == Some(anchor), "wrong anchor target");
        ensure!(receipt.status(), "anchor reverted at {height}");
    }
    Ok(())
}

#[test_context(ShastaEnv)]
#[serial]
#[ignore = "requires the Go binary built by script/test_derivation_parity.sh"]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn derivation_split_parity(env: &mut ShastaEnv) -> Result<()> {
    let beacon = BeaconStubServer::start().await?;
    let proposer = proposer_client(env).await?;
    let mut secondary = env.client_config.clone();
    secondary.l2_provider_url = std::env::var("L2_WS_1")?.parse()?;
    secondary.l2_auth_provider_url = std::env::var("L2_AUTH_1")?.parse()?;
    let go_client = Client::new(secondary).await?;
    let rust_parent = proposer
        .l2_provider
        .get_block_by_number(alloy_eips::BlockNumberOrTag::Latest)
        .await?
        .context("missing Rust parent")?;
    let go_parent = go_client
        .l2_provider
        .get_block_by_number(alloy_eips::BlockNumberOrTag::Latest)
        .await?
        .context("missing Go parent")?;
    ensure!(rust_parent.header.hash == go_parent.header.hash, "test parents differ");
    let mut go = start_go_driver(env, &beacon).await?;
    let (mut syncer, rust_client) = start_event_syncer(env, &beacon).await?;
    let cases = std::env::var("DERIVATION_PARITY_CASES").unwrap_or_else(|_|
        "control,type2_parity_2,type2_fee_overflow,type2_chain_overflow,blob_sidecar_v0,blob_sidecar_v1,forced_type2_parity_2,trailer_missing_1,nonfinal_stream,type2_unrecoverable,control".to_string());
    let result: Result<()> = async {
        for case in cases.split(',') {
            let _: serde_json::Value =
                rust_client.l1_provider.raw_request("evm_increaseTime".into(), [3u64]).await?;
            let _: serde_json::Value = rust_client
                .l1_provider
                .raw_request("evm_mine".into(), Vec::<String>::new())
                .await?;

            if case == "forced_type2_parity_2" {
                enqueue_invalid_forced_source(env, &proposer, &beacon).await?;
                // Keep the following source above the inherited forced block timestamp and
                // in a distinct beacon slot, whose default sidecar is the ordinary source.
                let _: serde_json::Value =
                    rust_client.l1_provider.raw_request("evm_increaseTime".into(), [12u64]).await?;
                let _: serde_json::Value = rust_client
                    .l1_provider
                    .raw_request("evm_mine".into(), Vec::<String>::new())
                    .await?;
            }
            let before = rust_client.l2_provider.get_block_number().await?;
            let baseline = batch_row_baseline(&rust_client).await?;
            let (request, sidecar) =
                proposal_variant(build_empty_proposal(env, &proposer).await?, case)?;
            beacon.set_default_blob_sidecar(sidecar);
            let (proposal_id, sender) = submit_raw_proposal(env, request).await?;
            ensure!(proposal_id == baseline.proposal_id, "proposal counter changed");
            let rust_height = wait_for_proposal_processed(
                &mut syncer,
                &rust_client,
                &baseline,
                before,
                Duration::from_secs(120),
            )
            .await?;
            let go_height = wait_for_go_proposal(&mut go, &go_client, proposal_id, before).await?;
            ensure!(rust_height == go_height, "derived heights differ for {case}");
            let forced = case == "forced_type2_parity_2";
            ensure!(rust_height == before + if forced { 2 } else { 1 }, "wrong source block count");
            if forced {
                assert_block_parity(
                    &rust_client,
                    &go_client,
                    before + 1,
                    env.taiko_anchor_address,
                    sender,
                )
                .await
                .context("defaulted forced source")?;
            }
            assert_block_parity(
                &rust_client,
                &go_client,
                rust_height,
                env.taiko_anchor_address,
                if forced || case == "control" || case == "type2_unrecoverable" {
                    env.l2_suggested_fee_recipient
                } else {
                    sender
                },
            )
            .await
            .with_context(|| format!("parity case {case}"))?;
            info!(
                case,
                proposal_id,
                height = rust_height,
                "Go/Rust parity and successful anchor confirmed"
            );
        }
        Ok(())
    }
    .await;
    let rust_stop = syncer.finish(result).await;
    let go_stop = go.shutdown();
    rust_stop?;
    go_stop
}
