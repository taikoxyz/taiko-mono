//! Docker scenarios: forced inclusion and anchor freshness on the ABCI devnet.
//!
//! [`Planter::plant_forced_inclusion`](test_harness::Planter::plant_forced_inclusion) writes a
//! forced inclusion entry into the setter-planted Inbox in the same L1 block as a type-3
//! transaction carrying the entry's blob; a proposer fetches the blob through the harness's fake
//! beacon, which serves anvil's blobs. With a 10 s delay an entry is due once the anchor (anvil's
//! `finalized`, two blocks behind its tip) is an L1 block at least 10 s younger than the entry.

use std::{
    collections::BTreeSet,
    fs,
    time::{Duration, Instant},
};

use abci::{AppState, store::STATE_FILE};
use alloy_eips::{BlockId, BlockNumberOrTag};
use alloy_primitives::{Address, B256, U256, address};
use alloy_provider::{Provider, RootProvider};
use anyhow::{Context, anyhow, ensure};
use test_harness::{
    Devnet, DevnetSpec, Fatal, anchor_of, dev_signer, finalized_number, sign_transfer, wait_until,
};

/// The genesis forced inclusion delay of the forced inclusion scenarios, in seconds.
const DELAY: u64 = 10;

/// The recipient of the forced transfer (a fresh account).
const RECIPIENT: Address = address!("00000000000000000000000000000000000f0ced");

/// The value of the forced transfer, in wei.
const VALUE: u64 = 4_242;

/// The `/status` halt reason of the anchor freshness rule (`RuleViolation::AnchorTooOld`).
const ANCHOR_TOO_OLD: &str = "anchor_too_old";

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

