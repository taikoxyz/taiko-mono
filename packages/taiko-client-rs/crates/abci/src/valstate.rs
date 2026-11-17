//! Canonical stock CometBFT validator-state replica.
pub use etna_core::valstate::{ValEntry, ValSet, ValState, ValStateError};
#[cfg(test)]
pub(crate) use etna_core::valstate::{spec_41a_state, stock_lookup};
