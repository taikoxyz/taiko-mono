//! Execute the actual lander command against pinned deployed contracts and genuine certificates.

#[path = "../../../crates/lander/tests/support/mod.rs"]
mod contracts_support;
mod support {
    pub mod lander;
}

use std::{
    path::Path,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use alloy_primitives::U256;
use alloy_provider::Provider;
use anyhow::{Context, Result, ensure};
use contracts_support::{ContractFixture, fixtures::FixtureChain};
use lander::store::{JournalIdentity, Store};
use serde_json::json;
use support::lander::{CliInputs, CliProcess, FixtureRpc, RpcData};
use tempfile::TempDir;
use test_harness::{DEV_KEY, anvil_request, dev_signer, mine_l1_blocks};

/// Cargo supplies the exact client executable built with this integration target.
const CLIENT: &str = env!("CARGO_BIN_EXE_taiko-client");

fn rpc_data(chain: &FixtureChain) -> RpcData {
    RpcData {
        blocks: chain.blocks.clone(),
        headers: chain.headers.clone(),
        committees: chain
            .committees
            .iter()
            .map(|(epoch, committee)| (*epoch, committee.state.clone()))
            .collect(),
    }
}

fn inputs(fixture: &ContractFixture, rpc: &FixtureRpc, root: &TempDir) -> Result<CliInputs> {
    let key = root.path().join("key.hex");
    let chain_config = root.path().join("chain.toml");
    std::fs::write(&key, DEV_KEY.to_string())?;
    std::fs::write(key.with_file_name("jwt.hex"), "11".repeat(32))?;
    std::fs::write(
        &chain_config,
        format!(
            "inbox = \"{}\"\nregistry = \"{}\"\nd_max = 12\nmargin_v = 2\n",
            fixture.inbox, fixture.registry,
        ),
    )?;
    Ok(CliInputs {
        l1: fixture.anvil.http.clone(),
        rpc: rpc.url.clone(),
        key,
        data: root.path().join("lander"),
        chain_config,
        max_blocks: fixture
            .genesis
            .epoch_len
            .checked_add(2)
            .context("fixture batch cap overflow")?,
    })
}

async fn wait_checkpoint(
    fixture: &ContractFixture,
    process: &mut CliProcess,
    height: u64,
) -> Result<()> {
    wait_checkpoint_before(fixture, process, height, Duration::from_secs(90)).await
}

async fn wait_checkpoint_before(
    fixture: &ContractFixture,
    process: &mut CliProcess,
    height: u64,
    deadline: Duration,
) -> Result<()> {
    tokio::time::timeout(deadline, async {
        loop {
            process.assert_running()?;
            let checkpoint = fixture.checkpoint().await?;
            if checkpoint.0 >= height {
                return Ok(());
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
    })
    .await
    .map_err(|error| {
        anyhow::anyhow!("checkpoint did not reach {height}: {error}\n{}", process.output())
    })?
}

fn assert_key_absent(process: &CliProcess) {
    let output = process.output();
    let key = DEV_KEY.to_string();
    assert!(!output.contains(&key), "CLI output exposed signing-key bytes");
    assert!(!output.contains(key.trim_start_matches("0x")), "CLI output exposed raw key bytes");
}

#[tokio::test]
#[ignore = "docker"]
async fn lander_cli_lands_blob_batches_and_resumes_after_sigterm() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let result = async {
        let mut chain = FixtureChain::new(&fixture).await?;
        chain.extend(&fixture, 5).await?;
        let rpc = FixtureRpc::start(rpc_data(&chain)).await?;
        let directory = TempDir::new()?;
        let args = inputs(&fixture, &rpc, &directory)?;
        let sender = dev_signer().address();
        let nonce = fixture.anvil.provider.get_transaction_count(sender).await?;
        let mut first =
            CliProcess::spawn(Path::new(CLIENT), &args, directory.path().join("first.log"), &[])?;
        wait_checkpoint(&fixture, &mut first, 5).await?;
        ensure!(
            fixture.checkpoint().await? == (5, chain.headers[5].hash_slow()),
            "first CLI checkpoint differs from genuine decided chain"
        );
        ensure!(first.signal(libc::SIGTERM).await?.success(), "SIGTERM should exit cleanly");
        assert_key_absent(&first);
        mine_l1_blocks(&fixture.anvil.provider, 3).await?;
        let resumed_height = fixture.genesis.epoch_len + 2;
        chain.extend(&fixture, resumed_height).await?;
        rpc.replace(rpc_data(&chain)).await;
        let mut second =
            CliProcess::spawn(Path::new(CLIENT), &args, directory.path().join("second.log"), &[])?;
        wait_checkpoint(&fixture, &mut second, resumed_height).await?;
        ensure!(
            fixture.checkpoint().await? ==
                (resumed_height, chain.headers[usize::try_from(resumed_height)?].hash_slow()),
            "resumed CLI checkpoint differs"
        );
        ensure!(
            second.signal(libc::SIGTERM).await?.success(),
            "restarted command should stop gracefully"
        );
        ensure!(
            fixture.anvil.provider.get_transaction_count(sender).await? == nonce + 2,
            "expected two real blob landing transactions"
        );
        assert_key_absent(&second);
        Ok(())
    }
    .await;
    if result.is_err() {
        fixture.anvil.dump_logs();
    }
    result
}

#[tokio::test]
#[ignore = "docker"]
async fn lander_cli_sigkill_reconciles_the_same_pending_nonce_before_progress() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let result = async {
        let mut chain = FixtureChain::new(&fixture).await?;
        chain.extend(&fixture, 5).await?;
        let rpc = FixtureRpc::start(rpc_data(&chain)).await?;
        let directory = TempDir::new()?;
        let args = inputs(&fixture, &rpc, &directory)?;
        let sender = dev_signer().address();
        let nonce = fixture.anvil.provider.get_transaction_count(sender).await?;
        anvil_request::<serde_json::Value>(
            &fixture.anvil.provider,
            "evm_setAutomine",
            json!([false]),
        )
        .await?;
        let mut first = CliProcess::spawn(
            Path::new(CLIENT),
            &args,
            directory.path().join("pending-first.log"),
            &[],
        )?;
        let journal = first.wait_phase(&args.data, "pending").await?;
        let original = &journal["state"]["transaction"];
        ensure!(original["nonce"].as_u64() == Some(nonce), "journal recorded a different nonce");
        ensure!(!first.signal(libc::SIGKILL).await?.success(), "SIGKILL should be an abrupt exit");
        assert_key_absent(&first);
        let mut second = CliProcess::spawn(
            Path::new(CLIENT),
            &args,
            directory.path().join("pending-second.log"),
            &[],
        )?;
        let resumed = second.wait_phase(&args.data, "pending").await?;
        ensure!(
            resumed["state"]["transaction"] == *original,
            "restart changed signed network bytes or nonce"
        );
        // Resume from both sides of the broadcast boundary: the durable phase may have been
        // written immediately before SIGKILL, or the first process may already have sent it.
        // Mining remains disabled long enough for the restarted process to reconcile/rebroadcast.
        tokio::time::sleep(Duration::from_millis(750)).await;
        anvil_request::<serde_json::Value>(
            &fixture.anvil.provider,
            "evm_setAutomine",
            json!([true]),
        )
        .await?;
        mine_l1_blocks(&fixture.anvil.provider, 1).await?;
        wait_checkpoint(&fixture, &mut second, 5).await?;
        ensure!(
            fixture.anvil.provider.get_transaction_count(sender).await? == nonce + 1,
            "restart consumed an extra nonce"
        );
        mine_l1_blocks(&fixture.anvil.provider, 3).await?;
        let resumed_height = fixture.genesis.epoch_len + 2;
        chain.extend(&fixture, resumed_height).await?;
        rpc.replace(rpc_data(&chain)).await;
        wait_checkpoint(&fixture, &mut second, resumed_height).await?;
        ensure!(
            fixture.anvil.provider.get_transaction_count(sender).await? == nonce + 2,
            "continued progress did not retain one nonce per landing"
        );
        ensure!(
            second.signal(libc::SIGTERM).await?.success(),
            "restarted command should stop gracefully"
        );
        assert_key_absent(&second);
        Ok(())
    }
    .await;
    if result.is_err() {
        fixture.anvil.dump_logs();
    }
    result
}

#[tokio::test]
#[ignore = "docker"]
async fn lander_cli_refuses_locks_corrupt_journals_and_invalid_caps_before_signing() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let result = async {
        let mut chain = FixtureChain::new(&fixture).await?;
        chain.extend(&fixture, 1).await?;
        let rpc = FixtureRpc::start(rpc_data(&chain)).await?;
        let directory = TempDir::new()?;
        let args = inputs(&fixture, &rpc, &directory)?;
        let sender = dev_signer().address();
        let nonce = fixture.anvil.provider.get_transaction_count(sender).await?;
        let identity = JournalIdentity {
            l1_chain_id: U256::from(31337),
            l2_chain_id: 167001,
            inbox: fixture.inbox,
            registry: fixture.registry,
            sender,
        };
        let lock = Store::open(&args.data, identity)?;
        let mut locked =
            CliProcess::spawn(Path::new(CLIENT), &args, directory.path().join("locked.log"), &[])?;
        ensure!(!locked.wait_exit().await?.success(), "second process obtained an owned journal");
        ensure!(
            locked.output().contains("locked"),
            "lock error lacks operator context: {}",
            locked.output()
        );
        assert_key_absent(&locked);
        drop(lock);
        std::fs::write(args.data.join("lander-state.json"), "{broken committed journal")?;
        let mut corrupt =
            CliProcess::spawn(Path::new(CLIENT), &args, directory.path().join("corrupt.log"), &[])?;
        ensure!(!corrupt.wait_exit().await?.success(), "corrupt main journal was discarded");
        ensure!(
            corrupt.output().contains("corrupt journal"),
            "unexpected corruption error: {}",
            corrupt.output()
        );
        assert_key_absent(&corrupt);
        let mut invalid = CliProcess::spawn(
            Path::new(CLIENT),
            &args,
            directory.path().join("invalid.log"),
            &[("--max-priority-fee-per-gas", "100000000001")],
        )?;
        ensure!(!invalid.wait_exit().await?.success(), "invalid fee policy reached the runner");
        ensure!(
            invalid.output().contains("fee caps"),
            "invalid fee error lacked context: {}",
            invalid.output()
        );
        assert_key_absent(&invalid);
        ensure!(
            fixture.anvil.provider.get_transaction_count(sender).await? == nonce,
            "fatal startup error submitted a transaction"
        );
        ensure!(fixture.checkpoint().await?.0 == 0, "fatal startup error advanced the checkpoint");
        Ok(())
    }
    .await;
    if result.is_err() {
        fixture.anvil.dump_logs();
    }
    result
}

