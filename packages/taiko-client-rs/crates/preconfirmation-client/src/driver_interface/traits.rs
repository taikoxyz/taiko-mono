//! Driver interface trait definitions.

use async_trait::async_trait;
use preconfirmation_types::SignedCommitment;

use crate::error::Result;

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
}

/// Trait for submitting preconfirmation inputs to the driver.
#[async_trait]
pub trait DriverSubmitter: Send + Sync {
    /// Submit a preconfirmation input for ordered processing.
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()>;
}

#[cfg(test)]
mod tests {
    use super::{DriverSubmitter, PreconfirmationInput};

    /// Ensure the driver submitter trait can be referenced.
    #[test]
    fn driver_submitter_trait_exists() {
        // Use a generic assertion to reference the trait.
        fn _assert_trait<T: DriverSubmitter>() {}
        assert!(true);
    }

    /// Ensure the input struct can be constructed.
    #[test]
    fn preconfirmation_input_constructs() {
        use preconfirmation_types::{
            Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment,
        };

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
}