/// The EL hashes of blocks `1..=head` of `l2`.
async fn block_hashes(l2: &RootProvider, head: u64) -> anyhow::Result<Vec<B256>> {
    let mut hashes = Vec::new();
    for h in 1..=head {
        let block = l2
            .get_block_by_number(BlockNumberOrTag::Number(h))
            .await?
            .with_context(|| format!("L2 block {h} missing"))?;
        hashes.push(block.header.hash);
    }
    Ok(hashes)
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

/// Plants a forced transfer of [`VALUE`] to [`RECIPIENT`] from the funded dev account and
/// waits for its inclusion within `timeout`; checks that block `F` holding it holds exactly that
/// transaction, moved exactly the value plus the gas from the sender to the recipient, anchors
/// at an L1 block at least [`DELAY`] seconds younger than the entry, and is decided with the
/// entry's witness and blob, while every block before it carried at most a peek (no blob) at
/// entry 0. Returns `F`.
async fn force_a_transfer(devnet: &Devnet, timeout: Duration) -> anyhow::Result<u64> {
    let l2 = devnet.l2_provider(0);
    let signer = dev_signer();
    let nonce = l2.get_transaction_count(signer.address()).await?;
    let tx = sign_transfer(&l2, &signer, RECIPIENT, U256::from(VALUE), nonce).await?;
    let hash = *tx.tx_hash();
    let entry = devnet.planter().plant_forced_inclusion(vec![tx]).await?;
    let planted = Instant::now();
    eprintln!("planted forced inclusion entry {entry:?} for {hash}");
    assert_eq!(entry.index, 0, "the queue was empty");

    let forced = wait_for_inclusion(devnet, hash, timeout).await?;
    eprintln!("forced transaction in L2 block {forced} {:?} after planting", planted.elapsed());
    let block = l2
        .get_block_by_number(BlockNumberOrTag::Number(forced))
        .await?
        .with_context(|| format!("L2 block {forced} missing"))?;
    assert_eq!(block.transactions.hashes().collect::<Vec<_>>(), vec![hash], "block {forced}");

    let receipt = l2.get_transaction_receipt(hash).await?.context("receipt vanished")?;
    let gas = U256::from(receipt.gas_used) * U256::from(receipt.effective_gas_price);
    let at = |n: u64| BlockId::number(n);
    let sender = signer.address();
    let spent = l2.get_balance(sender).block_id(at(forced - 1)).await? -
        l2.get_balance(sender).block_id(at(forced)).await?;
    assert_eq!(spent, U256::from(VALUE) + gas, "the sender paid the value plus the gas");
    assert_eq!(l2.get_balance(RECIPIENT).block_id(at(forced - 1)).await?, U256::ZERO);
    assert_eq!(l2.get_balance(RECIPIENT).block_id(at(forced)).await?, U256::from(VALUE));

    let anchor = anchor_of(&l2, forced).await?;
    let anchor_time = l1_timestamp(devnet, anchor).await?;
    assert!(
        anchor_time >= entry.timestamp + DELAY,
        "block {forced} anchors at L1 block {anchor} (time {anchor_time}), before the entry \
         (time {}) was due",
        entry.timestamp
    );

    let envelope = devnet.cmt(0).envelope(forced).await?;
    let witness = envelope.forced.context("the forced block carries no forced witness")?;
    assert_eq!(witness.index, entry.index);
    assert!(!witness.blob.is_empty(), "the forced block carries no blob");
    for h in 1..forced {
        if let Some(peek) = devnet.cmt(0).envelope(h).await?.forced {
            assert_eq!(peek.index, entry.index, "block {h} names another entry");
            assert!(peek.blob.is_empty(), "block {h} carries a blob before the forced block");
        }
    }
    Ok(forced)
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn forced_inclusion_executes_after_the_delay() -> anyhow::Result<()> {
    let started = Instant::now();
    let spec = DevnetSpec { forced_inclusion_delay: DELAY, ..Default::default() };
    let mut devnet = Devnet::start(spec).await?;
    devnet.wait_for_height(0, 3, Duration::from_secs(60)).await?;

    let forced = force_a_transfer(&devnet, Duration::from_secs(DELAY + 30)).await?;

    // The entry is consumed: later blocks carry no forced witness.
    devnet.wait_for_height(0, forced + 3, Duration::from_secs(30)).await?;
    for h in forced + 1..=forced + 3 {
        let envelope = devnet.cmt(0).envelope(h).await?;
        assert_eq!(envelope.forced, None, "block {h} carries a forced witness");
    }

    // Crash replay: the app loses its state and replays every block, the forced one included,
    // through a cold FinalizeBlock that rebuilds the forced block on its parent while the EL's
    // head is far above it.
    devnet.lander_pause().await;
    devnet.app_stop(0).await;
    let d = &devnet;
    wait_until("CometBFT exit", Duration::from_secs(30), Duration::from_millis(100), || async {
        Ok((!d.cmt_running(0).await?).then_some(()))
    })
    .await?;
    let file = devnet.app_data_dir(0).join(STATE_FILE);
    let before: AppState = serde_json::from_slice(&fs::read(&file)?)?;
    assert_eq!(before.forced_cursor, 1, "the persisted forced inclusion cursor");
    let l2 = devnet.l2_provider(0);
    let old_hashes = block_hashes(&l2, before.last_height).await?;
    fs::rename(&file, devnet.app_data_dir(0).join("abci-state.saved.json"))?;

    devnet.app_start(0).await?;
    devnet.cmt_restart(0).await?;
    devnet.wait_for_height(0, before.last_height, Duration::from_secs(60)).await?;
    let restored: AppState = serde_json::from_slice(&fs::read(&file)?)?;
    assert!(restored.last_height >= before.last_height);
    assert_eq!(restored.forced_cursor, 1, "the replayed forced inclusion cursor");
    assert_eq!(block_hashes(&l2, before.last_height).await?, old_hashes);
    devnet.lander_resume();
    devnet.wait_for_height(0, before.last_height + 3, Duration::from_secs(60)).await?;
    assert_eq!(devnet.app_halt(0), None);
    eprintln!("replayed past the forced block {forced} after {:?}", started.elapsed());

    devnet.stop().await?;
    eprintln!("forced inclusion scenario done after {:?}", started.elapsed());
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn validator_without_beacon_cannot_censor() -> anyhow::Result<()> {
    /// The validator whose app has no beacon.
    const BLIND: usize = 1;
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

    // A round the blind validator proposes at the due height (whether it gets one depends on
    // the rotation) produces nothing; another proposer's round includes the entry, and the blind
    // validator votes for it: with three equal validators every commit needs all three.
    let forced = force_a_transfer(&devnet, Duration::from_secs(DELAY + 60)).await?;
    let blind = devnet.keys()[BLIND].address();
    let proposer = devnet.cmt(0).proposer_address(forced).await?;
    assert_ne!(proposer, blind, "the blind validator built block {forced}");
    assert!(devnet.cmt(0).commit_signers(forced).await?.contains(&blind), "blind precommit");
    let round = devnet.cmt(0).call("commit", &[("height", forced.to_string())]).await?
        ["signed_header"]["commit"]["round"]
        .clone();
    eprintln!("forced block {forced} proposed by {proposer} in round {round}");

    // Every node, the blind one included, executed the forced block.
    devnet.wait_for_height(BLIND, forced + 2, Duration::from_secs(30)).await?;
    let hash = devnet.l2_provider(0).get_block_by_number(BlockNumberOrTag::Number(forced)).await?;
    let hash = hash.context("forced block missing on node 0")?.header.hash;
    for i in 0..3 {
        let block =
            devnet.l2_provider(i).get_block_by_number(BlockNumberOrTag::Number(forced)).await?;
        assert_eq!(block.map(|b| b.header.hash), Some(hash), "EL {i} at block {forced}");
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
