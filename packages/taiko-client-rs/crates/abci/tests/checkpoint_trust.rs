//! Real Comet v0.40.0 signing boundaries, preserved signing state and history catch-up.

use std::{fs, time::Duration};

use alloy_primitives::B256;
use anyhow::{Context, Result, ensure};
use test_harness::{Devnet, DevnetSpec, InboxValues, wait_until};

const WAIT: Duration = Duration::from_secs(90);
const POLL: Duration = Duration::from_millis(100);

async fn trust(devnet: &Devnet, node: usize) -> Result<serde_json::Value> {
    let response = devnet.trust_control(node, "read-current-session").await?;
    let session = response["session_id"].as_str().context("opaque trust session")?;
    devnet.trust_control(node, session).await
}

async fn ready(devnet: &Devnet, node: usize) -> Result<serde_json::Value> {
    wait_until("Etna checkpoint Ready", WAIT, POLL, || async {
        let snapshot = trust(devnet, node).await?;
        Ok((snapshot["trust_ready"] == true).then_some(snapshot))
    })
    .await
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn checkpoint_trust_first_start_comet_reconnect_and_app_crash_fail_closed() -> Result<()> {
    let mut devnet = Devnet::start(DevnetSpec::default()).await?;
    devnet.wait_for_height(0, 4, WAIT).await?;
    devnet.lander_pause().await;
    let first = ready(&devnet, 0).await?;
    let height = devnet.cmt(0).latest_height().await?;
    let state = devnet.signer_state(0)?;
    assert!(state["height"].as_str().unwrap().parse::<u64>()? >= height);
    devnet.cmt_restart(0).await?;
    let second = ready(&devnet, 0).await?;
    assert_ne!(first["session_id"], second["session_id"], "Comet-only restart must rearm");
    devnet.wait_for_height(0, height + 2, WAIT).await?;

    // An authorization immediately preceding crash can finish; allow that one to drain.
    devnet.app_stop(0).await;
    tokio::time::sleep(Duration::from_millis(500)).await;
    let stopped = devnet.signer_state(0)?;
    let delegated = devnet.signer_authorizations(0)?;
    tokio::time::sleep(Duration::from_secs(3)).await;
    assert_eq!(stopped, devnet.signer_state(0)?, "app loss must not allow further FilePV writes");
    assert_eq!(delegated, devnet.signer_authorizations(0)?, "no cached Ready after app death");
    devnet.app_start(0).await?;
    let old = second["session_id"].as_str().unwrap();
    let response = devnet.trust_control(0, old).await?;
    assert_eq!(response["trust_ready"], false);
    assert_ne!(
        response["session_id"], second["session_id"],
        "app-only restart changes incarnation"
    );
    // The pinned ABCI socket client may hang after app EOF; bounded pair supervision reaps it.
    devnet.node_stop(0).await?;
    devnet.app_start(0).await?;
    devnet.cmt_restart(0).await?;
    ready(&devnet, 0).await?;
    devnet.wait_for_height(0, height + 4, WAIT).await?;

    // Own-L1 proof acquisition must remain closed even when Comet itself is ready. Keep
    // Anvil's process/ports/state intact, then prove idle retries recover without a new block.
    devnet.node_stop(0).await?;
    let before_l1 = devnet.signer_state(0)?;
    let calls = devnet.signer_authorizations(0)?;
    devnet.l1_rpc_pause().await?;
    devnet.app_start(0).await?;
    devnet.cmt_restart(0).await?;
    tokio::time::sleep(Duration::from_secs(3)).await;
    let unavailable = trust(&devnet, 0).await?;
    assert_eq!(unavailable["trust_ready"], false);
    assert_eq!(unavailable["phase"], "acquiring");
    assert_eq!(before_l1, devnet.signer_state(0)?);
    assert_eq!(calls, devnet.signer_authorizations(0)?);
    devnet.l1_rpc_resume().await?;
    ready(&devnet, 0).await?;
    devnet.wait_for_height(0, height + 6, WAIT).await?;
    devnet.stop().await
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn checkpoint_trust_ahead_keeps_short_local_tip_nonsigning() -> Result<()> {
    let mut devnet = Devnet::start(DevnetSpec::default()).await?;
    devnet.wait_for_height(0, 4, WAIT).await?;
    devnet.lander_pause().await;
    devnet.node_stop(0).await?;
    let saved: abci::AppState =
        serde_json::from_slice(&fs::read(devnet.app_data_dir(0).join(abci::store::STATE_FILE))?)?;
    let head = saved.last_height;
    let before = devnet.signer_state(0)?;
    devnet
        .planter()
        .plant_inbox(&InboxValues {
            last_checkpoint: Some((head + 50, B256::repeat_byte(0x91))),
            checkpoint_comet_hash: Some(B256::repeat_byte(0x93)),
            ..Default::default()
        })
        .await?;
    // anvil finalizes latest-2; let the authenticated checkpoint become final.
    tokio::time::sleep(Duration::from_secs(4)).await;
    devnet.app_start(0).await?;
    devnet.cmt_restart(0).await?;
    tokio::time::sleep(Duration::from_secs(4)).await;
    let snapshot = trust(&devnet, 0).await?;
    assert_eq!(snapshot["trust_ready"], false);
    assert_eq!(snapshot["phase"], "catching_up");
    assert_eq!(snapshot["trusted_consensus_head"], serde_json::Value::Null);
    assert_eq!(snapshot["target"]["height"], head + 50);
    assert_eq!(before, devnet.signer_state(0)?);
    devnet.stop().await
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn checkpoint_trust_mismatch_during_intact_comet_replay_never_signs_or_commits_target()
-> Result<()> {
    let mut devnet = Devnet::start(DevnetSpec::default()).await?;
    devnet.wait_for_height(0, 8, WAIT).await?;
    devnet.lander_pause().await;
    devnet.node_stop(0).await?;
    let before = devnet.signer_state(0)?;
    let delegated = devnet.signer_authorizations(0)?;
    devnet
        .planter()
        .plant_inbox(&InboxValues {
            last_checkpoint: Some((4, B256::repeat_byte(0x92))),
            checkpoint_comet_hash: Some(B256::repeat_byte(0x94)),
            ..Default::default()
        })
        .await?;
    tokio::time::sleep(Duration::from_secs(4)).await;
    // Only the app's test-owned state is moved aside. Every Comet WAL/blockstore byte and
    // the actual signing state remain intact, as in the existing state-loss replay test.
    let file = devnet.app_data_dir(0).join(abci::store::STATE_FILE);
    fs::rename(&file, file.with_extension("saved.json"))?;
    devnet.app_start(0).await?;
    devnet.cmt_restart_begin(0).await?;
    wait_until("checkpoint mismatch halt", WAIT, POLL, || async {
        Ok(devnet.app_halt(0).map(|reason| {
            eprintln!("expected checkpoint mismatch: {reason}");
            reason
        }))
    })
    .await?;
    assert_eq!(before, devnet.signer_state(0)?);
    assert_eq!(delegated, devnet.signer_authorizations(0)?);
    let state: abci::AppState = serde_json::from_slice(&fs::read(file)?)?;
    assert!(state.last_height < 4, "mismatching target must never be durable");
    devnet.stop().await
}

/// The retained-history peer restarts as an unregistered observer, avoiding a blocked signer
/// holding its consensus mutex. The behind peer takes the existing real key+state by reference.
/// Its local voting power causes stock Comet to enter consensus early, exercising commit gossip.
async fn catch_up_with_local_voting_power(validators: usize, initial: usize) -> Result<()> {
    let mut devnet = Devnet::start(DevnetSpec {
        validators,
        initial_validators: initial,
        epoch_len: 100,
        ..Default::default()
    })
    .await?;
    let observer = validators - 1;
    devnet.wait_for_height(observer, 2, WAIT).await?;
    devnet.node_stop(observer).await?;
    let behind = devnet.signer_state(observer)?;
    devnet.wait_for_height(0, 12, WAIT).await?;
    devnet.lander_pause().await;
    tokio::time::sleep(Duration::from_secs(4)).await;
    let source_head = devnet.cmt(0).latest_height().await?;
    devnet.node_stop(0).await?;
    let original_state = devnet.signer_state(0)?;
    devnet.signer_swap_identity(observer, 0);
    assert_eq!(
        original_state,
        devnet.signer_state(observer)?,
        "same existing FilePV state, never reset"
    );
    assert_ne!(original_state, behind, "observer adopted the registered identity and existing HRS");
    assert_eq!(
        behind,
        devnet.signer_state(0)?,
        "retained peer uses the existing unregistered observer state"
    );
    devnet.app_start(0).await?;
    devnet.cmt_restart(0).await?;
    let delegated = devnet.signer_authorizations(observer)?;
    devnet.app_start(observer).await?;
    devnet.cmt_restart(observer).await?;
    wait_until("real Comet high-power checkpoint catch-up", WAIT, POLL, || async {
        let count = devnet.signer_authorizations(observer)?;
        let snapshot = trust(&devnet, observer).await?;
        if snapshot["trust_ready"] != true {
            ensure!(count == delegated, "FilePV received a request before checkpoint match");
            return Ok(None);
        }
        ensure!(
            snapshot["target"]["height"].as_u64().unwrap_or(0) > 2,
            "target must require historical catch-up"
        );
        Ok(Some(()))
    })
    .await?;
    devnet.wait_for_height(observer, source_head, WAIT).await?;
    devnet.stop().await
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn checkpoint_trust_sole_validator_catches_up_from_retained_peer_history_while_signer_closed()
-> Result<()> {
    catch_up_with_local_voting_power(2, 1).await
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn checkpoint_trust_one_third_local_power_catches_up_from_retained_peer_history_while_signer_closed()
-> Result<()> {
    catch_up_with_local_voting_power(4, 3).await
}
