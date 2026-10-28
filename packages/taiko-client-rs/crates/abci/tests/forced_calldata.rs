//! Real pinned-EL calldata admission, mixed blocks, hostile proposals, and cold replay.
#[path = "support/forced_calldata.rs"]
mod support;
use abci::{
    Engine, L1Source, RpcL1Source,
    engine::PayloadVerdict,
    forced, rules,
    wire::{Request, Response, response},
};
use alloy::{
    consensus::{SignableTransaction, TxEip1559, TxEnvelope, TxLegacy},
    signers::SignerSync,
};
use alloy_eips::eip2718::Encodable2718;
use alloy_primitives::{Address, B256, Bytes, Signature, TxKind, U256, address, keccak256};
use alloy_provider::Provider;
use anyhow::{Context, Result, ensure};
use std::{sync::atomic::Ordering, time::Duration};
use support::*;
use test_harness::{Devnet, DevnetSpec, dev_signer, send_transfer, sign_transfer};
const RECIPIENT: Address = address!("00000000000000000000000000000000000f0ced");
const TAIL_RECIPIENT: Address = address!("00000000000000000000000000000000000f00aa");

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn forced_transaction_event_provenance() -> Result<()> {
    let mut d = Devnet::start(DevnetSpec::default()).await?;
    d.wait_for_height(0, 3, Duration::from_secs(60)).await?;
    freeze(&mut d).await?;
    ensure!(comet_exit_code(&d).await? == 0, "healthy Comet must stop without forced termination");
    let artifact: serde_json::Value =
        serde_json::from_str(include_str!("../../test-harness/contracts/InboxSetter.json"))?;
    let runtime: Bytes = artifact["deployedBytecode"]["object"].as_str().unwrap().parse()?;
    assert_eq!(d.l1().get_code_at(d.params().inbox).await?, runtime);
    let first = Bytes::from_static(b"first exact bytes");
    let singles = d.planter().plant_forced_transaction(first.clone()).await?;
    let batch =
        [Bytes::from_static(b"second exact bytes"), Bytes::from_static(b"third exact bytes")];
    let entries = d.planter().plant_forced_transactions(&batch).await?;
    assert_eq!(singles.index, 0);
    assert_eq!(entries.iter().map(|e| e.index).collect::<Vec<_>>(), vec![1, 2]);
    assert_eq!(entries[0].l1_block, entries[1].l1_block, "two events in one mined block");
    let source = RpcL1Source::new(d.l1().clone());
    for (e, tx) in std::iter::once((singles, first)).chain(entries.into_iter().zip(batch)) {
        let header = source.header(e.l1_block).await?;
        let proof = source
            .account_witness(
                d.params().inbox,
                &abci::l1::layout::inbox::forced_inclusion_entry_slots(e.index),
                e.l1_block,
            )
            .await?;
        let proven = forced::verify_entry(header.state_root(), &proof, d.params().inbox, e.index)?;
        let fetched = source.forced_transaction(d.params().inbox, e.index, e.l1_block).await?;
        assert_eq!(fetched, tx);
        assert_eq!(keccak256(&fetched), proven.tx_hash);
        assert_eq!((proven.timestamp, proven.l1_block), (header.timestamp(), e.l1_block));
        assert_eq!((e.timestamp, e.tx_hash), (proven.timestamp, proven.tx_hash));
        let logs:serde_json::Value=d.l1().raw_request("eth_getLogs".into(),(serde_json::json!({"address":d.params().inbox,"fromBlock":format!("{:#x}",e.l1_block),"toBlock":format!("{:#x}",e.l1_block),"topics":[keccak256("ForcedInclusionSaved(uint48,bytes,uint256)"),B256::from(U256::from(e.index))]}),)).await?;
        let logs = logs.as_array().context("logs array")?;
        assert_eq!(logs.len(), 1);
        let hash: B256 = serde_json::from_value(logs[0]["transactionHash"].clone())?;
        let receipt = d.l1().get_transaction_receipt(hash).await?.context("admission receipt")?;
        assert!(receipt.status());
        assert_eq!(receipt.block_number, Some(e.l1_block));
        assert_eq!(receipt.block_hash, Some(header.hash()));
    }
    d.stop().await
}

