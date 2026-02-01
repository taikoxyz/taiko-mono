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

    // Run the subcommand.
    if let Err(err) = cli::Cli::parse().run() {
        eprintln!("Error: {err:?}");
        std::process::exit(1);
    }
}
