//! Mock lookahead resolver for preconfirmation integration tests.

use alloy_primitives::{Address, U256};
use async_trait::async_trait;
use protocol::preconfirmation::{PreconfSignerResolver, PreconfSlotInfo, Result};

/// A static lookahead resolver that always returns the configured signer.
///
/// This is useful for deterministic tests where you want to control
/// exactly which signer is expected for any timestamp.
///
/// # Example
///
/// ```ignore
/// let sk = SecretKey::from_slice(&[1u8; 32]).unwrap();
/// let signer = public_key_to_address(&PublicKey::from_secret_key(&Secp256k1::new(), &sk));
/// let resolver = StaticLookaheadResolver::new(signer, U256::from(1000));
///
/// // All timestamps will resolve to the same signer
/// let info = resolver.slot_info_for_timestamp(U256::from(500)).await?;
/// assert_eq!(info.signer, signer);
/// ```
pub struct StaticLookaheadResolver {
    /// The signer address to return for all timestamps.
    signer: Address,
    /// The submission window end to return for all timestamps.
    submission_window_end: U256,
}

impl StaticLookaheadResolver {
    /// Create a new static resolver with the given signer and submission window end.
    pub fn new(signer: Address, submission_window_end: U256) -> Self {
        Self { signer, submission_window_end }
    }
}

#[async_trait]
impl PreconfSignerResolver for StaticLookaheadResolver {
    async fn signer_for_timestamp(&self, _l2_block_timestamp: U256) -> Result<Address> {
        Ok(self.signer)
    }

    async fn slot_info_for_timestamp(&self, _l2_block_timestamp: U256) -> Result<PreconfSlotInfo> {
        Ok(PreconfSlotInfo {
            signer: self.signer,
            submission_window_end: self.submission_window_end,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn static_resolver_returns_configured_signer() {
        let signer = Address::repeat_byte(0x42);
        let resolver = StaticLookaheadResolver::new(signer, U256::from(1000));

        let result = resolver.signer_for_timestamp(U256::from(500)).await.unwrap();
        assert_eq!(result, signer);

        let info = resolver.slot_info_for_timestamp(U256::from(500)).await.unwrap();
        assert_eq!(info.signer, signer);
        assert_eq!(info.submission_window_end, U256::from(1000));
    }
}
