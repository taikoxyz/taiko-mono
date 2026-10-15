//! Docker scenarios: forced inclusion and anchor freshness on the ABCI devnet.
//!
//! [`Planter::plant_forced_inclusions`](test_harness::Planter::plant_forced_inclusions) writes
//! forced inclusion entries into the setter-planted Inbox in the same L1 block as a type-3
//! transaction carrying their blobs; a proposer fetches a blob through the harness's fake beacon,
//! which serves anvil's blobs. With a 10 s delay an entry is due once the anchor (anvil's
//! `finalized`, two blocks behind its tip) is an L1 block at least 10 s younger than the entry.

use std::{
    collections::BTreeSet,
    time::{Duration, Instant},
};

use alloy_eips::{BlockId, BlockNumberOrTag, eip2718::Encodable2718};
use alloy_primitives::{Address, B256, U256, address};
use alloy_provider::Provider;
use anyhow::{Context, anyhow, ensure};
use test_harness::{
    Devnet, DevnetSpec, Fatal, anchor_of, dev_signer, finalized_number, sign_transfer, wait_until,
};
use tokio::sync::oneshot;

/// The genesis forced inclusion delay of the forced inclusion scenarios, in seconds.
const DELAY: u64 = 10;

/// The recipient of the forced transfers (a fresh account).
const RECIPIENT: Address = address!("00000000000000000000000000000000000f0ced");

/// The value of each forced transfer, in wei.
const VALUE: u64 = 4_242;

/// The `/status` halt reason of the anchor freshness rule (`RuleViolation::AnchorTooOld`).
const ANCHOR_TOO_OLD: &str = "anchor_too_old";

/// The `/status` halt reason of a proposer that cannot fetch a due entry's blob
/// (`Rejection::BlobUnavailable`).
const BLOB_UNAVAILABLE: &str = "blob_unavailable";

/// Waits until L2 node 0 holds a successful receipt of `tx`; returns its block number. Fails
/// after `timeout`, or at once when an app halts.
async fn wait_for_inclusion(devnet: &Devnet, tx: B256, timeout: Duration) -> anyhow::Result<u64> {
    let l2 = devnet.l2_provider(0);
    let (l2, validators) = (&l2, devnet.keys().len());
    let receipt = wait_until(
        &format!("L2 receipt of the forced transaction {tx}"),
        timeout,
        Duration::from_millis(250),
        || async move {
            for i in 0..validators {
                if let Some(reason) = devnet.app_halt(i) {
                    return Err(Fatal(anyhow!("app {i} halted: {reason}")).into());
                }
            }
            Ok(l2.get_transaction_receipt(tx).await?)
        },
    )
    .await
    .inspect_err(|_| devnet.dump_logs())?;
    ensure!(receipt.status(), "the forced transaction {tx} reverted");
    receipt.block_number.context("receipt without a block number")
}

/// The timestamp of anvil's block `n`.
async fn l1_timestamp(devnet: &Devnet, n: u64) -> anyhow::Result<u64> {
    let block = devnet
        .l1()
        .get_block_by_number(BlockNumberOrTag::Number(n))
        .await?
        .with_context(|| format!("L1 block {n} missing"))?;
    Ok(block.header.timestamp)
}

/// The round in which the block at `height` was committed, from CometBFT node 0.
async fn commit_round(devnet: &Devnet, height: u64) -> anyhow::Result<u64> {
    let commit = devnet.cmt(0).call("commit", &[("height", height.to_string())]).await?;
    commit["signed_header"]["commit"]["round"].as_u64().context("commit round")
}

