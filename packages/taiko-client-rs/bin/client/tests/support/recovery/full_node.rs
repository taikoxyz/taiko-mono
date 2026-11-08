//! Delayed recovered full node with an independent EL imported through the normal Engine API.
use super::{Commands, Liveness, write_private};
use crate::contracts_support::ContractFixture;
use abci::{Engine, PayloadVerdict, envelope::ExecutionBlock};
use anyhow::{Context, Result};
use serde_json::Value;
use std::{fs, net::TcpListener};
use test_harness::{CmtClient, ContractConsensus, StandaloneReth};

fn port() -> Result<u16> {
    Ok(TcpListener::bind("127.0.0.1:0")?.local_addr()?.port())
}

pub async fn join_after_landing(
    f: &ContractFixture,
    c: &ContractConsensus,
    old_blocks: &[ExecutionBlock],
) -> Result<()> {
    let el = StandaloneReth::start().await?;
    let engine = el.engine()?;
    // Import only the usable c prefix, without manufacturing any app/Comet state. The delayed
    // node must genuinely replay recovered blocks to its independently finalized checkpoint.
    for block in old_blocks {
        assert_eq!(engine.new_payload(block).await?, PayloadVerdict::Valid);
        let hash = block.header.hash_slow();
        assert_eq!(engine.forkchoice(hash, hash, hash).await?, PayloadVerdict::Valid);
    }
    let mut commands = Commands::new(f, c)?;
    // The full node's own stock template: no signer, the validator as its persistent peer.
    let template = commands.dir.path().join("full-node-template");
    fs::create_dir_all(template.join("config"))?;
    write_private(
        &template.join("config/node_key.json"),
        serde_json::to_vec(&test_harness::node_keys(2)[1].node_key_json())?,
    )?;
    let mut config: toml::Table =
        toml::from_str(&fs::read_to_string(c.comet_home(0).join("config/config.toml"))?)?;
    config.insert("proxy_app".into(), format!("tcp://127.0.0.1:{}", port()?).into());
    config.insert("priv_validator_laddr".into(), "".into());
    let rpc = port()?;
    config
        .get_mut("rpc")
        .unwrap()
        .as_table_mut()
        .unwrap()
        .insert("laddr".into(), format!("tcp://127.0.0.1:{rpc}").into());
    let status = c.cmt.call("status", &[]).await?;
    let peer = format!(
        "{}@{}",
        status["node_info"]["id"].as_str().context("validator node ID")?,
        status["node_info"]["listen_addr"]
            .as_str()
            .context("validator P2P address")?
            .trim_start_matches("tcp://")
    );
    let p2p = config.get_mut("p2p").unwrap().as_table_mut().unwrap();
    p2p.insert("laddr".into(), format!("tcp://127.0.0.1:{}", port()?).into());
    p2p.insert("persistent_peers".into(), peer.into());
    fs::write(template.join("config/config.toml"), toml::to_string(&config)?)?;
    commands.old_home = template.canonicalize()?;
    commands.signer = None;
    commands.lander = false;
    commands.l2_http = el.http.clone();
    commands.l2_auth = el.auth.clone();
    let result = async {
        // prepare reads the EL state at c from this node's own EL (SYNC-9-16).
        let plan = commands.prepare_command(1).await?;
        let installed = commands.install_command(&plan, "delayed-full-node").await?;
        let mut node = commands.start_recovered(&installed, "delayed-full-node").await?;
        let comet = CmtClient::new(format!("http://127.0.0.1:{rpc}").parse()?);
        super::wait_committed(&comet, 13, &mut node).await?;
        let status = tokio::time::timeout(std::time::Duration::from_secs(90), async {
            loop {
                node.running()?;
                if let Ok(status) = comet.abci_status().await &&
                    status.trust_phase == abci::app::trust::TrustPhase::Ready
                {
                    return Ok::<_, anyhow::Error>(status);
                }
                tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            }
        })
        .await??;
        assert_eq!(
            status.trust_phase,
            abci::app::trust::TrustPhase::Ready,
            "delayed full node must authenticate its own finalized target"
        );
        assert!(status.trust_target.as_ref().unwrap().height >= 12);
        assert_eq!(status.generation, 1);
        let dummy = installed.home.join("data/priv_validator_state.json");
        let hrs: Value = serde_json::from_slice(&fs::read(dummy)?)?;
        assert_eq!(hrs["height"], "0", "unregistered local dummy never signs");
        node.stop().await
    }
    .await;
    if result.is_err() {
        commands.diagnostics();
    }
    el.stop().await?;
    result
}
