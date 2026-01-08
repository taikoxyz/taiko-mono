//! Driver interface trait definitions.

use alloy_primitives::U256;
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

/// Trait for driving preconfirmation submissions and sync state.
#[async_trait]
pub trait DriverClient: Send + Sync {
    /// Submit a preconfirmation input for ordered processing.
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> Result<()>;
    /// Await the driver event sync completion signal.
    async fn wait_event_sync(&self) -> Result<()>;
    /// Return the latest event sync tip block number.
    async fn event_sync_tip(&self) -> Result<U256>;
}

#[cfg(test)]
mod tests {
    use super::PreconfirmationInput;

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