async fn mixed(due: bool) -> Result<()> {
    let delay = if due { 2 } else { 3600 };
    let mut d =
        Devnet::start(DevnetSpec { forced_inclusion_delay: delay, ..Default::default() }).await?;
    d.wait_for_height(0, 3, Duration::from_secs(60)).await?;
    fund_pool(&d).await?;
    let parent = freeze(&mut d).await?;
    let l2 = d.l2_provider(0);
    let signer = dev_signer();
    let tx = sign_transfer(
        &l2,
        &signer,
        RECIPIENT,
        U256::from(4242),
        l2.get_transaction_count(signer.address()).await?,
    )
    .await?;
    let raw: Bytes = tx.encoded_2718().into();
    let entry = d.planter().plant_forced_transaction(raw.clone()).await?;
    anchor_ready(&d, entry.l1_block, entry.timestamp + if due { delay } else { 0 }).await?;
    let pool = pool_signer();
    let nonce = l2.get_transaction_count(pool.address()).await?;
    let tail = send_transfer(&l2, &pool, TAIL_RECIPIENT, U256::from(99), nonce).await?;
    let (_dir, store) = saved_store(&parent)?;
    let mut app = d.detached_app(0, store, ObservedEngine::new(d.rpc_engine(0)?))?;
    let time = now();
    let env = prepare(&mut app, time).await?;
    let anchor = abci::l1::verify_anchor_witness(
        env.anchor.as_ref().context("new anchor")?,
        d.params().inbox,
    )?;
    assert_eq!(anchor.timestamp >= entry.timestamp + delay, due);
    assert_eq!(env.block.transactions.first(), Some(&raw));
    assert!(env.forced.as_ref().unwrap().tx.is_empty());
    assert_eq!(
        env.block.transactions.iter().map(keccak256).collect::<Vec<_>>(),
        vec![*tx.tx_hash(), tail]
    );
    accept(&mut app, &env, time).await?;
    assert_eq!(app.state().unwrap().forced_cursor, parent.forced_cursor + 1);
    assert_eq!(app.status().unwrap().halt_reason, None);
    for hash in [*tx.tx_hash(), tail] {
        let r = l2.get_transaction_receipt(hash).await?.context("receipt")?;
        assert!(r.status());
        assert_eq!(r.block_number, Some(env.block.header.number));
    }
    assert_eq!(l2.get_balance(RECIPIENT).await?, U256::from(4242));
    assert_eq!(l2.get_balance(TAIL_RECIPIENT).await?, U256::from(99));
    // A fresh verdict cache must replay inclusion without any singleton build.
    let (_replay_dir, replay_store) = saved_store(&parent)?;
    let engine = ObservedEngine::new(d.rpc_engine(0)?);
    engine.unavailable.store(true, Ordering::SeqCst);
    let attempts = engine.attempts.clone();
    let mut cold = d.detached_app(0, replay_store, engine)?;
    cold.handle(finalize_request(&env, time)).await?;
    cold.handle(Request::Commit).await?;
    assert_eq!(attempts.load(Ordering::SeqCst), 0);
    assert_eq!(cold.state(), app.state());
    assert_eq!(
        l2.get_block_by_number(env.block.header.number.into()).await?.unwrap().header.hash,
        env.block.header.hash_slow()
    );
    d.stop().await
}
#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn forced_transaction_mixed_before_due() -> Result<()> {
    mixed(false).await
}
#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn forced_transaction_mixed_after_due() -> Result<()> {
    mixed(true).await
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn forced_same_nonce_replacement_rejected() -> Result<()> {
    let mut d =
        Devnet::start(DevnetSpec { forced_inclusion_delay: 2, ..Default::default() }).await?;
    d.wait_for_height(0, 3, Duration::from_secs(60)).await?;
    let parent = freeze(&mut d).await?;
    let l2 = d.l2_provider(0);
    let signer = dev_signer();
    let nonce = l2.get_transaction_count(signer.address()).await?;
    let tx = sign_transfer(&l2, &signer, RECIPIENT, U256::from(4242), nonce).await?;
    let replacement = sign_transfer(&l2, &signer, TAIL_RECIPIENT, U256::from(99), nonce).await?;
    let e = d.planter().plant_forced_transaction(tx.encoded_2718().into()).await?;
    anchor_ready(&d, e.l1_block, e.timestamp + 2).await?;
    let (_dir, store) = saved_store(&parent)?;
    let mut app = d.detached_app(0, store, d.rpc_engine(0)?)?;
    let time = now();
    let mut env = prepare(&mut app, time).await?;
    let attrs = rules::payload_attributes(
        &expected(&env),
        env.anchor.as_ref().unwrap().l1_header.hash(),
        Some(protocol::shasta::encode_transactions(std::slice::from_ref(&replacement))),
    );
    env.block = app.engine().build_block(parent.parent.hash, attrs).await?;
    assert_eq!(env.block.transactions, vec![Bytes::from(replacement.encoded_2718())]);
    assert_eq!(
        app.engine().new_payload(&env.block).await?,
        PayloadVerdict::Valid,
        "replacement payload itself is valid"
    );
    // The honest included proposal omitted its duplicate preimage. After replacing tx[0],
    // that omission cannot authorize skipping the original due entry.
    assert!(env.forced.as_ref().unwrap().tx.is_empty());
    let result = app.handle(Request::ProcessProposal(process_request(&env, time))).await?;
    assert!(matches!(result, Response::ProcessProposal(response::ProcessProposal::Reject)));
    assert_eq!(app.status().unwrap().halt_reason.as_deref(), Some("forced_inclusion"));
    assert_eq!(app.state(), Some(&parent));

    // Supplying the correct preimage reaches the singleton checker, which still retains the
    // original transaction on this parent. A same-nonce replacement cannot justify that skip.
    env.forced.as_mut().unwrap().tx = tx.encoded_2718().into();
    let result = app.handle(Request::ProcessProposal(process_request(&env, time))).await?;
    assert!(matches!(result, Response::ProcessProposal(response::ProcessProposal::Reject)));
    assert_eq!(app.status().unwrap().halt_reason.as_deref(), Some("forced_skip_invalid"));
    assert_eq!(app.state(), Some(&parent), "rejected candidate never advances cursor or parent");
    d.stop().await
}

