//! CLI command parser and runner.
//!
//! This module provides the main CLI structure and command dispatch logic.
//! It parses command-line arguments using `clap` and routes to the appropriate
//! subcommand handler (proposer, driver, or whitelist preconfirmation driver), which then runs
//! until it finishes or the process receives SIGINT or SIGTERM.

use std::{future::Future, time::Duration};

use crate::error::{CliError, Result};
use clap::{Parser, Subcommand};
use tokio::runtime::{Builder, Runtime};
use tracing::info;

use crate::commands::{
    driver::DriverSubCommand, proposer::ProposerSubCommand,
    whitelist_preconfirmation_driver::WhitelistPreconfirmationDriverSubCommand,
};

/// Upper bound on how long runtime shutdown waits for in-flight tasks after the subcommand has
/// returned or been stopped by a shutdown signal, so a stuck task cannot keep the process alive.
const RUNTIME_SHUTDOWN_TIMEOUT: Duration = Duration::from_secs(10);

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
            Commands::Proposer(proposer_cmd) => Self::run_until_shutdown(proposer_cmd.run()),
            Commands::Driver(driver_cmd) => Self::run_until_shutdown(driver_cmd.run()),
            Commands::WhitelistPreconfirmationDriver(cmd) => Self::run_until_shutdown(cmd.run()),
        }
    }

    /// Run `fut` on a new runtime until it finishes or the process receives SIGINT or SIGTERM.
    ///
    /// A shutdown signal drops `fut` and returns `Ok(())`, so the process exits with status 0.
    /// Handling SIGTERM matters in containers: the client runs as PID 1 there, and the kernel
    /// discards any signal PID 1 has no handler for, so `docker stop` or a pod deletion would
    /// otherwise only take effect with the SIGKILL at the end of the grace period.
    ///
    /// If the signal handlers cannot be installed, this returns [`CliError::SignalHandler`]
    /// without running `fut`: a client that cannot be stopped is worse than one that refuses
    /// to start.
    pub fn run_until_shutdown<F>(fut: F) -> Result<()>
    where
        F: Future<Output = Result<()>>,
    {
        let runtime = Self::tokio_runtime()?;
        let result = runtime.block_on(run_until_signal(fut, shutdown_signal()));
        runtime.shutdown_timeout(RUNTIME_SHUTDOWN_TIMEOUT);
        result
    }

    /// Create a new default tokio multi-thread runtime.
    ///
    /// This creates a multi-threaded runtime with all features enabled,
    /// suitable for running async subcommands.
    pub fn tokio_runtime() -> Result<Runtime> {
        Ok(Builder::new_multi_thread().enable_all().build()?)
    }
}

/// Drive `fut` to completion unless `shutdown` resolves first, in which case `fut` is dropped
/// and `Ok(())` is returned.
///
/// `shutdown` is polled before `fut` on every wake-up, so its signal handlers are installed
/// before the subcommand starts running. If `shutdown` fails instead, its error is returned
/// and `fut` is dropped; when that happens on the first wake-up, `fut` is never polled.
async fn run_until_signal<F, S>(fut: F, shutdown: S) -> Result<()>
where
    F: Future<Output = Result<()>>,
    S: Future<Output = Result<&'static str>>,
{
    tokio::select! {
        biased;
        signal = shutdown => {
            let signal = signal?;
            info!(signal, "received shutdown signal, stopping");
            Ok(())
        }
        result = fut => result,
    }
}

/// Resolve with the name of the first shutdown signal received: SIGINT, or SIGTERM on Unix.
///
/// Fails with [`CliError::SignalHandler`] if a handler cannot be installed. Tokio registers
/// handlers process-wide and never removes them, so a partially installed set must not be
/// left behind silently: the caller treats this error as fatal.
async fn shutdown_signal() -> Result<&'static str> {
    #[cfg(unix)]
    {
        use tokio::signal::unix::{SignalKind, signal};

        let mut sigterm = signal(SignalKind::terminate()).map_err(CliError::SignalHandler)?;
        tokio::select! {
            result = tokio::signal::ctrl_c() => {
                result.map(|()| "SIGINT").map_err(CliError::SignalHandler)
            }
            _ = sigterm.recv() => Ok("SIGTERM"),
        }
    }
    #[cfg(not(unix))]
    {
        tokio::signal::ctrl_c().await.map(|()| "SIGINT").map_err(CliError::SignalHandler)
    }
}

#[cfg(test)]
mod tests {
    use std::{
        future::pending,
        sync::{
            Arc,
            atomic::{AtomicBool, Ordering},
        },
    };

    use super::*;

