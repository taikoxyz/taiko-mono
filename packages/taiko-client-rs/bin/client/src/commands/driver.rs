//! Driver subcommand.

use async_trait::async_trait;
use clap::Parser;
use driver::{Driver, DriverConfig, metrics::DriverMetrics};

use crate::{
    commands::{Subcommand, build_driver_config},
    error::Result,
    flags::{common::CommonArgs, driver::DriverArgs},
};

/// Command-line interface for running the driver service.
#[derive(Parser, Clone, Debug)]
#[command(about = "Runs the driver software")]
pub struct DriverSubCommand {
    /// Common CLI arguments shared across all subcommands.
    #[command(flatten)]
    pub common_flags: CommonArgs,
    /// Driver-specific CLI arguments.
    #[command(flatten)]
    pub driver_flags: DriverArgs,
}

impl DriverSubCommand {
    /// Build driver configuration from command-line arguments.
    fn build_config(&self) -> Result<DriverConfig> {
        build_driver_config(&self.common_flags, &self.driver_flags)
    }

    /// Run the driver.
    pub async fn run(&self) -> Result<()> {
        <Self as Subcommand>::run(self).await
    }
}

#[async_trait]
impl Subcommand for DriverSubCommand {
    /// Return a reference to the common CLI arguments.
    fn common_args(&self) -> &CommonArgs {
        &self.common_flags
    }

    /// Register driver and indexer metrics.
    fn register_metrics(&self) -> Result<()> {
        DriverMetrics::init();
        Ok(())
    }

    /// Run the driver.
    async fn run(&self) -> Result<()> {
        self.init_logs()?;
        self.init_metrics()?;

        let cfg = self.build_config()?;
        Driver::new(cfg).await?.run().await.map_err(Into::into)
    }
}
