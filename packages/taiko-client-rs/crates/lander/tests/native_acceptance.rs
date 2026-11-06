//! Actual four-validator native consensus, direct fees, FI, landing and restart acceptance.
mod support;
#[path = "support/trust_timeout.rs"]
mod trust_timeout;
use alloy::sol_types::SolCall;
use alloy_eips::{BlockId, BlockNumberOrTag, eip2718::Encodable2718};
use alloy_primitives::{Address, B256, Bytes, U256};
use alloy_provider::Provider;
use anyhow::{Context, Result, ensure};
use lander::{
    ProofRequest, SidecarMode,
    batch::{BatchBuilder, BatchBuilderConfig, BatchSource},
    comet::HttpCometSource,
    l1::{LandingSource, RpcLandingSource},
    tx::{FeeCaps, RpcTransactionTransport, TransactionTransport},
};
use std::{sync::Arc, time::Duration};
use support::{
    ContractFixture,
    contracts::{EtnaInbox, receipt, transact, view},
    fixtures::limits,
};
use test_harness::{
    ContractConsensus, dev_signer, mine_l1_blocks, set_interval_mining, wait_until,
};

async fn land(f: &ContractFixture, c: &ContractConsensus) -> Result<(ProofRequest, B256)> {
    let source = Arc::new(RpcLandingSource::new(
        f.anvil.provider.clone(),
        f.l2.provider.clone(),
        f.params.clone(),
    ));
    let snapshot = source.snapshot().await?;
    let builder = BatchBuilder::new(
        Arc::new(HttpCometSource::new(c.cmt.url(), Duration::from_secs(10), 16 * 1024 * 1024)?),
        source.clone(),
        BatchBuilderConfig {
            params: f.params.clone(),
            limits: limits(),
            mode: SidecarMode::Eip7594,
            engine: Arc::new(f.l2.engine()?),
            engine_timeout: Duration::from_secs(10),
            max_batch_blocks: source.deployment(&snapshot).await?.max_batch_blocks,
        },
    )?;
    let request = builder.prepare(snapshot).await?.context("nonempty grid batch")?;
    f.expect_statement(request.batch.statement_hash).await?;
    let transport = RpcTransactionTransport::new(
        f.anvil.provider.clone(),
        dev_signer(),
        FeeCaps {
            max_fee_per_gas: 20_000_000_000,
            max_priority_fee_per_gas: 1_000_000_000,
            max_fee_per_blob_gas: 20_000_000_000,
        },
    )?;
    let proof = Bytes::from_static(&[0]);
    let tx = transport.sign(&request, &proof).await?;
    transport.broadcast(&tx).await?;
    let landed = receipt(&f.anvil.provider, tx.hash).await?;
    ensure!(landed.status(), "dummy landing reverted");
    let event = landed.decoded_log::<EtnaInbox::Landed>().context("real Landed event")?;
    assert_eq!(event.data.lastHeight, request.batch.input.lastHeight);
    let height = request.batch.input.lastHeight.to::<u64>();
    assert_eq!(f.checkpoint().await?.0, height);
    // The record's validator-state word is the hash of the state the actual app serves there;
    // the app retains it until a later checkpoint lands.
    let record = view(
        &f.anvil.provider,
        f.inbox,
        EtnaInbox::landingsCall { _height: request.batch.input.lastHeight },
        None,
    )
    .await?;
    let served = c.cmt.abci_query(&format!("/val_state/{height}")).await?;
    let served = served.with_context(|| format!("the app refuses /val_state/{height}"))?;
    assert_eq!(record.valStateHash, alloy_primitives::keccak256(served), "word 4 at {height}");
    Ok((request, tx.hash))
}

