#![cfg(unix)]

use std::{process::Stdio, time::Duration};

use anyhow::{Context, Result, ensure};
use tokio::{io::AsyncReadExt, net::TcpListener};

/// A cancelled output-producing command must not look like a successful empty report.
#[tokio::test]
#[ignore = "integration"]
async fn interrupted_one_shot_commands_exit_unsuccessfully() -> Result<()> {
    for command in ["abci-genesis", "abci-committee-record"] {
        for signal in ["-INT", "-TERM"] {
            let listener = TcpListener::bind("127.0.0.1:0").await?;
            let endpoint = format!("http://{}", listener.local_addr()?);
            let chain_id = protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID.to_string();
            let mut process = tokio::process::Command::new(env!("CARGO_BIN_EXE_taiko-client"));
            process.args([command, "--l1.http", &endpoint, "--l2.chain-id", &chain_id]);
            if command == "abci-committee-record" {
                process.args(["--genesis-cutoff", "1"]);
            }
            let child =
                process.stdout(Stdio::piped()).stderr(Stdio::piped()).kill_on_drop(true).spawn()?;
            let (mut connection, _) =
                tokio::time::timeout(Duration::from_secs(10), listener.accept()).await??;
            let mut request = [0u8; 4096];
            ensure!(connection.read(&mut request).await? > 0, "command should be waiting on RPC");
            let sent = tokio::process::Command::new("kill")
                .args([signal, &child.id().context("live child pid")?.to_string()])
                .status()
                .await?;
            ensure!(sent.success(), "shutdown signal should be delivered");
            let output =
                tokio::time::timeout(Duration::from_secs(15), child.wait_with_output()).await??;
            ensure!(!output.status.success(), "{command} returned success after {signal}");
            ensure!(
                output.stdout.is_empty(),
                "interrupted command should not emit a completed report"
            );
            ensure!(
                String::from_utf8_lossy(&output.stderr).contains("interrupted"),
                "stderr should explain interruption"
            );
        }
    }
    Ok(())
}
