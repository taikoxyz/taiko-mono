#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
#![cfg_attr(test, allow(missing_docs, clippy::missing_docs_in_private_items))]
//! Binary for running Taiko client services.

pub mod cli;
pub mod commands;
pub mod error;
pub mod flags;
pub mod metrics;

fn main() {
    use clap::Parser;

    // Enable backtraces unless a RUST_BACKTRACE value has already been explicitly provided.
    if std::env::var_os("RUST_BACKTRACE").is_none() {
        unsafe { std::env::set_var("RUST_BACKTRACE", "1") };
    }

    // Run the subcommand. Print the message chain, not `Debug`: the messages carry the
    // operator hints.
    #[expect(
        unreachable_code,
        reason = "`Commands` has no variants yet, so `Cli` is uninhabited and clap exits from \
                  `parse` with a usage error"
    )]
    if let Err(err) = cli::Cli::parse().run() {
        eprintln!("Error: {}", err.report());
        std::process::exit(1);
    }
}
