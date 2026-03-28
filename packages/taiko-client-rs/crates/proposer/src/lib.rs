#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
#![cfg_attr(test, allow(missing_docs, clippy::missing_docs_in_private_items))]
//! Taiko proposer for submitting L2 blocks batch proposals to L1.
pub mod config;
pub mod error;
pub mod metrics;
pub mod proposer;
pub mod transaction_builder;
pub(crate) mod tx_manager_adapter;
