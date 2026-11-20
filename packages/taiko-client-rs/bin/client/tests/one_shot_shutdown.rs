use std::{fs::Permissions, os::unix::fs::PermissionsExt, process::Stdio, time::Duration};

use anyhow::{Context, Result, ensure};
use tokio::{io::AsyncReadExt, net::TcpListener};

/// A cancelled output-producing command must not look like a successful empty report.
#[tokio::test]
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

/// `lander --land-to` exits 0 only once its landing is confirmed, so a signal before that is a
/// failure; without it the lander is a service, and a signal stops it cleanly.
#[tokio::test]
async fn interrupted_exact_lander_exits_unsuccessfully() -> Result<()> {
    let files = tempfile::tempdir()?;
    let key = files.path().join("lander.key");
    std::fs::write(&key, format!("0x{}", "11".repeat(32)))?;
    let jwt = files.path().join("jwt.hex");
    std::fs::write(&jwt, "22".repeat(32))?;
    for land_to in [Some("12"), None] {
        // The journal lease lives beside the data directory, in a parent only its owner writes.
        let root = tempfile::Builder::new().permissions(Permissions::from_mode(0o700)).tempdir()?;
        let data = root.path().join("lander");
        let listener = TcpListener::bind("127.0.0.1:0").await?;
        let endpoint = format!("http://{}", listener.local_addr()?);
        let endpoint = endpoint.as_str();
        let mut process = tokio::process::Command::new(env!("CARGO_BIN_EXE_taiko-client"));
        process.env("METRICS_ENABLED", "false").arg("lander");
        for (flag, value) in [
            ("--l1.http", endpoint),
            ("--l2.http", endpoint),
            ("--l2.auth", endpoint),
            ("--comet.http", endpoint),
            ("--jwt.secret", jwt.to_str().context("jwt path")?),
            ("--signing-key", key.to_str().context("key path")?),
            ("--data-dir", data.to_str().context("data path")?),
            ("--max-blocks", "6"),
            ("--max-fee-per-gas", "1"),
            ("--max-priority-fee-per-gas", "1"),
            ("--max-fee-per-blob-gas", "1"),
            ("--sidecar", "eip7594"),
        ] {
            process.args([flag, value]);
        }
        if let Some(height) = land_to {
            process.args(["--land-to", height]);
        }
        let mut child =
            process.stdout(Stdio::piped()).stderr(Stdio::piped()).kill_on_drop(true).spawn()?;
        let Ok(accepted) = tokio::time::timeout(Duration::from_secs(10), listener.accept()).await
        else {
            child.start_kill()?;
            let output = child.wait_with_output().await?;
            anyhow::bail!(
                "the lander never reached its first RPC: {}{}",
                String::from_utf8_lossy(&output.stdout),
                String::from_utf8_lossy(&output.stderr)
            );
        };
        let (mut connection, _) = accepted?;
        let mut request = [0u8; 4096];
        ensure!(connection.read(&mut request).await? > 0, "lander should be waiting on RPC");
        let sent = tokio::process::Command::new("kill")
            .args(["-TERM", &child.id().context("live child pid")?.to_string()])
            .status()
            .await?;
        ensure!(sent.success(), "shutdown signal should be delivered");
        let output =
            tokio::time::timeout(Duration::from_secs(15), child.wait_with_output()).await??;
        let stderr = String::from_utf8_lossy(&output.stderr);
        ensure!(
            output.status.success() == land_to.is_none(),
            "--land-to {land_to:?} exited {} after SIGTERM: {stderr}",
            output.status
        );
        ensure!(land_to.is_none() || stderr.contains("interrupted"), "{stderr}");
    }
    Ok(())
}