    /// Sets its flag when dropped.
    struct SetOnDrop(Arc<AtomicBool>);

    impl Drop for SetOnDrop {
        fn drop(&mut self) {
            self.0.store(true, Ordering::SeqCst);
        }
    }

    #[tokio::test]
    async fn returns_subcommand_result_when_no_signal_arrives() {
        let result =
            run_until_signal(async { Err(CliError::InvalidL1EndpointConfig) }, pending()).await;

        assert!(matches!(result, Err(CliError::InvalidL1EndpointConfig)));
    }

    #[tokio::test]
    async fn shutdown_signal_stops_a_running_subcommand() {
        let started = Arc::new(AtomicBool::new(false));
        let dropped = Arc::new(AtomicBool::new(false));
        let subcommand = {
            let started = started.clone();
            let guard = SetOnDrop(dropped.clone());
            async move {
                let _guard = guard;
                started.store(true, Ordering::SeqCst);
                pending::<Result<()>>().await
            }
        };
        let shutdown = async {
            tokio::task::yield_now().await;
            Ok("SIGTERM")
        };

        let result = run_until_signal(subcommand, shutdown).await;

        assert!(result.is_ok());
        assert!(started.load(Ordering::SeqCst), "the subcommand should have been running");
        assert!(dropped.load(Ordering::SeqCst), "the stopped subcommand should be dropped");
    }

    #[tokio::test]
    async fn signal_handler_setup_failure_is_fatal_and_skips_the_subcommand() {
        let started = Arc::new(AtomicBool::new(false));
        let subcommand = {
            let started = started.clone();
            async move {
                started.store(true, Ordering::SeqCst);
                Ok(())
            }
        };
        let shutdown =
            async { Err(CliError::SignalHandler(std::io::Error::other("no signal driver"))) };

        let result = run_until_signal(subcommand, shutdown).await;

        assert!(matches!(result, Err(CliError::SignalHandler(_))));
        assert!(!started.load(Ordering::SeqCst), "the subcommand should never have been polled");
    }

    /// Set in the child process that `sigterm_resolves_shutdown_signal` re-executes itself in.
    #[cfg(unix)]
    const SIGNAL_TEST_CHILD_ENV: &str = "TAIKO_CLIENT_SIGNAL_TEST_CHILD";

    // Installing the shutdown handlers changes the process-wide SIGINT and SIGTERM dispositions
    // for good, because tokio never removes them. So the real-signal check runs in a child
    // process that re-executes this test alone, and the shared test binary keeps its default
    // dispositions: later signal tests and Ctrl+C on a stalled run keep working.
    #[cfg(unix)]
    #[tokio::test]
    async fn sigterm_resolves_shutdown_signal() {
        if std::env::var_os(SIGNAL_TEST_CHILD_ENV).is_some() {
            raise_sigterm_and_expect_shutdown().await;
            return;
        }

        let test_binary = std::env::current_exe().expect("the test binary path should be known");
        let output = tokio::process::Command::new(test_binary)
            .args(["--exact", "cli::tests::sigterm_resolves_shutdown_signal", "--nocapture"])
            .env(SIGNAL_TEST_CHILD_ENV, "1")
            .output()
            .await
            .expect("the child test process should spawn");
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);

        assert!(
            output.status.success(),
            "the child test failed with {}\nstdout:\n{stdout}\nstderr:\n{stderr}",
            output.status
        );
        // libtest exits 0 when a filter matches no test, so check that the child actually ran it.
        assert!(stdout.contains("1 passed"), "the child did not run the test\nstdout:\n{stdout}");
    }

    /// The child-process half of `sigterm_resolves_shutdown_signal`: install the handlers, raise
    /// a real SIGTERM against this process and expect the shutdown signal to resolve.
    #[cfg(unix)]
    async fn raise_sigterm_and_expect_shutdown() {
        let mut shutdown = Box::pin(shutdown_signal());
        // Poll once so the SIGTERM handler is installed before the signal is raised; without a
        // handler, the default action would terminate the test process.
        tokio::select! {
            biased;
            _ = &mut shutdown => panic!("shutdown resolved before any signal was sent"),
            _ = std::future::ready(()) => {}
        }

        // SAFETY: `raise` has no memory-safety preconditions, and a handler for SIGTERM is
        // installed, so the signal is delivered to it instead of terminating the process.
        assert_eq!(unsafe { libc::raise(libc::SIGTERM) }, 0);

        let signal = tokio::time::timeout(Duration::from_secs(5), shutdown)
            .await
            .expect("SIGTERM should resolve the shutdown signal")
            .expect("the shutdown signal handlers should install");
        assert_eq!(signal, "SIGTERM");
    }
}
