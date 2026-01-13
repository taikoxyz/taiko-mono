//! Mock lookahead resolver for preconfirmation integration tests.

use alloy_primitives::{Address, U256};
use async_trait::async_trait;
use protocol::preconfirmation::{PreconfSignerResolver, PreconfSlotInfo, Result};

/// Derive an address from a secret key.
fn address_from_secret_key(sk: &secp256k1::SecretKey) -> Address {
    let pk = secp256k1::PublicKey::from_secret_key(&secp256k1::Secp256k1::new(), sk);
    preconfirmation_types::public_key_to_address(&pk)
}

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

    /// Create a resolver that returns the zero address.
    ///
    /// This is useful for tests that don't care about signer validation.
    pub fn zero() -> Self {
        Self::new(Address::ZERO, U256::ZERO)
    }

    /// Create a resolver that returns the given signer with a matching window end.
    ///
    /// The submission_window_end will be set to the timestamp + 12 (one slot).
    pub fn with_signer(signer: Address) -> Self {
        Self { signer, submission_window_end: U256::ZERO }
    }

    /// Create a resolver from a secret key.
    ///
    /// Derives the signer address from the secret key's public key.
    pub fn from_secret_key(sk: &secp256k1::SecretKey) -> Self {
        Self::new(address_from_secret_key(sk), U256::ZERO)
    }

    /// Set the submission window end value.
    pub fn with_submission_window_end(mut self, submission_window_end: U256) -> Self {
        self.submission_window_end = submission_window_end;
        self
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

/// A lookahead resolver that echoes the input timestamp as the submission window end.
///
/// This is useful for tests where you want the submission_window_end to match
/// the timestamp in the commitment.
pub struct EchoLookaheadResolver {
    /// The signer address to return for all timestamps.
    signer: Address,
}

impl EchoLookaheadResolver {
    /// Create a new echo resolver with the given signer.
    pub fn new(signer: Address) -> Self {
        Self { signer }
    }

    /// Create an echo resolver from a secret key.
    pub fn from_secret_key(sk: &secp256k1::SecretKey) -> Self {
        Self { signer: address_from_secret_key(sk) }
    }
}

#[async_trait]
impl PreconfSignerResolver for EchoLookaheadResolver {
    async fn signer_for_timestamp(&self, _l2_block_timestamp: U256) -> Result<Address> {
        Ok(self.signer)
    }

    async fn slot_info_for_timestamp(&self, l2_block_timestamp: U256) -> Result<PreconfSlotInfo> {
        // Echo the timestamp as the submission window end
        Ok(PreconfSlotInfo { signer: self.signer, submission_window_end: l2_block_timestamp })
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

    #[tokio::test]
    async fn echo_resolver_echoes_timestamp() {
        let signer = Address::repeat_byte(0x42);
        let resolver = EchoLookaheadResolver::new(signer);

        let timestamp = U256::from(12345);
        let info = resolver.slot_info_for_timestamp(timestamp).await.unwrap();
        assert_eq!(info.signer, signer);
        assert_eq!(info.submission_window_end, timestamp);
    }
}
