//! Shared test utilities for Taiko workspace integration tests.
//!
//! This crate provides common utilities used across multiple test crates:
//!
//! ## Core Utilities
//! - [`ShastaEnv`]: Test environment with L1/L2 providers and contract addresses.
//! - [`BeaconStubServer`]: A stub beacon server for tests.

use std::sync::OnceLock;

use tracing_subscriber::EnvFilter;

mod beacon_stub;
mod helper;
pub mod shasta;

pub use beacon_stub::BeaconStubServer;
pub use helper::mine_l1_block;
pub use shasta::{env::ShastaEnv, helpers::verify_anchor_block};

/// Initialise tracing for tests using a single global subscriber.
///
/// The `default_filter` is used when the `RUST_LOG` environment variable is not set.
pub(crate) fn init_tracing(default_filter: &str) {
    static INIT: OnceLock<()> = OnceLock::new();

    INIT.get_or_init(|| {
        let env_filter =
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new(default_filter));
        let _ = tracing_subscriber::fmt().with_env_filter(env_filter).try_init();
    });
}