async fn wait_batch_marker(
    process: &mut CliProcess,
    directory: &Path,
) -> Result<serde_json::Value> {
    tokio::time::timeout(Duration::from_secs(5), async {
        loop {
            process.assert_running()?;
            if let Ok(bytes) = std::fs::read(directory.join("lander-state.json")) &&
                let Ok(journal) = serde_json::from_slice::<serde_json::Value>(&bytes) &&
                journal["state"]["phase"] == "idle" &&
                journal["waiting"].is_object()
            {
                return Ok(journal["waiting"].clone());
            }
            tokio::time::sleep(Duration::from_millis(25)).await;
        }
    })
    .await
    .map_err(|error| {
        anyhow::anyhow!("no durable batch wait marker: {error}\n{}", process.output())
    })?
}

#[tokio::test]
#[ignore = "docker"]
async fn lander_cli_submits_at_minimum_or_timeout_and_keeps_wait_after_sigkill() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let result = async {
        let mut chain = FixtureChain::new(&fixture).await?;
        chain.extend(&fixture, 1).await?;
        let rpc = FixtureRpc::start(rpc_data(&chain)).await?;
        let directory = TempDir::new()?;
        let args = inputs(&fixture, &rpc, &directory)?;
        let policy = [("--min-blocks", "3"), ("--max-batch-wait", "30")];
        let sender = dev_signer().address();
        let nonce = fixture.anvil.provider.get_transaction_count(sender).await?;
        let mut first = CliProcess::spawn(
            Path::new(CLIENT),
            &args,
            directory.path().join("batch-first.log"),
            &[("--min-blocks", "1"), ("--max-batch-wait", "30")],
        )?;
        // Seed the checkpoint explicitly; genesis carries no runtime publication witness.
        wait_checkpoint_before(&fixture, &mut first, 1, Duration::from_secs(15)).await?;
        ensure!(first.signal(libc::SIGTERM).await?.success(), "initial checkpoint exits cleanly");
        let mut first = CliProcess::spawn(
            Path::new(CLIENT),
            &args,
            directory.path().join("batch-policy.log"),
            &policy,
        )?;
        mine_l1_blocks(&fixture.anvil.provider, 3).await?;
        chain.extend(&fixture, 3).await?;
        rpc.replace(rpc_data(&chain)).await;
        let waiting = wait_batch_marker(&mut first, &args.data).await?;
        ensure!(waiting["checkpoint_height"] == 1, "wait attached to wrong checkpoint");
        tokio::time::sleep(Duration::from_millis(500)).await;
        first.assert_running()?;
        ensure!(fixture.checkpoint().await?.0 == 1, "submitted before minimum or deadline");
        ensure!(
            fixture.anvil.provider.get_transaction_count(sender).await? == nonce + 1,
            "waiting consumed a nonce",
        );
        chain.extend(&fixture, 4).await?;
        rpc.replace(rpc_data(&chain)).await;
        // Three publishable blocks trigger before the thirty-second timer.
        // The fifteen-second observation window includes real signing and inclusion overhead.
        wait_checkpoint_before(&fixture, &mut first, 4, Duration::from_secs(15)).await?;
        let first_seen = waiting["first_seen_unix_ms"]
            .as_u64()
            .context("durable waiting timer has no observation timestamp")?;
        let age_ms = SystemTime::now()
            .duration_since(UNIX_EPOCH)?
            .as_millis()
            .saturating_sub(u128::from(first_seen));
        ensure!(
            age_ms < 30_000,
            "minimum test reached the timer deadline instead of the count gate"
        );
        mine_l1_blocks(&fixture.anvil.provider, 3).await?;
        chain.extend(&fixture, 5).await?;
        rpc.replace(rpc_data(&chain)).await;
        let original_wait = wait_batch_marker(&mut first, &args.data).await?;
        ensure!(original_wait["checkpoint_height"] == 4, "new backlog retained old checkpoint");
        ensure!(!first.signal(libc::SIGKILL).await?.success(), "SIGKILL should be abrupt");
        let mut second = CliProcess::spawn(
            Path::new(CLIENT),
            &args,
            directory.path().join("batch-restarted.log"),
            &policy,
        )?;
        let restored_wait = wait_batch_marker(&mut second, &args.data).await?;
        ensure!(restored_wait == original_wait, "restart reset the durable batching timer");
        wait_checkpoint_before(&fixture, &mut second, 5, Duration::from_secs(50)).await?;
        ensure!(
            fixture.checkpoint().await? == (5, chain.headers[5].hash_slow()),
            "timeout checkpoint differs"
        );
        ensure!(
            fixture.anvil.provider.get_transaction_count(sender).await? == nonce + 3,
            "batch policy consumed extra nonces"
        );
        ensure!(second.signal(libc::SIGTERM).await?.success(), "SIGTERM should exit cleanly");
        assert_key_absent(&first);
        assert_key_absent(&second);
        Ok(())
    }
    .await;
    if result.is_err() {
        fixture.anvil.dump_logs();
    }
    result
}

