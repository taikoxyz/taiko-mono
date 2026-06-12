//! Cryptographic utilities for hashing, signing, and signature recovery within the preconfirmation
//! P2P layer.
//!
//! This module provides functions for:
//! - Keccak-256 hashing of byte arrays and SSZ-serialized values.
//! - Signing preconfirmation commitments using secp256k1.
//! - Recovering the signer's address from a secp256k1 signature.
//! - Verifying signed commitments.
//! - Converting public keys to Ethereum addresses.

use alloy_primitives::{Address, B256};
use secp256k1::{
    Message, PublicKey, Secp256k1, SecretKey,
    ecdsa::{RecoverableSignature, RecoveryId},
};
use sha3::{Digest, Keccak256};
use ssz_rs::prelude::*;

use crate::{
    types::{Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment},
    validation::CryptoError,
};

/// Keccak-256 hash of arbitrary bytes.
pub fn keccak256_bytes(data: impl AsRef<[u8]>) -> B256 {
    B256::from_slice(&Keccak256::digest(data))
}

/// Keccak-256 hash of an SSZ-serializable value using the default `DOMAIN_PRECONF`.
pub fn keccak256_ssz<T: SimpleSerialize>(value: &T) -> Result<B256, CryptoError> {
    keccak256_ssz_with_domain(value, &crate::constants::DOMAIN_PRECONF)
}

/// Keccak-256 hash of a `Preconfirmation` (used for parent linkage).
/// The message is SSZ-serialized without any domain separation per spec §3.1.
pub fn preconfirmation_hash(preconf: &Preconfirmation) -> Result<B256, CryptoError> {
    Ok(keccak256_bytes(ssz_rs::serialize(preconf).map_err(CryptoError::Ssz)?))
}

/// Keccak-256 hash of SSZ bytes with an explicit 32-byte domain separator.
pub fn keccak256_ssz_with_domain<T: SimpleSerialize>(
    value: &T,
    domain: &[u8; 32],
) -> Result<B256, CryptoError> {
    let ssz_bytes = ssz_rs::serialize(value).map_err(CryptoError::Ssz)?;
    let mut bytes = Vec::with_capacity(32 + ssz_bytes.len());
    bytes.extend_from_slice(domain);
    bytes.extend(ssz_bytes);
    Ok(keccak256_bytes(bytes))
}

/// Sign the SSZ-serialized commitment with a secp256k1 key, returning a 65-byte (r,s,v) signature.
///
/// Uses the default `DOMAIN_PRECONF` separator; deployments with a chain-specific domain
/// should use [`sign_commitment_with_domain`].
pub fn sign_commitment(
    commitment: &PreconfCommitment,
    sk: &SecretKey,
) -> Result<Bytes65, CryptoError> {
    sign_commitment_with_domain(commitment, sk, &crate::constants::DOMAIN_PRECONF)
}

/// Sign the SSZ-serialized commitment with an explicit 32-byte signing domain (spec §4.1).
pub fn sign_commitment_with_domain(
    commitment: &PreconfCommitment,
    sk: &SecretKey,
    domain: &[u8; 32],
) -> Result<Bytes65, CryptoError> {
    let msg_hash = keccak256_ssz_with_domain(commitment, domain)?;
    let msg =
        Message::from_digest_slice(msg_hash.as_slice()).map_err(CryptoError::SignatureFormat)?;
    let sig = Secp256k1::new().sign_ecdsa_recoverable(&msg, sk);
    let (rec_id, compact) = sig.serialize_compact();
    let mut out = [0u8; 65];
    out[..64].copy_from_slice(&compact);
    out[64] = i32::from(rec_id) as u8;
    Vector::try_from(out.to_vec())
        .map_err(|_| CryptoError::SignatureFormat(secp256k1::Error::InvalidSignature))
}

/// Recover the signer address from a signature over SSZ(commitment).
///
/// Uses the default `DOMAIN_PRECONF` separator; deployments with a chain-specific domain
/// should use [`recover_signer_with_domain`].
pub fn recover_signer(
    commitment: &PreconfCommitment,
    signature: &Bytes65,
) -> Result<Address, CryptoError> {
    recover_signer_with_domain(commitment, signature, &crate::constants::DOMAIN_PRECONF)
}

/// Recover the signer address from a signature using an explicit 32-byte signing domain
/// (spec §4.1).
pub fn recover_signer_with_domain(
    commitment: &PreconfCommitment,
    signature: &Bytes65,
    domain: &[u8; 32],
) -> Result<Address, CryptoError> {
    let msg_hash = keccak256_ssz_with_domain(commitment, domain)?;
    let msg =
        Message::from_digest_slice(msg_hash.as_slice()).map_err(CryptoError::SignatureFormat)?;
    let rec_id =
        RecoveryId::try_from(signature[64] as i32).map_err(CryptoError::SignatureFormat)?;
    let mut compact = [0u8; 64];
    compact.copy_from_slice(&signature.as_ref()[..64]);
    let sig = RecoverableSignature::from_compact(&compact, rec_id)
        .map_err(CryptoError::SignatureFormat)?;
    let pubkey = Secp256k1::new().recover_ecdsa(&msg, &sig).map_err(CryptoError::Recover)?;
    Ok(public_key_to_address(&pubkey))
}

/// Verify a `SignedCommitment`, returning the recovered address on success.
///
/// Uses the default `DOMAIN_PRECONF` separator; deployments with a chain-specific domain
/// should use [`verify_signed_commitment_with_domain`].
pub fn verify_signed_commitment(signed: &SignedCommitment) -> Result<Address, CryptoError> {
    recover_signer(&signed.commitment, &signed.signature)
}

