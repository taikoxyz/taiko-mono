//! Unzen driver command and the shared configuration used before the Etna handoff.

use alloy_primitives::Address;
use clap::Parser;
use driver::{Driver, DriverConfig, metrics::DriverMetrics};
use protocol::shasta::set_devnet_unzen_override;
use rpc::{SubscriptionSource, client::ClientConfig};

use crate::{
    commands::{engine_lease, init_logs, init_metrics},
    error::Result,
    flags::{common::CommonArgs, driver::DriverArgs},
};

/// Deployment settings used only while deriving the pre-Etna chain.
#[derive(Parser, Clone, Debug)]
pub struct UnzenArgs {
    /// Existing L1 Unzen Inbox proxy whose proposal events the driver derives.
    #[clap(long = "shasta.inbox", env = "SHASTA_INBOX", required = true)]
    pub inbox: Address,
    /// Legacy devnet flag; the pinned Etna execution release supports Unzen timestamp zero only.
    #[clap(long = "devnet-unzen-timestamp", env = "DEVNET_UNZEN_TIMESTAMP", default_value_t = 0, value_parser = clap::value_parser!(u64).range(0..=0))]
    pub devnet_unzen_timestamp: u64,
}

/// Run the Unzen sync/derivation driver as an independent service.
#[derive(Parser, Clone, Debug)]
#[command(about = "Runs the Unzen driver for L1-derived execution history")]
pub struct DriverSubCommand {
    /// Own L1 and EL connections and observability.
    #[command(flatten)]
    pub common_flags: CommonArgs,
    /// Blob acquisition and synchronization options.
    #[command(flatten)]
    pub driver_flags: DriverArgs,
    /// Pre-Etna Inbox and fork configuration.
    #[command(flatten)]
    pub unzen_flags: UnzenArgs,
}

/// Create the restored driver's configuration without enabling preconfirmation ingress.
pub(super) fn build_config(
    common: &CommonArgs,
    flags: &DriverArgs,
    unzen: &UnzenArgs,
) -> DriverConfig {
    DriverConfig::new(
        ClientConfig {
            l1_provider_source: SubscriptionSource::Http(common.l1_http_endpoint.clone()),
            l2_provider_url: common.l2_http_endpoint.clone(),
            l2_auth_provider_url: common.l2_auth_endpoint.clone(),
            jwt_secret: common.l2_auth_jwt_secret.clone(),
            inbox_address: unzen.inbox,
        },
        flags.retry_interval(),
        flags.l1_beacon_endpoint.clone(),
        flags.l2_checkpoint_endpoint.clone(),
        flags.blob_server_endpoint.clone(),
        false,
    )
}

impl DriverSubCommand {
    /// Derive Unzen blocks while retaining exclusive local Engine ownership.
    pub async fn run(&self) -> Result<()> {
        init_logs(&self.common_flags.observability)?;
        DriverMetrics::init();
        init_metrics(&self.common_flags.observability)?;
        let _engine = engine_lease(&self.common_flags)?;
        set_devnet_unzen_override(self.unzen_flags.devnet_unzen_timestamp);
        let driver =
            Driver::new(build_config(&self.common_flags, &self.driver_flags, &self.unzen_flags))
                .await?;
        driver.run().await?;
        Ok(())
    }
}