/// Plants `count` forced transfers of [`VALUE`] to [`RECIPIENT`] from the funded dev account,
/// one per entry, as entries `0..count` in one L1 block, and waits up to `timeout` for the last
/// to execute. Entries due at one anchor fill consecutive blocks, so entry `i` must execute in
/// block `F + i`.
///
/// For each entry checks that its block holds exactly its transaction, moved exactly the value
/// plus the gas from the sender to the recipient, anchors at an L1 block at least [`DELAY`]
/// seconds younger than the entries and is decided with the entry's witness and blob; every
/// block before `F` carried at most a peek (no blob) at entry 0. Returns `F..F + count`.
async fn force_transfers(
    devnet: &Devnet,
    count: u64,
    timeout: Duration,
) -> anyhow::Result<Vec<u64>> {
    let l2 = devnet.l2_provider(0);
    let signer = dev_signer();
    let nonce = l2.get_transaction_count(signer.address()).await?;
    let mut sources = Vec::new();
    for i in 0..count {
        sources.push(vec![
            sign_transfer(&l2, &signer, RECIPIENT, U256::from(VALUE), nonce + i).await?,
        ]);
    }
    let hashes: Vec<B256> = sources.iter().map(|txs| *txs[0].tx_hash()).collect();
    let mut entries = Vec::new();
    for transactions in sources {
        entries.push(
            devnet
                .planter()
                .plant_forced_transaction(transactions[0].encoded_2718().into())
                .await?,
        );
    }
    let planted = Instant::now();
    eprintln!("planted forced inclusion entries {entries:?} for {hashes:?}");
    let indices: Vec<u64> = entries.iter().map(|e| e.index).collect();
    assert_eq!(indices, (0..count).collect::<Vec<_>>(), "the queue was empty");
    let timestamp = entries[0].timestamp;

    let last = hashes.last().context("no transfer")?;
    let last_height = wait_for_inclusion(devnet, *last, timeout).await?;
    eprintln!(
        "last forced transaction in L2 block {last_height} {:?} after planting",
        planted.elapsed()
    );
    let first = l2
        .get_transaction_receipt(hashes[0])
        .await?
        .context("first receipt")?
        .block_number
        .context("first block")?;
    let mut heights = Vec::new();
    for (entry, hash) in entries.iter().zip(&hashes) {
        let receipt = l2.get_transaction_receipt(*hash).await?.context("missing receipt")?;
        assert!(receipt.status(), "forced transaction {hash} reverted");
        let forced = receipt.block_number.context("receipt without a block number")?;
        assert!(
            heights.last().is_none_or(|previous| *previous < forced),
            "entries consume in queue order"
        );
        heights.push(forced);
        let block = l2
            .get_block_by_number(BlockNumberOrTag::Number(forced))
            .await?
            .with_context(|| format!("L2 block {forced} missing"))?;
        assert_eq!(block.transactions.hashes().collect::<Vec<_>>(), vec![*hash], "block {forced}");

        let gas = U256::from(receipt.gas_used) * U256::from(receipt.effective_gas_price);
        let at = |n: u64| BlockId::number(n);
        let sender = signer.address();
        let spent = l2.get_balance(sender).block_id(at(forced - 1)).await? -
            l2.get_balance(sender).block_id(at(forced)).await?;
        assert_eq!(spent, U256::from(VALUE) + gas, "block {forced}: the sender paid value + gas");
        let received = l2.get_balance(RECIPIENT).block_id(at(forced)).await? -
            l2.get_balance(RECIPIENT).block_id(at(forced - 1)).await?;
        assert_eq!(received, U256::from(VALUE), "block {forced}: the recipient got the value");

        let anchor = anchor_of(&l2, forced).await?;
        let anchor_time = l1_timestamp(devnet, anchor).await?;
        assert!(
            anchor_time >= entry.timestamp,
            "block {forced} anchors at L1 block {anchor} (time {anchor_time}), before the \
             entries (time {timestamp}) were due"
        );
        let envelope = devnet.cmt(0).envelope(forced).await?;
        let witness = envelope.forced.context("a forced block carries no forced witness")?;
        assert_eq!(witness.index, entry.index, "block {forced}");
        assert!(!witness.tx.is_empty(), "forced block {forced} carries no blob");
    }
    for h in 1..first {
        if let Some(peek) = devnet.cmt(0).envelope(h).await?.forced {
            assert_eq!(peek.index, 0, "block {h} names another entry");
            assert!(!peek.tx.is_empty(), "block {h} carries a blob before the forced block");
        }
    }
    Ok(heights)
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn calldata_forced_inclusion_executes_and_replays() -> anyhow::Result<()> {
    let started = Instant::now();
    let spec = DevnetSpec { forced_inclusion_delay: DELAY, ..Default::default() };
    let mut devnet = Devnet::start(spec).await?;
    devnet.wait_for_height(0, 3, Duration::from_secs(60)).await?;

    let forced = force_transfers(&devnet, 1, Duration::from_secs(DELAY + 30)).await?[0];

    // The entry is consumed: later blocks carry no forced witness.
    devnet.wait_for_height(0, forced + 3, Duration::from_secs(30)).await?;
    for h in forced + 1..=forced + 3 {
        let envelope = devnet.cmt(0).envelope(h).await?;
        assert_eq!(envelope.forced, None, "block {h} carries a forced witness");
    }

    // Crash replay: the app loses its state and replays every block, the forced one included,
    // through a cold FinalizeBlock that rebuilds the forced block on its parent while the EL's
    // head is far above it.
    let (before, restored) = devnet.replay_after_state_loss(0).await?;
    assert!(before.last_height > forced, "the crash is past the forced block");
    assert_eq!(before.forced_cursor, 1, "the persisted forced inclusion cursor");
    assert_eq!(restored.forced_cursor, 1, "the replayed forced inclusion cursor");
    assert_eq!(devnet.app_halt(0), None);
    eprintln!("replayed past the forced block {forced} after {:?}", started.elapsed());

    devnet.stop().await?;
    eprintln!("forced inclusion scenario done after {:?}", started.elapsed());
    Ok(())
}

/// A validator without beacon access cannot build a block consuming a due entry: its rounds at
/// those heights produce nothing, and the other validators include the entries.
///
/// Three entries are planted in one L1 block, so they are due at the same anchor and fill three
/// consecutive blocks. With three equal validators CometBFT's round-0 proposer rotates through
/// all three over any three consecutive heights (round changes within a height do not carry
/// over), so the blind validator is the round-0 proposer of one of the forced heights: it
/// refuses (`blob_unavailable` in its `/status` until its next commit) and the height commits in
/// a later round, proposed by another validator.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn validators_without_beacon_include_calldata() -> anyhow::Result<()> {
    /// The validator whose app has no beacon.
    const BLIND: usize = 1;
    /// The entries planted together.
    const ENTRIES: u64 = 3;
    let started = Instant::now();
    let spec = DevnetSpec {
        validators: 3,
        initial_validators: 3,
        forced_inclusion_delay: DELAY,
        validators_without_beacon: vec![BLIND],
        ..Default::default()
    };
    let devnet = Devnet::start(spec).await?;
    devnet.wait_for_height(0, 3, Duration::from_secs(90)).await?;

    // Watch the blind app's halt reasons while the entries are pending.
    let (stop, mut stopped) = oneshot::channel::<()>();
    let blind_cmt = devnet.cmt(BLIND).clone();
    let watcher = tokio::spawn(async move {
        let mut reasons = BTreeSet::new();
        loop {
            if let Ok(status) = blind_cmt.abci_status().await {
                reasons.extend(status.halt_reason);
            }
            tokio::select! {
                _ = &mut stopped => break reasons,
                _ = tokio::time::sleep(Duration::from_millis(200)) => {}
            }
        }
    });
    let forced = force_transfers(&devnet, ENTRIES, Duration::from_secs(DELAY + 60)).await;
    drop(stop);
    let reasons = watcher.await?;
    let forced = forced?;
    eprintln!("blind validator halt reasons while the entries were pending: {reasons:?}");
    assert!(!reasons.contains(BLOB_UNAVAILABLE), "calldata proposing needs no beacon");

    let blind = devnet.keys()[BLIND].address();
    let mut rounds = Vec::new();
    for &h in &forced {
        let proposer = devnet.cmt(0).proposer_address(h).await?;
        let _ = (proposer, &blind);
        rounds.push(commit_round(&devnet, h).await?);
    }
    eprintln!("forced blocks {forced:?} committed in rounds {rounds:?}");

    // Every node, the blind one included, executed the forced blocks.
    let last = *forced.last().context("no forced block")?;
    devnet.wait_for_height(BLIND, last + 2, Duration::from_secs(30)).await?;
    for &h in &forced {
        let block = devnet.l2_provider(0).get_block_by_number(BlockNumberOrTag::Number(h)).await?;
        let hash =
            block.with_context(|| format!("forced block {h} missing on node 0"))?.header.hash;
        for i in 1..3 {
            let block =
                devnet.l2_provider(i).get_block_by_number(BlockNumberOrTag::Number(h)).await?;
            assert_eq!(block.map(|b| b.header.hash), Some(hash), "EL {i} at block {h}");
        }
    }
    for i in 0..3 {
        assert_eq!(devnet.app_halt(i), None);
    }

    devnet.stop().await?;
    eprintln!("blind validator scenario done after {:?}", started.elapsed());
    Ok(())
}

