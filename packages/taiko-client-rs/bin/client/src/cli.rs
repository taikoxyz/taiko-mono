use std::io::Error;

use anyhow::Result;
use clap::{Parser, Subcommand};
use tokio::runtime::Runtime;

use crate::commands::proposer::ProposerSubCommand;

/// Subcommands for the CLI.
#[derive(Debug, Clone, Subcommand)]
pub enum Commands {
    /// Runs the consensus node.
    #[command(alias = "proposer")]
    Proposer(ProposerSubCommand),
}

#[derive(Parser, Clone, Debug)]
#[command(author)]
pub struct Cli {
    #[command(subcommand)]
    pub subcommand: Commands,
}

impl Cli {
    pub fn run(self) -> Result<()> {
        match self.subcommand {
            Commands::Proposer(_proposer_cmd) => Ok(()),
        }
    }

    pub fn run_until_ctrl_c<F>(fut: F) -> Result<()>
    where
        F: std::future::Future<Output = Result<()>>,
    {
        Self::tokio_runtime().map_err(|e| anyhow::anyhow!(e))?.block_on(fut)
    }

    pub fn tokio_runtime() -> Result<Runtime, Error> {
        tokio::runtime::Builder::new_multi_thread().enable_all().build()
    }
}
