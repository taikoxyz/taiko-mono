//! Transaction building utilities for E2E tests.
//!
//! This module provides helpers for building signed transactions:
//! - [`TransferPayload`]: A signed transfer with hash/sender for assertions.
//! - [`build_signed_transfer`]: Builds an EIP-1559 transfer transaction.
//! - [`build_anchor_tx_bytes`]: Constructs anchor transaction bytes.
//! - [`compute_next_block_base_fee`]: Calculates EIP-4396 base fee.
//! - [`build_test_transfers`]: Builds standard test transfers with automatic funding.
//! - [`ensure_test_account_funded`]: Funds test account if balance is zero.
//! - [`PreconfTxList`]: A complete transaction list for preconfirmation.
//! - [`build_preconf_txlist`]: Builds anchor + test transfers in one call.

mod anchor;
mod base_fee;
mod funding;
mod transfer;
mod txlist;

pub use anchor::build_anchor_tx_bytes;
pub use base_fee::compute_next_block_base_fee;
pub use funding::{DEFAULT_FUND_AMOUNT, build_test_transfers, ensure_test_account_funded};
pub use transfer::{TransferPayload, build_signed_transfer};
pub use txlist::{PreconfTxList, build_preconf_txlist, build_preconf_txlist_with_transfers};
