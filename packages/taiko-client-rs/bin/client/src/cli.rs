//! CLI command parser and runner.

use std::io::Error;

use anyhow::Result;
use clap::{Parser, Subcommand};
use tokio::runtime::Runtime;

use crate::commands::{driver::DriverSubCommand, proposer::ProposerSubCommand};

/// Subcommands for the CLI.
#[derive(Debug, Clone, Subcommand)]
pub enum Commands {
    /// Run the proposer.
    Proposer(Box<ProposerSubCommand>),
    /// Run the driver.
    Driver(Box<DriverSubCommand>),
}

#[derive(Parser, Clone, Debug)]
#[command(author)]
pub struct Cli {
    /// The subcommand to run.
    #[command(subcommand)]
    pub subcommand: Commands,
}

impl Cli {
    /// Run the subcommand.
    pub fn run(self) -> Result<()> {
        match self.subcommand {
            Commands::Proposer(proposer_cmd) => Self::run_until_ctrl_c(proposer_cmd.run()),
            Commands::Driver(driver_cmd) => Self::run_until_ctrl_c(driver_cmd.run()),
        }
    }

    /// Run until ctrl-c is pressed.
    pub fn run_until_ctrl_c<F>(fut: F) -> Result<()>
    where
        F: std::future::Future<Output = Result<()>>,
    {
        Self::tokio_runtime().map_err(|e| anyhow::anyhow!(e))?.block_on(fut)
    }

    /// Create a new default tokio multi-thread runtime.
    pub fn tokio_runtime() -> Result<Runtime, Error> {
        tokio::runtime::Builder::new_multi_thread().enable_all().build()
    }
}
