//! Initial EL publication must recover from occupied ports without moving recovery endpoints.

use std::net::{TcpListener, TcpStream};

use abci::Engine;
use alloy_provider::Provider;
use anyhow::{Context, Result, ensure};
use test_harness::StandaloneReth;

async fn docker(args: &[&str]) -> Result<String> {
    let output = tokio::process::Command::new("docker").args(args).output().await?;
    ensure!(output.status.success(), "docker failed: {}", String::from_utf8_lossy(&output.stderr));
    Ok(String::from_utf8(output.stdout)?.trim().to_owned())
}

fn free_port() -> Result<u16> {
    Ok(TcpListener::bind("127.0.0.1:0")?.local_addr()?.port())
}

/// A raced initial auth port must not prevent bootstrap or alter the eventual retained URLs.
#[tokio::test]
#[ignore = "docker"]
async fn occupied_initial_auth_port_recovers_and_preserves_restart_endpoints() -> Result<()> {
    let blocker = TcpListener::bind("127.0.0.1:0")?;
    let occupied = blocker.local_addr()?;
    let mut attempts = Vec::new();
    let el = StandaloneReth::start_with_ports(|| {
        let pair = (free_port()?, if attempts.is_empty() { occupied.port() } else { free_port()? });
        attempts.push(pair);
        Ok(pair)
    })
    .await?;
    ensure!(attempts.len() == 2, "occupied initial port should cause one fresh attempt");
    let http = el.http.clone();
    let auth = el.auth.clone();
    let container = el.docker_container().to_owned();
    let network = el.docker_network().to_owned();
    ensure!(http.port() == Some(attempts[1].0), "winning public port must be explicit");
    ensure!(auth.port() == Some(attempts[1].1), "winning auth port must be explicit");
    ensure!(http.port() != Some(occupied.port()) && auth.port() != Some(occupied.port()));
    ensure!(el.provider.get_chain_id().await? == 167001, "fresh EL must serve RPC");
    el.engine()?.check_capabilities().await?;
    el.genesis.verify(&el.provider).await?;
    let members = docker(&[
        "network",
        "inspect",
        "--format",
        "{{range .Containers}}{{.Name}} {{end}}",
        &network,
    ])
    .await?;
    ensure!(members == container, "only the winning container may remain on its network");
    let published = docker(&["port", &container]).await?;
    el.restart().await?;
    ensure!(el.http == http && el.auth == auth, "retained endpoints must survive restart");
    ensure!(
        docker(&["port", &container]).await? == published,
        "published ports must survive restart"
    );
    ensure!(
        el.provider.get_chain_id().await? == 167001,
        "original provider must work after restart"
    );
    el.engine()?.check_capabilities().await?;
    el.stop().await?;
    ensure!(docker(&["ps", "-aq", "--filter", &format!("name=^/{container}$")]).await?.is_empty());
    ensure!(
        docker(&["network", "ls", "-q", "--filter", &format!("name=^{network}$")])
            .await?
            .is_empty()
    );
    let stream =
        TcpStream::connect(occupied).context("owned cleanup must leave blocker untouched")?;
    let _accepted = blocker.accept()?;
    drop(stream);
    Ok(())
}