async fn recover_landed_execution(
    fixture: &ContractFixture,
    archived: &[alloy_eips::eip4844::Blob],
    checkpoint: &lander::codec::LandedRange,
) -> Result<()> {
    use abci::{Engine, PayloadVerdict};
    let recovered = test_harness::StandaloneReth::start().await?;
    assert_eq!(recovered.genesis.hash, fixture.genesis.genesis_hash);
    assert!(recovered.provider.get_block_by_number(1.into()).await?.is_none());
    let limits = lander::Limits {
        max_blocks: 100,
        max_blobs: 6,
        max_payload_bytes: 6 * lander::blob::PAYLOAD_BYTES_PER_BLOB,
        max_message_bytes: 22_020_096,
        max_decompressed_bytes: 64 << 20,
    };
    let payload = lander::blob::decode(archived, &limits)?;
    let blocks = lander::codec::decode_landed(&payload, checkpoint)?;
    let engine = recovered.engine()?;
    for published in &blocks {
        assert_eq!(engine.new_payload(&published.block).await?, PayloadVerdict::Valid);
        let hash = published.block.header.hash_slow();
        assert_eq!(engine.forkchoice(hash, hash, B256::ZERO).await?, PayloadVerdict::Valid);
    }
    let terminal =
        engine.header_by_number(checkpoint.last_height).await?.context("recovered EL head")?;
    assert_eq!(terminal.hash_slow(), checkpoint.last_block_hash);
    assert_eq!(terminal.state_root, checkpoint.last_state_root);
    let mut tampered = blocks.last().context("published block")?.block.clone();
    tampered.header.state_root = B256::repeat_byte(0xee);
    assert_ne!(engine.new_payload(&tampered).await?, PayloadVerdict::Valid);
    recovered.stop().await
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn four_validator_native_consensus_fees_fi_epoch_landing_and_restart() -> Result<()> {
    test_harness::init_tracing();
    let f = ContractFixture::deploy_validators(4).await?;
    abci::build_committee_record(
        &abci::RpcL1Source::new(f.anvil.provider.clone()),
        &f.params,
        f.genesis.genesis_cutoff,
        None,
    )
    .await?;
    let p = &f.anvil.provider;
    let l2 = &f.l2.provider;
    set_interval_mining(p, 1).await?;
    let dirs = (0..4).map(|i| f.signer_storage.path().join(i.to_string())).collect();
    let mut c =
        ContractConsensus::start(f.anvil.http.clone(), &f.l2, f.params.clone(), dirs).await?;
    assert_eq!(c.cmt.validators(Some(1)).await?.len(), 4);
    let ordinary = test_harness::sign_transfer(
        l2,
        &dev_signer(),
        Address::repeat_byte(0x91),
        U256::from(123),
        0,
    )
    .await?
    .encoded_2718();
    let payment = *l2.send_raw_transaction(&ordinary).await?.tx_hash();
    c.broadcast_to_peers(&ordinary).await?;
    let transfer = receipt(l2, payment).await.context("ordinary pool transaction inclusion")?;
    assert!(transfer.status());
    let h = transfer.block_number.context("normal height")?;
    c.wait_for_height(h + 1).await?;
    let header =
        l2.get_block_by_number(BlockNumberOrTag::Number(h)).await?.context("normal block")?.header;
    assert_eq!(header.extra_data[0], 100);
    let fee = U256::from(transfer.effective_gas_price) * U256::from(transfer.gas_used);
    assert_eq!(
        l2.get_balance(header.beneficiary).block_id(BlockId::number(h)).await? -
            l2.get_balance(header.beneficiary).block_id(BlockId::number(h - 1)).await?,
        fee
    );
    let raw = test_harness::sign_transfer(
        l2,
        &dev_signer(),
        Address::repeat_byte(0x92),
        U256::from(456),
        1,
    )
    .await?
    .encoded_2718();
    let forced_hash = alloy_primitives::keccak256(&raw);
    let (_, _, fi_fee) = f.save_forced_inclusion(&raw).await?;
    let included = receipt(l2, forced_hash).await.context("calldata FI transaction inclusion")?;
    assert!(included.status());
    let fi_height = included.block_number.context("FI height")?;
    c.wait_for_height(fi_height + 1).await?;
    assert_eq!(c.cmt.envelope(fi_height).await?.block.transactions[0].as_ref(), raw);
    c.wait_for_height(18.max(fi_height + 1)).await?;
    let epoch = c.cmt.committee(1).await?.context("native epoch 1")?;
    assert_eq!(epoch.members.len(), 4);
    assert_eq!(c.cmt.validators(Some(f.genesis.epoch_len + 1)).await?.len(), 4);
    let trust_path = c.app_dir(0).join("checkpoint-trust.sock");
    let before_timeout = trust_timeout::observe(&trust_path).await?;
    let old_session = before_timeout["session_id"].as_str().context("pre-timeout session")?;
    let hrs = c.signing_state(0)?;
    let timeout = trust_timeout::TrustTimeout::install(&c.app_dir(0)).await?;
    timeout.wait_recovered(old_session).await?;
    assert!(
        timeout.ready_when_delayed.load(std::sync::atomic::Ordering::SeqCst),
        "the actual app stayed Ready at the failed signer-specific query"
    );
    // The supervisor starts Comet only after the fresh session is Ready; recovery is complete
    // once that Comet serves again and its signer signs above the refused step, with no
    // further refusal and restart.
    let refused_height = hrs["height"].as_str().unwrap().parse::<u64>()?;
    wait_until(
        "recovered validator signs above the refused step",
        Duration::from_secs(60),
        Duration::from_millis(200),
        || async {
            let serving = c.peers[0].latest_height().await.is_ok();
            let signed = c.signing_state(0)?["height"].as_str().unwrap().parse::<u64>()?;
            Ok((serving && signed > refused_height).then_some(()))
        },
    )
    .await?;
    drop(timeout);
    let (first, _) = land(&f, &c).await?;
    assert!(first.batch.input.lastHeight >= U256::from(fi_height));
    assert_eq!(f.forced_inclusion_state().await?, (1, 1));
    assert_eq!(p.get_balance(f.inbox).await?, fi_fee);
    let treasury_before = p.get_balance(f.admin).await?;
    transact(p, dev_signer().address(), f.inbox, EtnaInbox::sweepProtocolFeesCall {}.abi_encode())
        .await?;
    assert_eq!(p.get_balance(f.admin).await?, treasury_before + fi_fee);
    mine_l1_blocks(p, 3).await?;
    // Landing observes peer 0. The other three can decide a block before peer 3 has
    // executed it, so establish the offline validator's own durable baseline before stopping.
    let first_height = first.batch.input.lastHeight.to::<u64>();
    let history = c.app_dir(3).join(format!("comet-hash-{first_height}.json"));
    let hrs_path = f.signer_storage.path().join("3/state.json");
    let (peer_head, signed_height) = wait_until(
        &format!("peer 3 to commit and sign the first landing at {first_height}"),
        Duration::from_secs(120),
        Duration::from_millis(100),
        || async {
            let app = c.peers[3].abci_status().await?;
            let catching_up = c.peers[3].call("status", &[]).await?["sync_info"]["catching_up"]
                .as_bool()
                .context("peer 3 stock catching_up flag")?;
            let signer = c.signing_state(3).with_context(|| format!("read {}", hrs_path.display()))?;
            let signed = signer["height"].as_str().context("peer 3 HRS height")?.parse::<u64>()?;
            ensure!(
                app.head >= first_height && app.trust_ready && !app.syncing && !catching_up && signed >= first_height,
                "peer 3 head={}, trust_ready={}, syncing={}, stock catching_up={catching_up}, HRS={signed}, required={first_height}",
                app.head, app.trust_ready, app.syncing,
            );
            Ok(Some((app.head, signed)))
        },
    )
    .await?;
    let saved_history =
        std::fs::read(&history).with_context(|| format!("read {}", history.display()))?;
    let local_hash: B256 = serde_json::from_slice(&saved_history)
        .with_context(|| format!("decode {}", history.display()))?;
    ensure!(
        local_hash == first.batch.input.lastCometHash,
        "peer 3 {} holds {local_hash}, landing commits {}",
        history.display(),
        first.batch.input.lastCometHash
    );
    eprintln!(
        "peer 3 before stop: head={peer_head} HRS={signed_height} first_landing={first_height} comet={local_hash}"
    );
    c.stop_node(3).await?;
    let old_state =
        c.signing_state(3).with_context(|| format!("read stopped HRS {}", hrs_path.display()))?;
    let old_height = old_state["height"].as_str().context("HRS height")?.parse::<u64>()?;
    let key_path = f.signer_storage.path().join("3/key.json");
    let key = std::fs::read(&key_path).with_context(|| format!("read {}", key_path.display()))?;
    assert_eq!(
        std::fs::read(&history).with_context(|| format!("read stopped {}", history.display()))?,
        saved_history
    );
    let wal = c.comet_home(3).join("data/cs.wal/wal");
    ensure!(wal.is_file(), "Comet WAL must survive node stop");
    c.wait_for_height(old_height + 8).await?;
    let (second, _) = land(&f, &c).await?;
    mine_l1_blocks(p, 3).await?;
    assert!(second.batch.input.lastHeight > U256::from(old_height));
    assert_eq!(c.signing_state(3)?, old_state, "offline HRS unchanged");
    c.restart_node(3).await?;
    wait_until(
        "fourth validator catches up",
        Duration::from_secs(120),
        Duration::from_millis(100),
        || async {
            Ok((c.peers[3].latest_height().await? >= second.batch.input.lastHeight.to::<u64>() + 2)
                .then_some(()))
        },
    )
    .await?;
    ensure!(
        std::fs::read(&key_path)
            .with_context(|| format!("read restarted {}", key_path.display()))? ==
            key,
        "registered key changed across peer 3 restart at {}",
        key_path.display()
    );
    // Restart never rewrites a committed Comet block ID. Commits delete one only once the
    // committed anchor's checkpoint has passed it, after saving that state, so read the file
    // before the state.
    match std::fs::read(&history) {
        Ok(bytes) => assert_eq!(bytes, saved_history),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            let state: abci::store::AppState = serde_json::from_slice(&std::fs::read(
                c.app_dir(3).join(abci::store::STATE_FILE),
            )?)?;
            let floor = state.comet_history_floor();
            ensure!(floor > first.batch.input.lastHeight.to::<u64>(), "pruned at floor {floor}");
        }
        Err(error) => return Err(error.into()),
    }
    ensure!(
        abci::Store::new(c.app_dir(3))
            .load_comet_hash(second.batch.input.lastHeight.to::<u64>())?
            .is_some(),
        "the latest landed checkpoint keeps its Comet block ID"
    );
    assert!(c.signing_state(3)?["height"].as_str().unwrap().parse::<u64>()? >= old_height);
    let recovery = lander::codec::LandedRange {
        parent_height: 0,
        parent_hash: f.genesis.genesis_hash,
        last_height: first.batch.input.lastHeight.to(),
        last_block_hash: first.batch.input.lastBlockHash,
        last_state_root: first.batch.input.lastStateRoot,
    };
    c.stop().await?;
    recover_landed_execution(&f, first.batch.blobs.sidecar.blobs(), &recovery).await?;
    f.l2.stop().await?;
    f.anvil.stop().await
}
