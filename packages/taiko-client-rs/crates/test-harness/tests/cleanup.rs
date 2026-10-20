#![cfg(unix)]

use std::time::Duration;

use alloy_provider::Provider;
use anyhow::{Context, Result, ensure};
use test_harness::StandaloneAnvil;

const CHILD_READY: &str = "TAIKO_HARNESS_CLEANUP_CHILD_READY";

/// Cancelling just the entrypoint must forward termination and run its label-scoped fallback.
#[tokio::test]
#[ignore = "integration"]
async fn entrypoint_sigterm_forwards_to_children_and_cleans_only_its_run() -> Result<()> {
    use std::os::unix::fs::PermissionsExt;

    let directory = tempfile::tempdir()?;
    let log = directory.path().join("docker-calls");
    let ready = directory.path().join("ready");
    let fake_docker = directory.path().join("docker");
    let fake_cargo = directory.path().join("cargo");
    std::fs::write(
        &fake_docker,
        r#"#!/bin/bash
printf '%s\n' "$*" >> "$DOCKER_CALLS"
if [[ "$1" == ps ]]; then echo owned-container; fi
if [[ "$1 $2" == 'network ls' ]]; then echo owned-network; fi
"#,
    )?;
    std::fs::write(&fake_cargo, "#!/bin/bash\ntouch \"$READY\"\nsleep 3\n")?;
    for path in [&fake_docker, &fake_cargo] {
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o755))?;
    }
    let path = format!("{}:{}", directory.path().display(), std::env::var("PATH")?);
    let mut child = tokio::process::Command::new("bash")
        .arg(concat!(env!("CARGO_MANIFEST_DIR"), "/../../tests/entrypoint.sh"))
        .env("PATH", path)
        .env("READY", &ready)
        .env("DOCKER_CALLS", &log)
        .env("TAIKO_CLIENT_RS_TEST_RUN", "cancelled-run")
        .env("PULL_POLICY", "missing")
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .kill_on_drop(true)
        .spawn()?;
    tokio::time::timeout(Duration::from_secs(5), async {
        while !ready.exists() {
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await?;
    let sent = tokio::process::Command::new("kill")
        .args(["-TERM", &child.id().context("live entrypoint pid")?.to_string()])
        .status()
        .await?;
    ensure!(sent.success(), "SIGTERM should be delivered");
    let status = tokio::time::timeout(Duration::from_secs(1), child.wait())
        .await
        .context("entrypoint did not promptly forward termination")??;
    ensure!(status.code() == Some(143), "entrypoint should report SIGTERM interruption");
    let calls = std::fs::read_to_string(log)?;
    ensure!(
        calls.contains("ps -aq --filter label=taiko-client-rs.test-run=cancelled-run"),
        "container selection must be scoped to this run"
    );
    ensure!(
        calls.contains("network ls -q --filter label=taiko-client-rs.test-run=cancelled-run"),
        "network selection must be scoped to this run"
    );
    ensure!(calls.contains("rm -f -v owned-container"), "owned container must be removed");
    ensure!(calls.contains("network rm owned-network"), "owned network must be removed");
    Ok(())
}

async fn docker(args: &[&str]) -> Result<String> {
    let output = tokio::process::Command::new("docker").args(args).output().await?;
    ensure!(output.status.success(), "docker failed: {}", String::from_utf8_lossy(&output.stderr));
    Ok(String::from_utf8(output.stdout)?.trim().to_owned())
}

/// External termination must remove this process's resources without touching a sibling devnet.
#[tokio::test]
#[ignore = "docker"]
async fn sigterm_removes_owned_resources_and_preserves_sibling_devnets() -> Result<()> {
    if let Some(path) = std::env::var_os(CHILD_READY) {
        let anvil = StandaloneAnvil::start().await?;
        std::fs::write(path, anvil.http.as_str())?;
        std::future::pending::<()>().await;
        return Ok(());
    }

    let sibling = StandaloneAnvil::start().await?;
    let directory = tempfile::tempdir()?;
    let ready = directory.path().join("ready");
    let mut child = tokio::process::Command::new(std::env::current_exe()?)
        .args([
            "--ignored",
            "--exact",
            "sigterm_removes_owned_resources_and_preserves_sibling_devnets",
            "--nocapture",
        ])
        .env(CHILD_READY, &ready)
        .kill_on_drop(true)
        .spawn()?;
    let endpoint = tokio::time::timeout(Duration::from_secs(120), async {
        loop {
            if let Ok(value) = std::fs::read_to_string(&ready) {
                break Ok::<_, anyhow::Error>(url::Url::parse(&value)?);
            }
            ensure!(child.try_wait()?.is_none(), "child exited before its devnet was ready");
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
    })
    .await
    .context("child devnet readiness timed out")??;
    let published = format!(":{}->8545/tcp", endpoint.port().context("published port")?);
    let listing = docker(&["ps", "-a", "--format", "{{.Names}} {{.Ports}}"]).await?;
    let container = listing
        .lines()
        .find(|line| line.contains(&published))
        .and_then(|line| line.split_whitespace().next())
        .context("child container should be visible")?
        .to_owned();
    ensure!(!container.is_empty(), "child container should be visible");
    let network = docker(&[
        "inspect",
        "--format",
        "{{range $name, $value := .NetworkSettings.Networks}}{{$name}}{{end}}",
        &container,
    ])
    .await?;
    ensure!(!network.is_empty(), "child network should be visible");
    let status = tokio::process::Command::new("kill")
        .args(["-TERM", &child.id().context("live child pid")?.to_string()])
        .status()
        .await?;
    ensure!(status.success(), "SIGTERM should be delivered");
    let status = tokio::time::timeout(Duration::from_secs(30), child.wait()).await??;
    ensure!(!status.success(), "an interrupted test must report failure");
    let remaining_container =
        docker(&["ps", "-aq", "--filter", &format!("name=^{container}$")]).await?;
    let remaining_network =
        docker(&["network", "ls", "-q", "--filter", &format!("name=^{network}$")]).await?;
    // Remove a failed reproduction's leftovers before reporting the assertion.
    if !remaining_container.is_empty() {
        let _ = docker(&["rm", "-f", "-v", &container]).await;
    }
    if !remaining_network.is_empty() {
        let _ = docker(&["network", "rm", &network]).await;
    }
    ensure!(remaining_container.is_empty(), "SIGTERM left the owned container behind");
    ensure!(remaining_network.is_empty(), "SIGTERM left the owned network behind");
    ensure!(sibling.provider.get_chain_id().await? == 31337, "sibling devnet must survive");
    sibling.stop().await?;
    Ok(())
}
