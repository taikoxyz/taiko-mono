//! CLI command parser and runner.

use std::{future::Future, io::Error};

use anyhow::{Result, anyhow};
use clap::{Parser, Subcommand};
use tokio::runtime::{Builder, Runtime};

use crate::commands::{
    driver::DriverSubCommand, preconfirmation_driver::PreconfirmationDriverSubCommand,
    proposer::ProposerSubCommand,
};

/// Subcommands for the CLI.
#[derive(Debug, Clone, Subcommand)]
pub enum Commands {
    /// Run the proposer.
    Proposer(Box<ProposerSubCommand>),
    /// Run the driver.
    Driver(Box<DriverSubCommand>),
    /// Run the preconfirmation driver with P2P client.
    PreconfirmationDriver(Box<PreconfirmationDriverSubCommand>),
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
            Commands::PreconfirmationDriver(cmd) => Self::run_until_ctrl_c(cmd.run()),
        }
    }

    /// Run until ctrl-c is pressed.
    pub fn run_until_ctrl_c<F>(fut: F) -> Result<()>
    where
        F: Future<Output = Result<()>>,
    {
        Self::tokio_runtime().map_err(|e| anyhow!(e))?.block_on(fut)
    }

    /// Create a new default tokio multi-thread runtime.
    pub fn tokio_runtime() -> Result<Runtime, Error> {
        Builder::new_multi_thread().enable_all().build()
    }
}
