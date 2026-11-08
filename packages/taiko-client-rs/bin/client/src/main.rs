#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
#![cfg_attr(test, allow(missing_docs, clippy::missing_docs_in_private_items))]
//! Binary for running Taiko client services.

pub mod cli;
pub mod commands;
pub mod error;
pub mod flags;
/// Offline landed checkpoint import.
pub mod import;
pub mod metrics;
pub mod recovery;

fn main() {
    use clap::Parser;

    // Enable backtraces unless a RUST_BACKTRACE value has already been explicitly provided.
    if std::env::var_os("RUST_BACKTRACE").is_none() {
        unsafe { std::env::set_var("RUST_BACKTRACE", "1") };
    }

    // Run the subcommand. Print the message chain, not `Debug`: the messages carry the
    // operator hints.
    if let Err(err) = cli::Cli::parse().run() {
        eprintln!("Error: {}", err.report());
        std::process::exit(
            if matches!(
                err,
                error::CliError::CheckpointImport(lander::checkpoint_import::ImportError::Safety(
                    _
                ))
            ) {
                2
            } else {
                1
            },
        );
    }
}
