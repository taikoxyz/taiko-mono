//! Deterministic secp256k1 signer with fixed-k signing support.

use alloy::signers::{Result as SignerResult, Signer, SignerSync};
use alloy_primitives::{Address, B256, Signature as AlloySignature, U256, hex};
use async_trait::async_trait;
use k256::{
    AffinePoint, FieldBytes, ProjectivePoint, Scalar,
    elliptic_curve::{
        bigint::U256 as ScalarModulus, ff::PrimeField, ops::Reduce, point::AffineCoordinates,
        scalar::IsHigh, sec1::ToEncodedPoint,
    },
};
use thiserror::Error;
use tracing::{debug, instrument};

/// Golden touch testnet private key used by the protocol.
pub const GOLDEN_TOUCH_PRIVATE_KEY: &str =
    "0x92954368afd3caa1f3ce3ead0069c1af414054aefe1ef9aeacc1bf426222ce38";

/// Result of a fixed-`k` signing attempt.
#[derive(Debug, Clone)]
pub struct SignatureWithRecoveryId {
    /// Canonical ECDSA signature compatible with Alloy types.
    pub signature: alloy_primitives::Signature,
    /// Recovery identifier matching go-ethereum's encoding (`0..=3`).
    pub recovery_id: u8,
}

/// Errors raised by [`FixedKSigner`].
#[derive(Debug, Error)]
pub enum FixedKSignerError {
    /// The provided private key is malformed or outside the curve order.
    #[error("invalid private key")]
    InvalidPrivateKey,
    /// Failed to invert the provided `k` value (should never happen for valid inputs).
    #[error("non-invertible signing scalar")]
    NonInvertibleScalar,
    /// The deterministic signing attempt produced an invalid signature (s == 0).
    #[error("invalid signature component")]
    ZeroSignatureComponent,
    /// All configured `k` candidates failed to produce a valid signature.
    #[error("unable to sign with provided k candidates")]
    SigningFailed,
}

/// Deterministic secp256k1 signer.
#[derive(Debug, Clone)]
pub struct FixedKSigner {
    secret_scalar: Scalar,
    address: Address,
    chain_id: Option<u64>,
}

impl FixedKSigner {
    /// Instantiate a signer from a hex-encoded private key (with or without `0x`).
    #[instrument(skip(private_key_hex))]
    pub fn new(private_key_hex: &str) -> Result<Self, FixedKSignerError> {
        let trimmed = private_key_hex.strip_prefix("0x").unwrap_or(private_key_hex);
        let bytes = hex::decode_to_array::<_, 32>(trimmed)
            .map_err(|_| FixedKSignerError::InvalidPrivateKey)?;

        let maybe_scalar = Scalar::from_repr(bytes.into());
        let scalar =
            Option::<Scalar>::from(maybe_scalar).ok_or(FixedKSignerError::InvalidPrivateKey)?;

        if scalar.is_zero().into() {
            return Err(FixedKSignerError::InvalidPrivateKey);
        }

        let address = Self::derive_address(&scalar);

        debug!(?address, "initialised fixed-k signer");
        Ok(Self { secret_scalar: scalar, address, chain_id: None })
    }

    /// Convenience helper that instantiates the signer using the embedded golden-touch key.
    #[instrument]
    pub fn golden_touch() -> Result<Self, FixedKSignerError> {
        Self::new(GOLDEN_TOUCH_PRIVATE_KEY)
    }

    /// Attempt to sign the provided digest using a fixed list of `k` candidates.
    ///
    /// The method mirrors the Go implementation by first trying `k = 1`, then `k = 2`.
    #[instrument(skip(self, hash))]
    pub fn sign_with_predefined_k(
        &self,
        hash: &[u8; 32],
    ) -> Result<SignatureWithRecoveryId, FixedKSignerError> {
        for candidate in [Scalar::ONE, Scalar::from(2u64)] {
            if let Ok(signature) = self.sign_with_specific_k(candidate, hash) {
                debug!(?candidate, "generated signature with fixed k");
                return Ok(signature);
            }
        }
        Err(FixedKSignerError::SigningFailed)
    }

