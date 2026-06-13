//! Prover Subcommand.

use std::time::Duration;

use async_trait::async_trait;
use clap::Parser;
use protocol::shasta::set_devnet_unzen_override;
use prover::{config::ProverConfigs, metrics::ProverMetrics, prover::Prover};

use crate::{
    commands::Subcommand,
    error::{CliError, Result},
    flags::{common::CommonArgs, prover::ProverArgs},
};

/// Command-line interface for running a prover.
#[derive(Parser, Clone, Debug)]
#[command(about = "Runs the prover software")]
pub struct ProverSubCommand {
    /// Common CLI arguments.
    #[command(flatten)]
    pub common_flags: CommonArgs,
    /// Prover-specific CLI arguments.
    #[command(flatten)]
    pub prover_flags: ProverArgs,
}

impl ProverSubCommand {
    /// Build prover configuration from command-line arguments.
    fn build_config(&self) -> Result<ProverConfigs> {
        let l1_provider_source = self.common_flags.l1_provider_source()?;
        let prover = &self.prover_flags;

        let raiko_api_key = match &prover.raiko_api_key_path {
            Some(path) => {
                let contents = std::fs::read_to_string(path).map_err(|err| {
                    CliError::Config(format!("failed to read raiko API key file: {err}"))
                })?;
                Some(contents.trim().to_owned())
            }
            None => None,
        };

        Ok(ProverConfigs {
            l1_provider_source,
            l2_provider_url: self.common_flags.l2_http_endpoint.clone(),
            l2_auth_provider_url: self.common_flags.l2_auth_endpoint.clone(),
            jwt_secret: self.common_flags.l2_auth_jwt_secret.clone(),
            inbox_address: self.common_flags.shasta_inbox_address,
            l1_prover_private_key: prover.l1_prover_private_key,
            raiko_host: prover.raiko_host.clone(),
            raiko_zkvm_host: prover.raiko_zkvm_host.clone(),
            raiko_api_key,
            raiko_request_timeout: Duration::from_secs(prover.raiko_request_timeout_secs),
            starting_proposal_id: prover.starting_proposal_id,
            prove_unassigned_proposals: prover.prove_unassigned_proposals,
            proposal_window_size: prover.proposal_window_size,
            dummy: prover.dummy,
            proof_polling_interval: Duration::from_secs(prover.proof_polling_interval_secs),
            local_proposer_addresses: prover.local_proposer_addresses.clone(),
            block_confirmations: prover.block_confirmations,
            force_batch_proving_interval: Duration::from_secs(
                prover.force_batch_proving_interval_secs,
            ),
            sgx_batch_size: prover.sgx_batch_size,
            zkvm_batch_size: prover.zkvm_batch_size,
            shadow_mode: prover.shadow_mode,
            gas_limit: prover.gas_limit,
            retry_interval: Duration::from_secs(prover.retry_interval_secs),
            confirmation_timeout: Duration::from_secs(prover.confirmation_timeout_secs),
            receipt_query_interval: None,
            min_tip_cap_gwei: prover.min_tip_cap_gwei,
            min_base_fee_gwei: prover.min_base_fee_gwei,
            backoff_retry_interval: Duration::from_secs(prover.backoff_retry_interval_secs),
            backoff_max_retries: prover.backoff_max_retries,
        })
    }

    /// Run the prover software.
    pub async fn run(&self) -> Result<()> {
        <Self as Subcommand>::run(self).await
    }
}

#[async_trait]
impl Subcommand for ProverSubCommand {
    /// Return a reference to the common CLI arguments.
    fn common_args(&self) -> &CommonArgs {
        &self.common_flags
    }

    /// Register prover metrics before runtime startup.
    fn register_metrics(&self) -> Result<()> {
        ProverMetrics::init();
        Ok(())
    }

    /// Execute the prover subcommand flow.
    async fn run(&self) -> Result<()> {
        self.init_logs()?;
        set_devnet_unzen_override(self.common_flags.devnet_unzen_timestamp);
        self.init_metrics()?;

        let cfg = self.build_config()?;

        Prover::new(cfg).await?.start().await.map_err(Into::into)
    }
}
