//! Transaction building utilities for E2E tests.
//!
//! This module provides helpers for building signed transactions:
//! - [`TransferPayload`]: A signed transfer with hash/sender for assertions.
//! - [`build_signed_transfer`]: Builds an EIP-1559 transfer transaction.
//! - [`build_anchor_tx_bytes`]: Constructs anchor transaction bytes.
//! - [`compute_next_block_base_fee`]: Calculates EIP-4396 base fee.

mod anchor;
mod base_fee;
mod transfer;

pub use anchor::build_anchor_tx_bytes;
pub use base_fee::compute_next_block_base_fee;
pub use transfer::{TransferPayload, build_signed_transfer};
