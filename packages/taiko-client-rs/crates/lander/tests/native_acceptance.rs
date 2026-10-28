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
    contracts::{EtnaInbox, receipt, transact},
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
    let builder = BatchBuilder::new(
        Arc::new(HttpCometSource::new(c.cmt.url(), Duration::from_secs(10), 16 * 1024 * 1024)?),
        source.clone(),
        BatchBuilderConfig {
            params: f.params.clone(),
            limits: limits(),
            mode: SidecarMode::Eip7594,
            engine: Arc::new(f.l2.engine()?),
            engine_timeout: Duration::from_secs(10),
        },
    )?;
    let request =
        builder.prepare(source.snapshot().await?).await?.context("nonempty grid batch")?;
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
    assert_eq!(f.checkpoint().await?.0, request.batch.input.lastHeight.to::<u64>());
    eprintln!(
        "ACCEPTANCE dummy=0x00 land={} range=({},{}] statement={} leaves={}",
        tx.hash,
        request.batch.input.parentHeight,
        request.batch.input.lastHeight,
        request.batch.statement_hash,
        request.batch.leaves.len()
    );
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
    let report = abci::build_committee_record(
        &abci::RpcL1Source::new(f.anvil.provider.clone()),
        &f.params,
        f.genesis.genesis_cutoff,
        None,
    )
    .await?;
    let report_json = report.to_json_pretty();
    std::fs::write("/tmp/etna-task3c2-acceptance-committee.json", &report_json)?;
    eprintln!("ACCEPTANCE committeeRecord={report_json}");
    let p = &f.anvil.provider;
    let l2 = &f.l2.provider;
    set_interval_mining(p, 1).await?;
    let dirs = (0..4).map(|i| f.signer_storage.path().join(i.to_string())).collect();
    let mut c =
        ContractConsensus::start(f.anvil.http.clone(), &f.l2, f.params.clone(), dirs).await?;
    let genesis_hash = alloy_primitives::keccak256(c.genesis_json.as_bytes());
    std::fs::write("/tmp/etna-task3c2-acceptance-genesis.json", &c.genesis_json)?;
    eprintln!(
        "ACCEPTANCE bootstrap inbox={} registry={} EL={} stateRoot={} cometGenesisKeccak={genesis_hash}",
        f.inbox, f.registry, f.genesis.genesis_hash, f.genesis.genesis_state_root
    );
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
    eprintln!("ACCEPTANCE normal receipt={payment}");
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
    eprintln!(
        "ACCEPTANCE normal={} at={} fee={} FI={} at={} epoch=1 nativeMembers=4",
        payment, h, fee, forced_hash, fi_height
    );
    let trust_path = c.app_dir(0).join("checkpoint-trust.sock");
    let before_timeout = trust_timeout::observe(&trust_path).await?;
    let old_session = before_timeout["session_id"].as_str().context("pre-timeout session")?;
    let hrs = c.signing_state(0)?;
    let timeout = trust_timeout::TrustTimeout::install(&c.app_dir(0)).await?;
    let new_session = timeout.wait_recovered(old_session).await?;
    assert!(
        timeout.ready_when_delayed.load(std::sync::atomic::Ordering::SeqCst),
        "the actual app stayed Ready at the failed signer-specific query"
    );
    assert!(
        c.signing_state(0)?["height"].as_str().unwrap().parse::<u64>()? >=
            hrs["height"].as_str().unwrap().parse::<u64>()?
    );
    drop(timeout);
    eprintln!(
        "ACCEPTANCE signerTimeout appWasReady=true automaticRestart=true oldSession={old_session} newSession={new_session} HRSNotReset=true"
    );
    let (first, _) = land(&f, &c).await?;
    assert!(first.batch.input.lastHeight >= U256::from(fi_height));
    assert_eq!(f.forced_inclusion_state().await?, (1, 1));
    assert_eq!(p.get_balance(f.inbox).await?, fi_fee);
    let treasury_before = p.get_balance(f.admin).await?;
    transact(p, dev_signer().address(), f.inbox, EtnaInbox::sweepProtocolFeesCall {}.abi_encode())
        .await?;
    assert_eq!(p.get_balance(f.admin).await?, treasury_before + fi_fee);
    mine_l1_blocks(p, 3).await?;
    c.stop_node(3).await?;
    let old_state = c.signing_state(3)?;
    let old_height = old_state["height"].as_str().context("HRS height")?.parse::<u64>()?;
    let key_path = f.signer_storage.path().join("3/key.json");
    let key = std::fs::read(&key_path)?;
    let history = c.app_dir(3).join(format!("comet-hash-{}.json", first.batch.input.lastHeight));
    let saved_history = std::fs::read(&history)?;
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
    assert_eq!(std::fs::read(key_path)?, key);
    assert_eq!(std::fs::read(history)?, saved_history);
    assert!(c.signing_state(3)?["height"].as_str().unwrap().parse::<u64>()? >= old_height);
    eprintln!(
        "ACCEPTANCE restart node=3 oldHRSHeight={old_height} checkpoint={} caughtUp={} sameKey=true samePrivateHistory=true WALRetained=true",
        second.batch.input.lastHeight,
        c.peers[3].latest_height().await?
    );
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