    /// Perform a fixed-`k` signing attempt. The caller is responsible for providing a valid `k`.
    #[instrument(skip(self, hash))]
    pub fn sign_with_specific_k(
        &self,
        k: Scalar,
        hash: &[u8; 32],
    ) -> Result<SignatureWithRecoveryId, FixedKSignerError> {
        // Calculate k * G in affine coordinates.
        let k_point: AffinePoint = (ProjectivePoint::GENERATOR * k).to_affine();
        let x_bytes = k_point.x();
        let y_is_odd = bool::from(k_point.y_is_odd());

        let raw_r = Scalar::from_repr(x_bytes);
        let overflow = !bool::from(raw_r.is_some());
        let r = raw_r.unwrap_or_else(|| <Scalar as Reduce<ScalarModulus>>::reduce_bytes(&x_bytes));

        let kinv =
            Option::<Scalar>::from(k.invert()).ok_or(FixedKSignerError::NonInvertibleScalar)?;

        // s = k^{-1} (hash + r * priv)
        let hash_bytes: FieldBytes = (*hash).into();
        let e = <Scalar as Reduce<ScalarModulus>>::reduce_bytes(&hash_bytes);
        let mut s = self.secret_scalar.mul(&r).add(&e).mul(&kinv);

        if s.is_zero().into() {
            return Err(FixedKSignerError::ZeroSignatureComponent);
        }

        let mut recovery_id = ((overflow as u8) << 1) | (y_is_odd as u8);
        if bool::from(s.is_high()) {
            s = -s;
            recovery_id ^= 0x01;
        }

        let r_bytes = r.to_bytes();
        let s_bytes = s.to_bytes();

        let signature = AlloySignature::new(
            U256::from_be_slice(r_bytes.as_ref()),
            U256::from_be_slice(s_bytes.as_ref()),
            (recovery_id & 1) == 1,
        );

        debug!(
            r = ?r_bytes,
            s = ?s_bytes,
            recovery_id,
            "produced fixed-k signature"
        );
        Ok(SignatureWithRecoveryId { signature, recovery_id })
    }

    /// Derive the Ethereum address corresponding to the given private key scalar.
    fn derive_address(scalar: &Scalar) -> Address {
        let public_key = (ProjectivePoint::GENERATOR * scalar).to_affine();
        let encoded = public_key.to_encoded_point(false);
        Address::from_raw_public_key(&encoded.as_bytes()[1..])
    }

    /// Internal helper to implement the `SignerSync` trait.
    fn sign_hash_internal(&self, hash: &B256) -> Result<AlloySignature, FixedKSignerError> {
        let mut bytes = [0u8; 32];
        bytes.copy_from_slice(hash.as_slice());
        let sig = self.sign_with_predefined_k(&bytes)?;
        debug!(address = ?self.address, "produced signature for hash");
        Ok(sig.signature)
    }
}

#[async_trait]
impl Signer for FixedKSigner {
    /// Asynchronously sign a 32-byte hash.
    async fn sign_hash(&self, hash: &B256) -> SignerResult<AlloySignature> {
        SignerSync::sign_hash_sync(self, hash)
    }

    /// Return the signer's Ethereum address.
    fn address(&self) -> Address {
        self.address
    }

    /// Return the signer's configured chain ID, if any.
    fn chain_id(&self) -> Option<u64> {
        self.chain_id
    }

    /// Set or clear the signer's chain ID.
    fn set_chain_id(&mut self, chain_id: Option<u64>) {
        self.chain_id = chain_id;
    }
}

impl SignerSync for FixedKSigner {
    /// Synchronously sign a 32-byte hash.
    fn sign_hash_sync(&self, hash: &B256) -> SignerResult<AlloySignature> {
        self.sign_hash_internal(hash).map_err(alloy::signers::Error::other)
    }

