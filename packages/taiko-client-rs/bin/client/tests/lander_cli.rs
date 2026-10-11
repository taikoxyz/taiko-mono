//! Execute the actual lander command against pinned deployed contracts and genuine certificates.

#[path = "../../../crates/lander/tests/support/mod.rs"]
mod contracts_support;
mod support {
    pub mod lander;
}

use std::{path::Path, time::Duration};

use alloy_primitives::U256;
use alloy_provider::Provider;
use anyhow::{Result, ensure};
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
    std::fs::write(
        &chain_config,
        format!(
            "inbox = \"{}\"\nregistry = \"{}\"\nd_max = 5\nmargin_v = 0\n",
            fixture.inbox, fixture.registry,
        ),
    )?;
    Ok(CliInputs {
        l1: fixture.anvil.http.clone(),
        rpc: rpc.url.clone(),
        key,
        data: root.path().join("lander"),
        chain_config,
    })
}

async fn wait_checkpoint(
    fixture: &ContractFixture,
    process: &mut CliProcess,
    height: u64,
) -> Result<()> {
    tokio::time::timeout(Duration::from_secs(90), async {
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
        chain.extend(&fixture, 10).await?;
        rpc.replace(rpc_data(&chain)).await;
        let mut second =
            CliProcess::spawn(Path::new(CLIENT), &args, directory.path().join("second.log"), &[])?;
        wait_checkpoint(&fixture, &mut second, 10).await?;
        ensure!(
            fixture.checkpoint().await? == (10, chain.headers[10].hash_slow()),
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
        chain.extend(&fixture, 10).await?;
        rpc.replace(rpc_data(&chain)).await;
        wait_checkpoint(&fixture, &mut second, 10).await?;
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