#[tokio::test]
#[ignore = "docker"]
async fn lander_cli_flushes_backpressure_and_switch_witnesses_before_batch_deadline() -> Result<()>
{
    let fixture = ContractFixture::deploy().await?;
    let result = async {
        let mut chain = FixtureChain::new(&fixture).await?;
        chain.extend(&fixture, 1).await?;
        let rpc = FixtureRpc::start(rpc_data(&chain)).await?;
        let directory = TempDir::new()?;
        let args = inputs(&fixture, &rpc, &directory)?;
        let sender = dev_signer().address();
        let nonce = fixture.anvil.provider.get_transaction_count(sender).await?;
        let mut process = CliProcess::spawn(
            Path::new(CLIENT),
            &args,
            directory.path().join("batch-urgent.log"),
            &[("--min-blocks", "1"), ("--max-batch-wait", "3600")],
        )?;
        wait_checkpoint_before(&fixture, &mut process, 1, Duration::from_secs(15)).await?;
        ensure!(process.signal(libc::SIGTERM).await?.success(), "initial flush exits");
        let mut process = CliProcess::spawn(
            Path::new(CLIENT),
            &args,
            directory.path().join("batch-pressure.log"),
            &[("--min-blocks", "10"), ("--max-batch-wait", "3600")],
        )?;
        mine_l1_blocks(&fixture.anvil.provider, 3).await?;
        chain.extend(&fixture, 10).await?;
        rpc.replace(rpc_data(&chain)).await;
        // Nine unlanded blocks leave only one height before the builtin ABCI cap U=10.
        wait_checkpoint_before(&fixture, &mut process, 10, Duration::from_secs(15)).await?;
        ensure!(process.signal(libc::SIGTERM).await?.success(), "SIGTERM should exit cleanly");
        assert_key_absent(&process);
        // The unlanded switch at height 12 triggers useful settlement at depth 2.
        mine_l1_blocks(&fixture.anvil.provider, 3).await?;
        let switch_height = fixture.genesis.epoch_len - 1;
        chain.extend(&fixture, switch_height).await?;
        rpc.replace(rpc_data(&chain)).await;
        let mut process = CliProcess::spawn(
            Path::new(CLIENT),
            &args,
            directory.path().join("batch-epoch.log"),
            &[("--min-blocks", "10"), ("--max-batch-wait", "3600")],
        )?;
        // Only two blocks remain, including the fixed-cutoff switch witness.
        wait_checkpoint_before(&fixture, &mut process, switch_height, Duration::from_secs(15))
            .await?;
        ensure!(
            fixture.checkpoint().await? ==
                (switch_height, chain.headers[usize::try_from(switch_height)?].hash_slow()),
            "urgent checkpoint differs"
        );
        ensure!(
            fixture.anvil.provider.get_transaction_count(sender).await? == nonce + 3,
            "urgent flush consumed extra nonces"
        );
        ensure!(process.signal(libc::SIGTERM).await?.success(), "SIGTERM should exit cleanly");
        assert_key_absent(&process);
        Ok(())
    }
    .await;
    if result.is_err() {
        fixture.anvil.dump_logs();
    }
    result
}