    /// Return the signer's Ethereum address.
    fn chain_id_sync(&self) -> Option<u64> {
        self.chain_id
    }
}

#[cfg(all(test, feature = "net"))]
mod tests {
    use super::*;
    use k256::Scalar;
    use tokio::runtime::Runtime;

    fn expected_signature(r_hex: &str, s_hex: &str, v: u8) -> (AlloySignature, u8) {
        let r_bytes = hex::decode_to_array::<_, 32>(r_hex).unwrap();
        let s_bytes = hex::decode_to_array::<_, 32>(s_hex).unwrap();
        let r = U256::from_be_slice(&r_bytes);
        let s = U256::from_be_slice(&s_bytes);
        (AlloySignature::new(r, s, v == 1), v)
    }

    #[test]
    fn sign_with_specific_k_matches_go_vectors() {
        let signer = FixedKSigner::golden_touch().expect("golden touch key");

        let payload = hex::decode_to_array::<_, 32>(
            "0x44943399d1507f3ce7525e9be2f987c3db9136dc759cb7f92f742154196868b9",
        )
        .unwrap();
        let signature =
            signer.sign_with_specific_k(Scalar::from(2u64), &payload).expect("signing succeeds");
        let (expected_sig, expected_v) = expected_signature(
            "0xc6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5",
            "0x38940d69b21d5b088beb706e9ebabe6422307e12863997a44239774467e240d5",
            1,
        );
        assert_eq!(signature.signature, expected_sig);
        assert_eq!(signature.recovery_id, expected_v);

        let payload = hex::decode_to_array::<_, 32>(
            "0x663d210fa6dba171546498489de1ba024b89db49e21662f91bf83cdffe788820",
        )
        .unwrap();
        let signature =
            signer.sign_with_specific_k(Scalar::from(2u64), &payload).expect("signing succeeds");
        let (expected_sig, expected_v) = expected_signature(
            "0xc6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5",
            "0x5840695138a83611aa9dac67beb95aba7323429787a78df993f1c5c7f2c0ef7f",
            0,
        );
        assert_eq!(signature.signature, expected_sig);
        assert_eq!(signature.recovery_id, expected_v);
    }

    #[test]
    fn sign_with_predefined_k_matches_specific_k() {
        let signer = FixedKSigner::golden_touch().expect("golden touch key");
        let payload = hex::decode_to_array::<_, 32>(
            "0x663d210fa6dba171546498489de1ba024b89db49e21662f91bf83cdffe788820",
        )
        .unwrap();
        let k1_sig = signer.sign_with_specific_k(Scalar::ONE, &payload).ok();
        let k2_sig =
            signer.sign_with_specific_k(Scalar::from(2u64), &payload).expect("k=2 signature");
        let actual =
            signer.sign_with_predefined_k(&payload).expect("predefined k signature").signature;
        let matches_k1 = k1_sig.as_ref().map(|sig| sig.signature == actual).unwrap_or(false);
        let matches_k2 = k2_sig.signature == actual;
        assert!(matches_k1 || matches_k2, "predefined-k result matches neither k=1 nor k=2 output");
    }

    #[test]
    fn signer_trait_impls_sign_hashed_payload() {
        let signer = FixedKSigner::golden_touch().expect("golden touch key");
        let payload = hex::decode_to_array::<_, 32>(
            "0x44943399d1507f3ce7525e9be2f987c3db9136dc759cb7f92f742154196868b9",
        )
        .unwrap();
        let hash = B256::from(payload);
        let expected = SignerSync::sign_hash_sync(&signer, &hash).expect("sync sign");

        let rt = Runtime::new().expect("runtime");
        let async_sig = rt.block_on(signer.sign_hash(&hash)).expect("async sign");
        assert_eq!(async_sig, expected);
    }
}
