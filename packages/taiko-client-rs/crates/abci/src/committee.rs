//! The signing set decision and validator updates: etna-core's one definition, re-exported.
//!
//! Every generation starts on its origin record's fallback keys, each at power 1; from then on
//! [`decide`] picks each set from the candidate snapshot or the fallback keys and
//! [`validator_updates`] turns two consecutive sets into CometBFT validator updates.

pub use etna_core::committee::*;