fn sign_tx(tx: TxEip1559) -> Result<TxEnvelope> {
    let sig = dev_signer().sign_hash_sync(&tx.signature_hash())?;
    Ok(TxEnvelope::Eip1559(tx.into_signed(sig)))
}
fn sign_legacy(tx: TxLegacy) -> Result<TxEnvelope> {
    let sig = dev_signer().sign_hash_sync(&tx.signature_hash())?;
    Ok(TxEnvelope::Legacy(tx.into_signed(sig)))
}
async fn deploy_fixture(d: &Devnet) -> Result<Address> {
    let artifact: serde_json::Value =
        serde_json::from_str(include_str!("../../test-harness/contracts/ZkGasFixture.json"))?;
    let input: Bytes = artifact["bytecode"]["object"].as_str().unwrap().parse()?;
    let l2 = d.l2_provider(0);
    let tx = sign_tx(TxEip1559 {
        chain_id: l2.get_chain_id().await?,
        nonce: l2.get_transaction_count(dev_signer().address()).await?,
        gas_limit: 1_000_000,
        max_fee_per_gas: 10_000_000_000,
        max_priority_fee_per_gas: 1_000_000_000,
        to: TxKind::Create,
        input,
        ..Default::default()
    })?;
    let hash = *l2.send_raw_transaction(&tx.encoded_2718()).await?.tx_hash();
    let receipt = test_harness::wait_until(
        "fixture deployment",
        Duration::from_secs(30),
        Duration::from_millis(100),
        || async { Ok(l2.get_transaction_receipt(hash).await?) },
    )
    .await?;
    ensure!(receipt.status(), "fixture deployment reverted");
    receipt.contract_address.context("deployed address")
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn forced_invalid_skip_keeps_mempool() -> Result<()> {
    let mut d = Devnet::start(DevnetSpec {
        forced_inclusion_delay: 2,
        epoch_len: 200,
        unsettled_limit: 180,
        ..Default::default()
    })
    .await?;
    d.wait_for_height(0, 3, Duration::from_secs(60)).await?;
    let fixture = deploy_fixture(&d).await?;
    fund_pool(&d).await?;
    let mut parent = freeze(&mut d).await?;
    let l2 = d.l2_provider(0);
    let nonce = l2.get_transaction_count(dev_signer().address()).await?;
    let base = TxEip1559 {
        chain_id: l2.get_chain_id().await?,
        nonce,
        gas_limit: 21_000,
        max_fee_per_gas: 10_000_000_000,
        max_priority_fee_per_gas: 1_000_000_000,
        to: TxKind::Call(RECIPIENT),
        value: U256::from(4242),
        ..Default::default()
    };
    // Canonical bytes can fail deterministic eligibility locally.
    // Fee, nonce, balance and zk-gas cases still require a real singleton result.
    let mut cases: Vec<(&str, Bytes, bool, bool)> = Vec::new();
    let mut tx = base.clone();
    tx.nonce += 10;
    cases.push(("nonce_too_high", sign_tx(tx)?.encoded_2718().into(), true, true));
    let mut tx = base.clone();
    tx.value = U256::MAX;
    cases.push(("insufficient_balance", sign_tx(tx)?.encoded_2718().into(), true, true));
    cases.push((
        "zero_signature",
        TxEnvelope::Eip1559(base.clone().into_signed(Signature::new(
            U256::ZERO,
            U256::ZERO,
            false,
        )))
        .encoded_2718()
        .into(),
        true,
        false,
    ));
    let mut tx = base.clone();
    tx.max_fee_per_gas = 0;
    tx.max_priority_fee_per_gas = 0;
    cases.push(("fee_below_base", sign_tx(tx)?.encoded_2718().into(), true, true));
    let mut tx = base.clone();
    tx.gas_limit = d.params().block_gas_limit + 1;
    cases.push(("declared_gas_above_block", sign_tx(tx)?.encoded_2718().into(), true, false));
    let blob = alloy::consensus::TxEip4844 {
        chain_id: base.chain_id,
        nonce,
        gas_limit: 100_000,
        max_fee_per_gas: base.max_fee_per_gas,
        max_priority_fee_per_gas: base.max_priority_fee_per_gas,
        to: RECIPIENT,
        max_fee_per_blob_gas: 1_000_000_000,
        blob_versioned_hashes: vec![B256::repeat_byte(1)],
        ..Default::default()
    };
    let sig = dev_signer().sign_hash_sync(&blob.signature_hash())?;
    cases.push((
        "unsupported_blob_envelope",
        TxEnvelope::from(blob.into_signed(sig)).encoded_2718().into(),
        true,
        false,
    ));
    let mut tx = base.clone();
    tx.to = TxKind::Call(fixture);
    tx.value = U256::ZERO;
    tx.gas_limit = 300_000;
    tx.input = Bytes::copy_from_slice(&keccak256("consumeZkGas()")[..4]);
    cases.push(("zk_gas_above_block", sign_tx(tx)?.encoded_2718().into(), true, true));
    cases.push(("malformed", Bytes::from_static(&[0xff]), false, false));
    let canonical = sign_tx(base.clone())?.encoded_2718();
    let mut trailing = canonical.clone();
    trailing.push(0);
    cases.push(("trailing", trailing.into(), false, false));
    cases.push((
        "noncanonical_network_wrapper",
        alloy_rlp::encode(canonical.as_slice()).into(),
        false,
        false,
    ));
    cases.push(("empty", Bytes::new(), false, false));
    // Plant every case, then wait once for the last entry to be anchored and due. Each block
    // consumes exactly the next queue entry, so the cases still run one per block, in order.
    let mut planted = Vec::with_capacity(cases.len());
    for (name, raw, canonical, requires_singleton) in cases {
        assert_eq!(forced::decode_canonical(&raw).is_some(), canonical, "{name}");
        let e = d.planter().plant_forced_transaction(raw.clone()).await?;
        planted.push((name, raw, canonical, requires_singleton, e));
    }
    let (last_block, last_timestamp) = {
        let last = &planted.last().context("planted cases")?.4;
        (last.l1_block, last.timestamp)
    };
    anchor_ready(&d, last_block, last_timestamp + 2).await?;
    for (name, raw, canonical, requires_singleton, e) in planted {
        eprintln!("real EL invalidity case: {name}");
        let pool = pool_signer();
        let pn = l2.get_transaction_count(pool.address()).await?;
        let tail = send_transfer(&l2, &pool, TAIL_RECIPIENT, U256::from(99), pn).await?;
        let (_dir, store) = saved_store(&parent)?;
        let engine = ObservedEngine::new(d.rpc_engine(0)?);
        let builds = engine.builds.clone();
        let mut app = d.detached_app(0, store, engine)?;
        let time = now();
        let env = prepare(&mut app, time).await?;
        assert_eq!(env.forced.as_ref().unwrap().tx, raw, "{name}");
        assert_eq!(
            env.block.transactions.iter().map(keccak256).collect::<Vec<_>>(),
            vec![tail],
            "{name}: ordinary pool block survives skip"
        );
        accept(&mut app, &env, time).await?;
        assert_eq!(app.state().unwrap().forced_cursor, e.index + 1, "{name}");
        let r = l2.get_transaction_receipt(tail).await?.context("tail receipt")?;
        assert!(r.status());
        assert_eq!(r.block_number, Some(env.block.header.number));
        let evidence = builds.lock().unwrap().clone();
        let singleton = if canonical {
            Some(protocol::shasta::encode_transactions(&[forced::decode_canonical(&raw).unwrap()]))
        } else {
            None
        };
        if canonical {
            assert_eq!(
                evidence.iter().any(|b| b.list == singleton),
                requires_singleton,
                "{name}: singleton build presence matches fee eligibility"
            );
            if requires_singleton {
                assert!(
                    evidence.iter().any(|b| b.list == singleton && b.count == 0),
                    "{name}: real empty singleton evidence"
                );
            }
        } else {
            assert!(
                evidence.iter().all(|b| b.list.is_none()),
                "{name}: malformed bytes never reach an explicit EL build"
            );
        }
        if requires_singleton {
            // The explicit EL historical-state error is terminal, unlike -32603 below.
            let (_fatal_dir, fatal_store) = saved_store(&parent)?;
            let engine = ObservedEngine::new(d.rpc_engine(0)?);
            engine.unknown_execution.store(true, Ordering::SeqCst);
            let mut fatal = d.detached_app(0, fatal_store.clone(), engine)?;
            assert!(
                matches!(
                    fatal.handle(finalize_request(&env, time)).await,
                    Err(abci::AbciError::SafetyHalt(_))
                ),
                "{name}: -38100 is never a legal skip"
            );
            assert_eq!(fatal_store.load()?, Some(parent.clone()));
            assert!(
                std::fs::read_to_string(_fatal_dir.path().join("fatal-evidence.txt"))?
                    .contains("-38100")
            );
        }
        // Only deterministically eligible skips need retained parent state during cold replay.
        // Emulate the pinned getPayload error, then release the real engine and verify recovery.
        let (_cold_dir, cold_store) = saved_store(&parent)?;
        let engine = ObservedEngine::new(d.rpc_engine(0)?);
        let attempts = engine.attempts.clone();
        let unavailable = engine.unavailable.clone();
        unavailable.store(true, Ordering::SeqCst);
        let mut cold = d.detached_app(0, cold_store.clone(), engine)?;
        if requires_singleton {
            let request = finalize_request(&env, time);
            use tracing::instrument::WithSubscriber;
            let logs = std::sync::Arc::new(std::sync::Mutex::new(Vec::new()));
            let sink = logs.clone();
            let retry_recorded = std::sync::Arc::new(tokio::sync::Notify::new());
            let notification = retry_recorded.clone();
            let subscriber = tracing_subscriber::fmt()
                .without_time()
                .with_ansi(false)
                .with_max_level(tracing::Level::WARN)
                .with_writer(move || LogWriter {
                    bytes: sink.clone(),
                    retry_recorded: notification.clone(),
                })
                .finish();
            {
                let finalize = cold.handle(request).with_subscriber(subscriber);
                tokio::pin!(finalize);
                tokio::select! {
                    result = &mut finalize => {
                        anyhow::bail!("unavailable replay finished before retry observation: {result:?}");
                    }
                    observed = tokio::time::timeout(Duration::from_secs(30), retry_recorded.notified()) => {
                        observed.context("waiting for unavailable singleton retry diagnostic")?;
                    }
                }
                assert!(
                    futures::poll!(&mut finalize).is_pending(),
                    "unavailable replay cannot finalize after its observed retry"
                );
            }
            let diagnostic = String::from_utf8(logs.lock().unwrap().clone())?;
            assert!(
                diagnostic.contains("forced_rebuild_unavailable"),
                "missing unavailable label: {diagnostic}"
            );
            assert!(
                diagnostic.contains(&parent.parent.hash.to_string()),
                "missing historical parent: {diagnostic}"
            );
            assert!(
                diagnostic.contains("may lack"),
                "history loss is qualified, not inferred from an internal error"
            );
            assert!(attempts.load(Ordering::SeqCst) > 0);
            assert_eq!(cold.state(), Some(&parent));
            assert_eq!(cold_store.load()?, Some(parent.clone()));
            unavailable.store(false, Ordering::SeqCst);
        }
        cold.handle(finalize_request(&env, time)).await?;
        cold.handle(Request::Commit).await?;
        if !requires_singleton {
            assert_eq!(
                attempts.load(Ordering::SeqCst),
                0,
                "{name}: deterministically ineligible bytes need no singleton"
            );
        }
        assert_eq!(cold.state(), app.state());
        assert_eq!(
            l2.get_block_by_number(env.block.header.number.into()).await?.unwrap().header.hash,
            env.block.header.hash_slow()
        );
        parent = app.state().unwrap().clone();
    }
    // A reverting but executable transaction is included and consumes the queue entry.
    let mut tx = base;
    tx.to = TxKind::Call(fixture);
    tx.value = U256::ZERO;
    tx.gas_limit = 100_000;
    tx.input = Bytes::copy_from_slice(&keccak256("revertAlways()")[..4]);
    let tx = sign_tx(tx)?;
    let raw: Bytes = tx.encoded_2718().into();
    let e = d.planter().plant_forced_transaction(raw.clone()).await?;
    anchor_ready(&d, e.l1_block, e.timestamp + 2).await?;
    let (_dir, store) = saved_store(&parent)?;
    let mut app = d.detached_app(0, store, d.rpc_engine(0)?)?;
    let time = now();
    let env = prepare(&mut app, time).await?;
    assert_eq!(env.block.transactions, vec![raw]);
    accept(&mut app, &env, time).await?;
    let receipt = l2.get_transaction_receipt(*tx.tx_hash()).await?.context("revert receipt")?;
    assert!(!receipt.status());
    assert_eq!(app.state().unwrap().forced_cursor, e.index + 1);
    d.stop().await
}

/// A stalled Comet process must not prevent freezing the parent or later handshake replay.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn frozen_comet_is_reaped_before_parent_read_and_recovers() -> Result<()> {
    let mut d = Devnet::start(DevnetSpec::default()).await?;
    d.wait_for_height(0, 3, Duration::from_secs(60)).await?;
    let name = d.cmt_container(0);
    // SIGSTOP makes graceful shutdown impossible without changing the app or its history.
    let paused = tokio::process::Command::new("docker")
        .args(["kill", "--signal=STOP", &name])
        .output()
        .await?;
    ensure!(paused.status.success(), "pause the test's Comet process");
    let parent = freeze(&mut d).await?;
    ensure!(!d.app_running(0) && !d.cmt_running(0).await?, "both node processes must be stopped");
    ensure!(comet_exit_code(&d).await? == 137, "unresponsive Comet must be killed");
    let hashes = d.l2_block_hashes(0, parent.last_height).await?;
    d.app_start(0).await?;
    d.cmt_restart(0).await?;
    d.wait_for_height(0, parent.last_height + 3, Duration::from_secs(60)).await?;
    ensure!(
        d.l2_block_hashes(0, parent.last_height).await? == hashes,
        "managed stop and handshake must preserve committed execution history"
    );
    ensure!(d.app_halt(0).is_none(), "restart must not enter a safety halt");
    d.stop().await
}

