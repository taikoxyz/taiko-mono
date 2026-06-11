//! Transaction building utilities for E2E tests.
//!
//! This module provides helpers for building signed transactions:
//! - [`TransferPayload`]: A signed transfer with hash/sender for assertions.
//! - [`build_signed_transfer`]: Builds an EIP-1559 transfer transaction.
//! - [`build_anchor_tx_bytes`]: Constructs anchor transaction bytes.
//! - [`compute_next_block_base_fee`]: Calculates EIP-4396 base fee.
//! - [`build_test_transfers`]: Builds standard test transfers with automatic funding.
//! - [`PreconfTxList`]: A complete transaction list for preconfirmation.
//! - [`build_preconf_txlist`]: Builds anchor + test transfers in one call.

mod anchor;
mod base_fee;
mod funding;
mod transfer;
mod txlist;

pub(crate) use anchor::build_anchor_tx_bytes;
pub use base_fee::compute_next_block_base_fee;
pub(crate) use funding::build_test_transfers;
pub use transfer::TransferPayload;
pub(crate) use transfer::build_signed_transfer;
pub use txlist::{PreconfTxList, build_preconf_txlist};
