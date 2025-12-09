//! Lookahead resolver submodules split for readability.

mod core;
mod epoch;
mod timeline;
mod types;

pub use core::LookaheadResolver;
pub(crate) use epoch::MAX_LOOKBACK_EPOCHS;
pub use types::LookaheadBroadcast;
