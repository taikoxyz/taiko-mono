//! Driver integration traits and data types.
//!
//! This module provides the [`EmbeddedDriverClient`] for direct in-process
//! communication with the driver via channels.

use preconfirmation_types::SignedCommitment;

use crate::validation::is_eop_only;

/// Embedded driver client for direct in-process communication.
pub mod embedded;
/// Execution payload builder.
pub mod payload;
/// Driver-facing traits and input structures.
pub mod traits;

/// Preconfirmation input handed to the driver for ordered processing.
#[derive(Debug, Clone)]
pub struct PreconfirmationInput {
    /// The full signed commitment from the preconfer.
    pub commitment: SignedCommitment,
    /// Decoded transactions (raw tx bytes); None for EOP-only commitments.
    pub transactions: Option<Vec<Vec<u8>>>,
    /// Raw compressed txlist bytes for audit/debugging.
    pub compressed_txlist: Option<Vec<u8>>,
}

impl PreconfirmationInput {
    /// Build a new input with optional transactions and compressed payload.
    pub fn new(
        commitment: SignedCommitment,
        transactions: Option<Vec<Vec<u8>>>,
        compressed_txlist: Option<Vec<u8>>,
    ) -> Self {
        Self { commitment, transactions, compressed_txlist }
    }

    /// Return true when this input should be skipped by the driver client.
    pub fn should_skip_driver_submission(&self) -> bool {
        is_eop_only(&self.commitment) &&
            self.transactions.as_ref().is_none_or(|transactions| transactions.is_empty())
    }
}

pub use embedded::{ContractInboxReader, EmbeddedDriverClient};
pub use traits::{BlockHeaderProvider, DriverClient, InboxReader};

#[cfg(test)]
mod tests {
    use super::PreconfirmationInput;
    use preconfirmation_types::{
        Bytes32, Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment,
    };

    fn build_commitment(eop: bool, raw_tx_list_hash: Bytes32) -> SignedCommitment {
        let preconf = Preconfirmation { eop, raw_tx_list_hash, ..Default::default() };
        let commitment = PreconfCommitment { preconf, ..Default::default() };
        let signature = Bytes65::try_from(vec![0u8; 65]).expect("signature bytes");
        SignedCommitment { commitment, signature }
    }

    /// Ensure the input struct can be constructed.
    #[test]
    fn preconfirmation_input_constructs() {
        // Build a test commitment.
        let preconf = Preconfirmation { eop: false, ..Default::default() };
        // Build a dummy signature.
        let signature: Bytes65 = Bytes65::try_from(vec![0u8; 65]).expect("signature bytes");
        // Build the signed commitment.
        let commitment = SignedCommitment {
            commitment: PreconfCommitment { preconf, ..Default::default() },
            signature,
        };
        // Build the input.
        let input = PreconfirmationInput::new(commitment, None, None);
        assert!(input.transactions.is_none());
    }

    #[test]
    fn eop_only_without_transactions_should_skip() {
        let zero_hash = Bytes32::try_from(vec![0u8; 32]).expect("zero hash");
        let commitment = build_commitment(true, zero_hash);
        let input = PreconfirmationInput::new(commitment, None, None);
        assert!(input.should_skip_driver_submission());
    }

    #[test]
    fn eop_only_with_transactions_should_not_skip() {
        let zero_hash = Bytes32::try_from(vec![0u8; 32]).expect("zero hash");
        let commitment = build_commitment(true, zero_hash);
        let input = PreconfirmationInput::new(commitment, Some(vec![vec![0x01]]), None);
        assert!(!input.should_skip_driver_submission());
    }

    #[test]
    fn non_eop_without_transactions_should_not_skip() {
        let zero_hash = Bytes32::try_from(vec![0u8; 32]).expect("zero hash");
        let commitment = build_commitment(false, zero_hash);
        let input = PreconfirmationInput::new(commitment, None, None);
        assert!(!input.should_skip_driver_submission());
    }

    #[test]
    fn eop_true_with_nonzero_hash_should_not_skip() {
        let nonzero_hash = Bytes32::try_from(vec![1u8; 32]).expect("nonzero hash");
        let commitment = build_commitment(true, nonzero_hash);
        let input = PreconfirmationInput::new(commitment, None, None);
        assert!(!input.should_skip_driver_submission());
    }
}