/// Exercise the raw cap against executable blocks built by the pinned real EL, including a block
/// the EL fills with legacy transactions under the production byte limit.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn raw_execution_boundary_124000_accepts_124001_rejects() -> Result<()> {
    use alloy_rlp::Encodable;
    let mut d = Devnet::start(DevnetSpec::default()).await?;
    d.wait_for_height(0, 3, Duration::from_secs(60)).await?;
    let parent = freeze(&mut d).await?;
    let (_dir, store) = saved_store(&parent)?;
    let mut app = d.detached_app(0, store, d.rpc_engine(0)?)?;
    let time = now();
    let base = prepare(&mut app, time).await?;
    let nonce = d.l2_provider(0).get_transaction_count(dev_signer().address()).await?;
    let anchor = base.anchor.as_ref().map(|w| w.l1_header.hash()).unwrap_or(parent.anchor.hash);
    let mut input_size = 123_000usize;
    let mut blocks = Vec::new();
    for target in [124_000usize, 124_001] {
        let mut found = None;
        for _ in 0..8 {
            let tx = sign_tx(TxEip1559 {
                chain_id: d.params().l2_chain_id,
                nonce,
                gas_limit: 3_000_000,
                max_fee_per_gas: 10_000_000_000,
                max_priority_fee_per_gas: 1_000_000_000,
                to: TxKind::Call(RECIPIENT),
                input: Bytes::from(vec![0; input_size]),
                ..Default::default()
            })?;
            let mut attrs = rules::payload_attributes(
                &expected(&base),
                anchor,
                Some(protocol::shasta::encode_transactions(&[tx])),
            );
            assert_eq!(attrs.max_block_bytes, Some(124_000));
            // The EL reserves a conservative header bound during selection. Give this
            // test-only construction room to obtain exact executable boundary blocks;
            // production attributes above always retain124000.
            attrs.max_block_bytes = Some(target as u64 + 1024);
            let block = app.engine().build_block(parent.parent.hash, attrs).await?;
            ensure!(
                block.transactions.len() == 1,
                "boundary fixture transaction must execute: target={target} input={input_size} raw={}",
                block.length()
            );
            let length = block.length();
            if length == target {
                found = Some(block);
                break;
            }
            input_size = input_size
                .checked_add_signed(target as isize - length as isize)
                .context("boundary input sizing")?;
        }
        blocks.push(found.context("exact executable raw boundary")?);
    }

    // The EL measures every transaction, legacy included, as an RLP byte string of its EIP-2718
    // bytes, like the envelope. Offered more legacy transactions than fit, it fills the block
    // under the production limit with a measure the client accepts.
    let legacy = (0..5u64)
        .map(|i| {
            sign_legacy(TxLegacy {
                chain_id: Some(d.params().l2_chain_id),
                nonce: nonce + i,
                gas_price: 10_000_000_000,
                gas_limit: 1_000_000,
                to: TxKind::Call(RECIPIENT),
                value: U256::ZERO,
                input: Bytes::from(vec![0; 30_000]),
            })
        })
        .collect::<Result<Vec<_>>>()?;
    let attrs = rules::payload_attributes(
        &expected(&base),
        anchor,
        Some(protocol::shasta::encode_transactions(&legacy)),
    );
    assert_eq!(attrs.max_block_bytes, Some(124_000));
    let mut full = base.clone();
    full.block = app.engine().build_block(parent.parent.hash, attrs).await?;
    // Four of them fit (about 121 kB); the fifth would pass the limit.
    let included = full.block.transactions.len();
    ensure!(
        (2..legacy.len()).contains(&included) &&
            full.block.transactions.iter().all(|tx| tx[0] >= 0xc0),
        "the EL fills the block with legacy transactions up to the byte limit: {included} included"
    );
    ensure!(full.block.length() <= 124_000, "byte-full block measures {}", full.block.length());
    let Response::ProcessProposal(verdict) =
        app.handle(Request::ProcessProposal(process_request(&full, time))).await?
    else {
        anyhow::bail!("process response")
    };
    assert_eq!(verdict, response::ProcessProposal::Accept, "{:?}", app.status());

    let mut over = base.clone();
    over.block = blocks.pop().unwrap();
    assert_eq!(over.block.length(), 124_001);
    let Response::ProcessProposal(verdict) =
        app.handle(Request::ProcessProposal(process_request(&over, time))).await?
    else {
        anyhow::bail!("process response")
    };
    assert_eq!(verdict, response::ProcessProposal::Reject);
    let (_fatal_dir, fatal_store) = saved_store(&parent)?;
    let mut fatal = d.detached_app(0, fatal_store.clone(), d.rpc_engine(0)?)?;
    assert!(matches!(
        fatal.handle(finalize_request(&over, time)).await,
        Err(abci::AbciError::SafetyHalt(_))
    ));
    assert_eq!(fatal_store.load()?, Some(parent.clone()));
    let mut exact = base;
    exact.block = blocks.pop().unwrap();
    assert_eq!(exact.block.length(), 124_000);
    accept(&mut app, &exact, time).await?;
    assert_eq!(d.l2_provider(0).get_block_number().await?, exact.block.header.number);
    d.stop().await
}
