//! Delayed recovered full node with an independent EL imported through the normal Engine API.
use super::{Commands, process::Process, write_private};
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
    let commands = Commands::new(f, c)?;
    let home = commands.dir.path().join("full-node-template");
    fs::create_dir_all(home.join("config"))?;
    let app = commands.dir.path().join("original-full-node-app");
    fs::create_dir(&app)?;
    fs::copy(c.comet_home(0).join("config/genesis.json"), home.join("config/genesis.json"))?;
    write_private(
        &home.join("config/node_key.json"),
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
    config
        .get_mut("p2p")
        .unwrap()
        .as_table_mut()
        .unwrap()
        .insert("laddr".into(), format!("tcp://127.0.0.1:{}", port()?).into());
    fs::write(home.join("config/config.toml"), toml::to_string(&config)?)?;
    let status = c.cmt.call("status", &[]).await?;
    let peer = format!(
        "{}@{}",
        status["node_info"]["id"].as_str().context("validator node ID")?,
        status["node_info"]["listen_addr"]
            .as_str()
            .context("validator P2P address")?
            .trim_start_matches("tcp://")
    );
    let mut profile: toml::Table = toml::from_str(&fs::read_to_string(&commands.profile)?)?;
    profile.remove("signer");
    profile.remove("lander");
    profile.insert("role".into(), "full-node".into());
    profile.insert("app_data_dir".into(), app.to_string_lossy().to_string().into());
    profile.insert("comet_home".into(), home.to_string_lossy().to_string().into());
    profile.insert("l2_http".into(), el.http.to_string().into());
    profile.insert("l2_auth".into(), el.auth.to_string().into());
    profile.insert("peers".into(), vec![peer].into());
    write_private(&commands.profile, toml::to_string(&profile)?)?;
    let plan = commands.prepare_command(1).await?;
    let mut process: Process = commands.activate_command(&plan, "delayed-full-node")?;
    let comet = CmtClient::new(format!("http://127.0.0.1:{rpc}").parse()?);
    let result = async {
        super::wait_committed(&comet, 13, &mut process).await?;
        let status = tokio::time::timeout(std::time::Duration::from_secs(90), async {
            loop {
                process.running()?;
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
        let active: Value = serde_json::from_slice(&fs::read(commands.root.join("active.json"))?)?;
        let dummy = std::path::Path::new(active["installation"]["home"].as_str().unwrap())
            .join("data/priv_validator_state.json");
        let hrs: Value = serde_json::from_slice(&fs::read(dummy)?)?;
        assert_eq!(hrs["height"], "0", "unregistered local dummy never signs");
        process.stop().await?;
        Ok(())
    }
    .await;
    if result.is_err() {
        commands.diagnostics();
    }
    drop(process);
    el.stop().await?;
    result
}
