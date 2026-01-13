//! Shared test utilities for Taiko workspace integration tests.

use std::sync::OnceLock;

use tracing_subscriber::EnvFilter;

mod blob_server;
mod helper;
pub mod shasta;

pub use blob_server::BlobServer;
pub use helper::{evm_mine, mine_l1_block};
pub use shasta::{env::ShastaEnv, helpers::verify_anchor_block};

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
