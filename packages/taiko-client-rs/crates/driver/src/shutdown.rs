//! Cooperative OS shutdown-signal handling shared by the client binaries and runners.
//!
//! Mirrors the Go client's signal trap (SIGINT/SIGTERM) so Kubernetes rollouts and operators
//! terminate the client cooperatively instead of killing it mid-operation.

use tracing::{error, info};

/// Resolve when the process receives a shutdown signal (SIGINT/ctrl-c or SIGTERM).
///
/// If a signal handler cannot be installed the corresponding branch parks forever, leaving the
/// default process disposition in place for that signal.
#[cfg(unix)]
pub async fn shutdown_signal() {
    use tokio::signal::unix::SignalKind;

    tokio::select! {
        _ = wait_for_signal(SignalKind::interrupt(), "SIGINT") => {}
        _ = wait_for_signal(SignalKind::terminate(), "SIGTERM") => {}
    }
}

/// Resolve when the process receives a ctrl-c on targets without unix signals.
#[cfg(not(unix))]
pub async fn shutdown_signal() {
    if let Err(err) = tokio::signal::ctrl_c().await {
        error!(?err, "failed to install ctrl-c handler");
        std::future::pending::<()>().await;
    }
    info!(signal = "ctrl-c", "received shutdown signal");
}

/// Wait for one occurrence of the given unix signal, logging when it arrives.
#[cfg(unix)]
async fn wait_for_signal(kind: tokio::signal::unix::SignalKind, label: &'static str) {
    match tokio::signal::unix::signal(kind) {
        Ok(mut stream) => {
            if stream.recv().await.is_some() {
                info!(signal = label, "received shutdown signal");
            } else {
                // The stream can no longer receive signals; park so the caller keeps running.
                std::future::pending::<()>().await;
            }
        }
        Err(err) => {
            error!(signal = label, ?err, "failed to install signal handler");
            std::future::pending::<()>().await;
        }
    }
}
