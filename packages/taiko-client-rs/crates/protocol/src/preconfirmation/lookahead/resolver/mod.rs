//! Lookahead resolver submodules split for readability.

mod core;
mod epoch;
mod timeline;
mod types;

pub use core::LookaheadResolver;
pub(crate) use epoch::{SECONDS_IN_EPOCH, SECONDS_IN_SLOT};
pub use types::LookaheadBroadcast;