/// Exercise the actual startup wiring without contracts, history or a pending forced skip.
/// Grouped with the CLI integration suite so the standard test entrypoint runs it.
#[tokio::test]
#[ignore = "docker"]
async fn lander_cli_checks_engine_before_opening_journal_or_running() -> Result<()> {
    use axum::http::StatusCode;
    use std::sync::atomic::Ordering;

    for (status, body, expected, retry) in [
        (
            StatusCode::UNAUTHORIZED,
            json!({"error": "upstream-private-token"}),
            "Engine transport failure",
            true,
        ),
        (
            StatusCode::OK,
            json!({"jsonrpc":"2.0", "error": {
                "code": -32601, "message": "upstream-private-token"
            }}),
            "engine_exchangeCapabilities error code -32601",
            false,
        ),
        (
            StatusCode::OK,
            json!({"jsonrpc":"2.0", "result": []}),
            "Engine/JWT configuration failure",
            false,
        ),
    ] {
        let rpc = FixtureRpc::start(RpcData {
            blocks: Vec::new(),
            headers: Vec::new(),
            committees: Default::default(),
        })
        .await?;
        *rpc.engine_reply.write().await = (status, body);
        let directory = TempDir::new()?;
        let key = directory.path().join("key.hex");
        let chain_config = directory.path().join("chain.toml");
        std::fs::write(&key, DEV_KEY.to_string())?;
        std::fs::write(key.with_file_name("jwt.hex"), "11".repeat(32))?;
        std::fs::write(&chain_config, "")?;
        let args = CliInputs {
            l1: rpc.url.clone(),
            rpc: rpc.url.clone(),
            key,
            chain_config,
            data: directory.path().join("lander"),
            max_blocks: 1,
        };
        let mut process =
            CliProcess::spawn(Path::new(CLIENT), &args, directory.path().join("startup.log"), &[])?;
        if retry {
            tokio::time::timeout(Duration::from_secs(5), async {
                while rpc.capability_calls.load(Ordering::Relaxed) < 2 {
                    process.assert_running()?;
                    tokio::time::sleep(Duration::from_millis(25)).await;
                }
                anyhow::Ok(())
            })
            .await
            .context("startup did not retry authenticated capability exchange")??;
            ensure!(
                process.signal(libc::SIGTERM).await?.success(),
                "startup retry must be cancellable"
            );
        } else {
            ensure!(!process.wait_exit().await?.success(), "invalid Engine API reached runner");
            ensure!(rpc.capability_calls.load(Ordering::Relaxed) == 1, "fatal setup error retried");
        }
        let output = process.output();
        ensure!(output.contains(expected), "missing startup diagnostic: {output}");
        ensure!(output.contains("l2.auth"), "missing authenticated endpoint flag: {output}");
        ensure!(!output.contains("upstream-private-token"), "upstream text was exposed");
        ensure!(
            !output.contains("running the permissionless Etna lander"),
            "runner started without Engine"
        );
        ensure!(!args.data.exists(), "startup failure opened the journal");
        assert_key_absent(&process);
    }
    Ok(())
}