/// With L1 paused, the chain runs on its frozen anchor until a block would be more than
/// `maxAnchorAge` (20 s) younger than it, then stops; once L1 resumes, it continues.
///
/// `L = 60`, `D_MAX = 52`, `MARGIN_V = 2` give the unsettled cap `U = 50`, far above the ~25
/// blocks the chain trails its frozen `lastCheckpoint` by when the anchor gets too old, so only
/// anchor freshness can stop it, and the epoch boundary stays out of reach.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn stale_l1_finality_pauses_and_resumes_l2() -> anyhow::Result<()> {
    /// How long L1 stays paused.
    const PAUSE: Duration = Duration::from_secs(40);
    let started = Instant::now();
    let spec = DevnetSpec {
        epoch_len: 60,
        d_max: 52,
        margin_v: 2,
        max_anchor_age: 20,
        ..Default::default()
    };
    let devnet = Devnet::start(spec.clone()).await?;
    devnet.wait_for_height(0, 5, Duration::from_secs(60)).await?;
    let l1 = devnet.l1();
    let l2 = devnet.l2_provider(0);

    devnet.l1_pause().await?;
    let paused = Instant::now();
    tokio::time::sleep(Duration::from_millis(1500)).await;
    let frozen = finalized_number(l1).await?;
    let paused_at = devnet.cmt(0).latest_height().await?;
    eprintln!("L1 paused at finalized {frozen}, CometBFT height {paused_at}");

    // The chain stops once its anchor is too old.
    let d = &devnet;
    wait_until("the anchor freshness halt", PAUSE, Duration::from_millis(250), || async move {
        if let Some(reason) = d.app_halt(0) {
            return Err(Fatal(anyhow!("app 0 halted: {reason}")).into());
        }
        let reason = d.abci_status(0).await?.halt_reason;
        Ok((reason.as_deref() == Some(ANCHOR_TOO_OLD)).then_some(()))
    })
    .await?;
    let stalled_at = devnet.cmt(0).latest_height().await?;
    eprintln!("stalled at height {stalled_at} {:?} after the pause", paused.elapsed());
    assert!(stalled_at > paused_at + 5, "the chain stopped early, at {stalled_at}");
    let mut reasons = BTreeSet::new();
    while paused.elapsed() < PAUSE {
        assert_eq!(devnet.cmt(0).latest_height().await?, stalled_at, "the chain moved");
        reasons.extend(devnet.abci_status(0).await?.halt_reason);
        tokio::time::sleep(Duration::from_millis(250)).await;
    }
    assert_eq!(reasons, BTreeSet::from([ANCHOR_TOO_OLD.to_string()]), "/status halt reasons");
    assert_eq!(finalized_number(l1).await?, frozen, "L1 finalized moved while paused");
    assert_eq!(l2.get_block_number().await?, stalled_at, "the EL moved");
    let head = l2
        .get_block_by_number(BlockNumberOrTag::Number(stalled_at))
        .await?
        .context("stalled head missing")?;
    let anchor = anchor_of(&l2, stalled_at).await?;
    let age = head.header.timestamp.saturating_sub(l1_timestamp(&devnet, anchor).await?);
    assert!(age <= spec.max_anchor_age, "head {stalled_at} is {age} s younger than its anchor");

    // Once L1 finalizes fresh blocks, the chain continues on a newer anchor.
    devnet.l1_resume().await?;
    let resumed = Instant::now();
    devnet.wait_for_height(0, stalled_at + 3, Duration::from_secs(30)).await?;
    eprintln!("resumed {:?} after L1", resumed.elapsed());
    let anchor = anchor_of(&l2, stalled_at + 3).await?;
    assert!(anchor > frozen, "block {} anchors at {anchor}, not above {frozen}", stalled_at + 3);
    assert_eq!(devnet.app_halt(0), None);

    devnet.stop().await?;
    eprintln!("stale L1 finality scenario done after {:?}", started.elapsed());
    Ok(())
}
