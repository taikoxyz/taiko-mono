//! CLI command parser and runner.
//!
//! This module provides the main CLI structure and command dispatch logic.
//! It parses command-line arguments using `clap` and routes to the appropriate
//! subcommand handler (proposer, driver, or preconfirmation driver).

use std::future::Future;

use crate::error::Result;
use clap::{Parser, Subcommand};
use tokio::runtime::{Builder, Runtime};

use crate::commands::{
    driver::DriverSubCommand, preconfirmation_driver::PreconfirmationDriverSubCommand,
    proposer::ProposerSubCommand,
    whitelist_preconfirmation_driver::WhitelistPreconfirmationDriverSubCommand,
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
    /// Run the whitelist preconfirmation driver with whitelist P2P protocol.
    WhitelistPreconfirmationDriver(Box<WhitelistPreconfirmationDriverSubCommand>),
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
            Commands::WhitelistPreconfirmationDriver(cmd) => Self::run_until_ctrl_c(cmd.run()),
        }
    }

    /// Run until ctrl-c is pressed.
    pub fn run_until_ctrl_c<F>(fut: F) -> Result<()>
    where
        F: Future<Output = Result<()>>,
    {
        Self::tokio_runtime()?.block_on(fut)
    }

    /// Create a new default tokio multi-thread runtime.
    ///
    /// This creates a multi-threaded runtime with all features enabled,
    /// suitable for running async subcommands.
    pub fn tokio_runtime() -> Result<Runtime> {
        Ok(Builder::new_multi_thread().enable_all().build()?)
    }
}
