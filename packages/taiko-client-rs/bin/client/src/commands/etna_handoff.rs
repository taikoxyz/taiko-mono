//! Stage the complete Unzen driver before serving Etna ABCI on the same execution chain.

use std::{fs::File, io::Write, path::PathBuf, time::Duration};

use abci::{AbciMetrics, L1Source, RpcL1Source, SwitchOrigin, build_genesis, l1::layout::inbox};
use alloy_primitives::U256;
use clap::Parser;
use driver::{Driver, metrics::DriverMetrics};
use rpc::client::{DEFAULT_HTTP_TIMEOUT, connect_http_with_timeout};
use tracing::{info, warn};

use super::{
    abci::{AbciSubCommand, l2_chain_id},
    bind_l1_chain_id,
    driver::{UnzenArgs, build_config},
    engine_lease, init_logs, init_metrics, load_chain_params, rpc_chain_id,
};
use crate::{
    error::{CliError, Result},
    flags::{abci::AbciArgs, common::CommonArgs, driver::DriverArgs},
};

/// Synchronize to the final Unzen block and start Etna without releasing Engine ownership.
#[derive(Parser, Clone, Debug)]
#[command(about = "Derives the finalized Unzen end, writes fixed Etna genesis, then serves ABCI")]
pub struct EtnaHandoffSubCommand {
    /// Own L1/EL endpoints and the shared Engine control directory.
    #[command(flatten)]
    pub common_flags: CommonArgs,
    /// Pre-fork synchronization and blob acquisition settings.
    #[command(flatten)]
    pub driver_flags: DriverArgs,
    /// Existing Unzen Inbox and optional devnet Unzen activation override.
    #[command(flatten)]
    pub unzen_flags: UnzenArgs,
    /// Etna state, listening address, beneficiary and deployment configuration.
    #[command(flatten)]
    pub abci_flags: AbciArgs,
    /// Fixed CometBFT genesis destination; an existing differing genesis is never replaced.
    #[clap(long = "genesis-out", env = "ETNA_GENESIS_OUT", required = true)]
    pub genesis_out: PathBuf,
}

impl EtnaHandoffSubCommand {
    /// Hold the Engine lease across both stages, retaining signer state and fixed genesis.
    pub async fn run(&self) -> Result<()> {
        let common = &self.common_flags;
        init_logs(&common.observability)?;
        DriverMetrics::init();
        AbciMetrics::init();
        init_metrics(&common.observability)?;
        let _engine = engine_lease(common)?;
        let chain_id = l2_chain_id(&common.l2_http_endpoint).await?;
        let (mut params, expected_l1) =
            load_chain_params(chain_id, self.abci_flags.chain_config.as_deref())?;
        bind_l1_chain_id(
            &mut params,
            expected_l1,
            rpc_chain_id(&common.l1_http_endpoint, "l1.http").await?,
        )?;
        let switch = params.switch.as_ref().ok_or_else(|| {
            CliError::Handoff(
                "etna-handoff requires the chain's switching deployment configuration".into(),
            )
        })?;
        if switch.unzen_inbox != self.unzen_flags.inbox {
            return Err(CliError::Handoff(
                "driver Inbox differs from the configured Unzen Inbox".into(),
            ));
        }
        protocol::shasta::set_devnet_unzen_override(self.unzen_flags.devnet_unzen_timestamp);
        let driver =
            Driver::new(build_config(common, &self.driver_flags, &self.unzen_flags)).await?;
        let derived = driver
            .run_until_etna(
                switch.fork_timestamp,
                common.engine_control_dir.join("unzen-origin.json"),
            )
            .await?;
        let origin = SwitchOrigin {
            l1_number: derived.finalized_l1_number,
            l1_hash: derived.finalized_l1_hash,
            height: derived.height,
            hash: derived.hash,
        };
        // run_until_etna returns only between completed batches, with no detached Engine writers.
        drop(driver);
        info!(height = origin.height, hash = %origin.hash, "Unzen derivation drained; waiting for the finalized Etna start write");
        let l1 = RpcL1Source::new(connect_http_with_timeout(
            common.l1_http_endpoint.clone(),
            DEFAULT_HTTP_TIMEOUT,
        ));
        let genesis = loop {
            let attempt: std::result::Result<Option<abci::GenesisDoc>, abci::GenesisError> =
                async {
                    let finalized = l1.finalized_number().await?;
                    let start_hash = l1
                        .storage_at(params.inbox, inbox::slot(inbox::START_BLOCK_HASH), finalized)
                        .await?;
                    if start_hash == U256::ZERO {
                        return Ok(None);
                    }
                    build_genesis(&l1, &params).await.map(Some)
                }
                .await;
            match attempt {
                Ok(Some(genesis)) => break genesis,
                Ok(None) => {}
                Err(error) if retryable_genesis(&error) => {
                    warn!(%error, "Etna start inputs unavailable; retaining Engine ownership and retrying");
                }
                Err(error) => return Err(error.into()),
            }
            tokio::time::sleep(Duration::from_secs(4)).await;
        };
        if genesis.initial_height != (origin.height + 1).to_string() ||
            genesis.app_hash.to_lowercase() != alloy_primitives::hex::encode(origin.hash)
        {
            return Err(CliError::Handoff(
                "finalized Etna start differs from the driver-derived Unzen end".into(),
            ));
        }
        self.install_genesis(&genesis.to_json_pretty())?;
        info!(height = origin.height + 1, path = %self.genesis_out.display(), "fixed Etna genesis ready; serving ABCI");
        AbciSubCommand { common_flags: common.clone(), abci_flags: self.abci_flags.clone() }
            .serve_app(Some(origin))
            .await
    }

    /// Publish the fixed genesis atomically, or accept an identical already-installed document.
    fn install_genesis(&self, json: &str) -> Result<()> {
        let expected: serde_json::Value = serde_json::from_str(json)
            .map_err(|_| CliError::Handoff("generated genesis is not valid JSON".into()))?;
        if self.genesis_out.exists() {
            let current = std::fs::read(&self.genesis_out)?;
            let actual: serde_json::Value = serde_json::from_slice(&current)
                .map_err(|_| CliError::Handoff("existing genesis is not valid JSON".into()))?;
            if actual != expected {
                return Err(CliError::Handoff(
                    "existing genesis differs; fixed genesis is never overwritten".into(),
                ));
            }
            return Ok(());
        }
        let parent = self
            .genesis_out
            .parent()
            .filter(|p| !p.as_os_str().is_empty())
            .unwrap_or_else(|| std::path::Path::new("."));
        std::fs::create_dir_all(parent)?;
        let mut stage = tempfile::NamedTempFile::new_in(parent)?;
        stage.write_all(json.as_bytes())?;
        stage.write_all(b"\n")?;
        stage.as_file().sync_all()?;
        stage.persist_noclobber(&self.genesis_out).map_err(|e| CliError::Runtime(e.error))?;
        File::open(parent)?.sync_all()?;
        Ok(())
    }
}

/// Missing own-L1 inputs remain pending; authenticated contradictions stop the handoff.
fn retryable_genesis(error: &abci::GenesisError) -> bool {
    match error {
        abci::GenesisError::L1(error) => !error.is_integrity_failure(),
        abci::GenesisError::InitializationNotFinal { .. } => true,
        abci::GenesisError::Fetch(error) => match error.as_ref() {
            abci::l1::FetchError::L1(error) => !error.is_integrity_failure(),
            abci::l1::FetchError::Timeout(_) => true,
            _ => false,
        },
        _ => false,
    }
}
