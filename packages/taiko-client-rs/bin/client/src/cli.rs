//! CLI command parser and runner.
//!
//! This module provides the main CLI structure and command dispatch logic.
//! It parses command-line arguments using `clap` and routes to the appropriate
//! subcommand handler (proposer, driver, or whitelist preconfirmation driver).

use std::future::Future;

use crate::error::Result;
use clap::{Parser, Subcommand};
use tokio::runtime::{Builder, Runtime};

use crate::commands::{
    driver::DriverSubCommand, proposer::ProposerSubCommand,
    whitelist_preconfirmation_driver::WhitelistPreconfirmationDriverSubCommand,
};

/// Subcommands for the CLI.
#[derive(Debug, Clone, Subcommand)]
pub enum Commands {
    /// Run the proposer.
    Proposer(Box<ProposerSubCommand>),
    /// Run the driver.
    Driver(Box<DriverSubCommand>),
    /// Run the whitelist preconfirmation driver with whitelist P2P protocol.
    WhitelistPreconfirmationDriver(Box<WhitelistPreconfirmationDriverSubCommand>),
}

#[derive(Parser, Clone, Debug)]
#[command(author)]
/// Top-level CLI parser containing the selected subcommand.
pub struct Cli {
    /// The subcommand to run.
    #[command(subcommand)]
    pub subcommand: Commands,
}

impl Cli {
    /// Run the subcommand.
    pub fn run(self) -> Result<()> {
        match self.subcommand {
            Commands::Proposer(proposer_cmd) => Self::run_until_shutdown_signal(proposer_cmd.run()),
            Commands::Driver(driver_cmd) => Self::run_until_shutdown_signal(driver_cmd.run()),
            // The whitelist runner installs its own signal handling so it can drain its REST
            // server and sidecars before exiting; a second top-level handler would race it and
            // cancel that teardown.
            Commands::WhitelistPreconfirmationDriver(cmd) => Self::block_on(cmd.run()),
        }
    }

    /// Run the future until it completes or the process receives a shutdown signal
    /// (SIGINT/ctrl-c or SIGTERM).
    pub fn run_until_shutdown_signal<F>(fut: F) -> Result<()>
    where
        F: Future<Output = Result<()>>,
    {
        Self::block_on(async {
            tokio::select! {
                res = fut => res,
                _ = driver::shutdown::shutdown_signal() => Ok(()),
            }
        })
    }

    /// Drive the future to completion on a fresh multi-thread runtime.
    pub fn block_on<F>(fut: F) -> Result<()>
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