/// Verify a `SignedCommitment` under an explicit 32-byte signing domain (spec §4.1),
/// returning the recovered address on success.
pub fn verify_signed_commitment_with_domain(
    signed: &SignedCommitment,
    domain: &[u8; 32],
) -> Result<Address, CryptoError> {
    recover_signer_with_domain(&signed.commitment, &signed.signature, domain)
}

/// Convert a secp256k1 public key into an Ethereum address (last 20 bytes of keccak256(pubkey)).
pub fn public_key_to_address(pk: &PublicKey) -> Address {
    let uncompressed = pk.serialize_uncompressed();
    debug_assert_eq!(uncompressed[0], 0x04);
    let hash = keccak256_bytes(&uncompressed[1..]);
    Address::from_slice(&hash.as_slice()[12..])
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{PreconfCommitment, Preconfirmation, Uint256};

    /// Build a deterministic commitment used for hashing/signing tests.
    fn sample_commitment() -> PreconfCommitment {
        PreconfCommitment {
            preconf: Preconfirmation {
                eop: false,
                block_number: Uint256::from(1u64),
                timestamp: Uint256::from(2u64),
                gas_limit: Uint256::from(3u64),
                coinbase: Vector::try_from(vec![0u8; 20]).unwrap(),
                anchor_block_number: Uint256::from(4u64),
                raw_tx_list_hash: Vector::try_from(vec![1u8; 32]).unwrap(),
                parent_preconfirmation_hash: Vector::try_from(vec![2u8; 32]).unwrap(),
                submission_window_end: Uint256::from(5u64),
                prover_auth: Vector::try_from(vec![3u8; 20]).unwrap(),
                proposal_id: Uint256::from(6u64),
            },
            slasher_address: Vector::try_from(vec![9u8; 20]).unwrap(),
        }
    }

    /// Keccak over SSZ matches manual keccak of domain + serialized value.
    #[test]
    fn keccak_ssz_matches_keccak_bytes() {
        let value = sample_commitment();
        let ssz_hash = keccak256_ssz(&value).unwrap();
        let mut raw = crate::constants::DOMAIN_PRECONF.to_vec();
        raw.extend(ssz_rs::serialize(&value).unwrap());
        let manual = keccak256_bytes(raw);
        assert_eq!(ssz_hash, manual);
    }

    /// Signing and recovery yields the expected Ethereum address.
    #[test]
    fn sign_and_verify_commitment_recovers_address() {
        let commitment = sample_commitment();
        let sk_bytes = [42u8; 32];
        let sk = SecretKey::from_slice(&sk_bytes).unwrap();
        let sig = sign_commitment(&commitment, &sk).unwrap();
        let recovered = recover_signer(&commitment, &sig).unwrap();
        let pk = PublicKey::from_secret_key(&Secp256k1::new(), &sk);
        let expected = public_key_to_address(&pk);
        assert_eq!(recovered, expected);
    }

    /// Signing and recovery agree when both sides use the same custom domain.
    #[test]
    fn custom_domain_sign_and_recover_roundtrip() {
        let commitment = sample_commitment();
        let sk = SecretKey::from_slice(&[42u8; 32]).unwrap();
        let domain = *b"CUSTOM_PRECONF_DOMAIN_FOR_TESTS!";
        let sig = sign_commitment_with_domain(&commitment, &sk, &domain).unwrap();
        let recovered = recover_signer_with_domain(&commitment, &sig, &domain).unwrap();
        let pk = PublicKey::from_secret_key(&Secp256k1::new(), &sk);
        assert_eq!(recovered, public_key_to_address(&pk));

        let signed = SignedCommitment { commitment, signature: sig };
        let verified = verify_signed_commitment_with_domain(&signed, &domain).unwrap();
        assert_eq!(verified, public_key_to_address(&pk));
    }

    /// Recovery under a different domain must not yield the signer's address.
    #[test]
    fn mismatched_domain_recovers_different_signer() {
        let commitment = sample_commitment();
        let sk = SecretKey::from_slice(&[42u8; 32]).unwrap();
        let domain = *b"CUSTOM_PRECONF_DOMAIN_FOR_TESTS!";
        let sig = sign_commitment_with_domain(&commitment, &sk, &domain).unwrap();
        let pk = PublicKey::from_secret_key(&Secp256k1::new(), &sk);
        let signer = public_key_to_address(&pk);

        // Recovering with the default domain must not attribute the signature to the signer.
        let recovered = recover_signer(&commitment, &sig);
        assert!(recovered.is_err() || recovered.unwrap() != signer);
    }

    /// The default-domain helpers stay byte-identical to the explicit-domain variants.
    #[test]
    fn default_domain_helpers_match_explicit_variants() {
        let commitment = sample_commitment();
        let sk = SecretKey::from_slice(&[42u8; 32]).unwrap();
        let default_sig = sign_commitment(&commitment, &sk).unwrap();
        let explicit_sig =
            sign_commitment_with_domain(&commitment, &sk, &crate::constants::DOMAIN_PRECONF)
                .unwrap();
        assert_eq!(default_sig, explicit_sig);
    }

    /// Verifying a signed commitment recovers the signer used to create it.
    #[test]
    fn verify_signed_commitment_roundtrip() {
        let commitment = sample_commitment();
        let sk_bytes = [7u8; 32];
        let sk = SecretKey::from_slice(&sk_bytes).unwrap();
        let sig = sign_commitment(&commitment, &sk).unwrap();
        let signed = SignedCommitment { commitment, signature: sig.clone() };
        let recovered = verify_signed_commitment(&signed).unwrap();
        let pk = PublicKey::from_secret_key(&Secp256k1::new(), &sk);
        let expected = public_key_to_address(&pk);
        assert_eq!(recovered, expected);
    }
}
