//! Proposer Subcommand.
use clap::Parser;

use crate::flags::{common::CommonArgs, proposer::ProposerArgs};

/// Command-line interface for running a proposer.
///
/// The `ProposerSubCommand` struct defines all the configuration options needed to start and run
/// a proposer software for Taiko protocol.
#[derive(Parser, Clone, Debug)]
#[command(about = "Runs the proposer software")]
pub struct ProposerSubCommand {
    /// Common CLI arguments.
    #[command(flatten)]
    pub common_flags: CommonArgs,
    #[command(flatten)]
    pub proposer_flags: ProposerArgs,
}

impl ProposerSubCommand {
    /// Returns a reference to the common CLI arguments.
    pub fn common_flags(&self) -> &CommonArgs {
        &self.common_flags
    }

    /// Returns a reference to the proposer-specific CLI arguments.
    pub fn proposer_flags(&self) -> &ProposerArgs {
        &self.proposer_flags
    }

    pub async fn run(&self) {}
}
