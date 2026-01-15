//! Test utilities for preconfirmation integration tests.
//!
//! This module provides mock implementations for testing the preconfirmation client:
//! - [`MockDriverClient`]: A mock driver client that records submissions for verification.
//! - [`StaticLookaheadResolver`]: A static lookahead resolver for deterministic tests.
//! - [`EchoLookaheadResolver`]: A resolver that echoes the timestamp as submission window end.

mod driver;
mod lookahead;

pub use driver::{MockDriverClient, SafeTipDriverClient};
pub use lookahead::{EchoLookaheadResolver, StaticLookaheadResolver};
