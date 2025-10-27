//! Shared test utilities for Taiko workspace integration tests.

use std::sync::OnceLock;

use tracing_subscriber::EnvFilter;

mod blob_server;
mod shasta_env;

pub use blob_server::BlobServer;
pub use shasta_env::{ShastaEnv, verify_anchor_block, wait_for_new_proposal};

/// Initialise tracing for tests using a single global subscriber.
///
/// The `default_filter` is used when the `RUST_LOG` environment variable is not set.
pub fn init_tracing(default_filter: &str) {
    static INIT: OnceLock<()> = OnceLock::new();

    INIT.get_or_init(|| {
        let env_filter =
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new(default_filter));
        let _ = tracing_subscriber::fmt().with_env_filter(env_filter).try_init();
    });
}
