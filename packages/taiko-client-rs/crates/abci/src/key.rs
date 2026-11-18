//! Native compressed SEC1 keys and Ethereum validator identities for stock CometBFT.

use alloy_primitives::{Address, FixedBytes, keccak256};
use k256::elliptic_curve::sec1::ToEncodedPoint;
use serde::{Deserialize, Serialize};

/// Validated 33-byte secp256k1 public key; never an Ed25519 or transport identity.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(try_from = "FixedBytes<33>", into = "FixedBytes<33>")]
pub struct ConsensusKey(FixedBytes<33>);

/// Invalid compressed key or noncanonical/invalid secp256k1eth signature.
#[derive(Debug, Clone, Copy, PartialEq, Eq, thiserror::Error)]
#[error("invalid secp256k1eth key or signature")]
pub struct KeyError;

impl ConsensusKey {
    /// Validates canonical compressed SEC1 bytes, including curve membership.
    pub fn from_slice(bytes: &[u8]) -> Result<Self, KeyError> {
        let raw = FixedBytes::<33>::try_from(bytes).map_err(|_| KeyError)?;
        if !matches!(raw[0], 2 | 3) {
            return Err(KeyError);
        }
        k256::PublicKey::from_sec1_bytes(bytes).map_err(|_| KeyError)?;
        Ok(Self(raw))
    }

    /// SEC1 parity prefix (2 or 3), for the canonical registry ABI.
    pub const fn prefix(self) -> u8 {
        self.0.0[0]
    }

    /// SEC1 x-coordinate as a fixed-width ABI word.
    pub fn x(self) -> alloy_primitives::B256 {
        alloy_primitives::B256::from_slice(&self.0.0[1..])
    }

    /// Ethereum account address from the uncompressed key, excluding its SEC1 prefix.
    pub fn address(self) -> Address {
        let key = k256::PublicKey::from_sec1_bytes(self.0.as_slice()).expect("validated key");
        let uncompressed = key.to_encoded_point(false);
        Address::from_slice(&keccak256(&uncompressed.as_bytes()[1..])[12..])
    }

    /// Verifies stock low-s R||S||V over Keccak256 of canonical Comet sign bytes.
    pub fn verify_signature(self, sign_bytes: &[u8], signature: &[u8]) -> bool {
        if signature.len() != 65 || signature[64] > 1 {
            return false;
        }
        let Ok(sig) = k256::ecdsa::Signature::from_slice(&signature[..64]) else {
            return false;
        };
        if sig.normalize_s().is_some() {
            return false;
        }
        let recovery = k256::ecdsa::RecoveryId::from_byte(signature[64]).expect("V is 0 or 1");
        k256::ecdsa::VerifyingKey::recover_from_prehash(
            keccak256(sign_bytes).as_slice(),
            &sig,
            recovery,
        )
        .is_ok_and(|key| key.to_encoded_point(true).as_bytes() == self.as_bytes())
    }

    /// Compressed SEC1 bytes, including the parity prefix.
    pub fn as_bytes(&self) -> &[u8; 33] {
        &self.0.0
    }
}

impl TryFrom<FixedBytes<33>> for ConsensusKey {
    /// SEC1 validation failed.
    type Error = KeyError;
    /// Rejects noncanonical SEC1 points during deserialization as well as explicit construction.
    fn try_from(value: FixedBytes<33>) -> Result<Self, Self::Error> {
        Self::from_slice(value.as_slice())
    }
}
impl From<ConsensusKey> for FixedBytes<33> {
    /// Preserves all 33 canonical bytes.
    fn from(key: ConsensusKey) -> Self {
        key.0
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_primitives::{address, hex};
    const KEY: [u8; 33] =
        hex!("0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798");
    #[test]
    fn compressed_key_uses_full_ethereum_validator_address() {
        let key = ConsensusKey::from_slice(&KEY).unwrap();
        assert_eq!(key.address(), address!("7e5f4552091a69125d5dfcb7b8c2659029395bdf"));
        assert_eq!(key.as_bytes(), &KEY);
    }
    #[test]
    fn invalid_or_legacy_keys_cannot_deserialize() {
        assert!(ConsensusKey::from_slice(&KEY[1..]).is_err());
        assert!(ConsensusKey::from_slice(&[0; 33]).is_err());
        assert!(
            serde_json::from_value::<ConsensusKey>(serde_json::json!(FixedBytes::<33>::ZERO))
                .is_err()
        );
    }
}

impl std::fmt::Display for ConsensusKey {
    /// Displays canonical SEC1 bytes as 0x-prefixed hex.
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        self.0.fmt(f)
    }
}

/// Stock JSON public key, separate from the hexadecimal registry representation.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(try_from = "PublicKeyJson", into = "PublicKeyJson")]
pub struct CometPublicKey(
    /// Validated compressed secp256k1eth key.
    pub ConsensusKey,
);

/// Stock key JSON discriminator and padded base64 bytes.
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct PublicKeyJson {
    /// Stock Amino key-type name.
    #[serde(rename = "type")]
    kind: String,
    /// Canonical padded standard-base64 SEC1 bytes.
    value: String,
}
impl From<CometPublicKey> for PublicKeyJson {
    /// Serializes the exact stock key type and bytes.
    fn from(key: CometPublicKey) -> Self {
        use base64::Engine as _;
        Self {
            kind: "tendermint/PubKeySecp256k1eth".into(),
            value: base64::engine::general_purpose::STANDARD.encode(key.0.as_bytes()),
        }
    }
}
impl TryFrom<PublicKeyJson> for CometPublicKey {
    /// Invalid or unsupported key encoding.
    type Error = KeyError;
    /// Refuses old algorithms rather than substituting an Ethereum address for their identity.
    fn try_from(value: PublicKeyJson) -> Result<Self, Self::Error> {
        use base64::Engine as _;
        if value.kind != "tendermint/PubKeySecp256k1eth" {
            return Err(KeyError);
        }
        let bytes =
            base64::engine::general_purpose::STANDARD.decode(value.value).map_err(|_| KeyError)?;
        Ok(Self(ConsensusKey::from_slice(&bytes)?))
    }
}

#[cfg(test)]
mod protocol_vectors {
    use super::*;
    #[test]
    fn schema4_key_decompression_and_addresses() {
        for case in crate::test_utils::vectors::at("/key_decompression").as_array().unwrap() {
            let raw = alloy_primitives::hex::decode(case["public_key"].as_str().unwrap()).unwrap();
            let key = ConsensusKey::from_slice(&raw);
            assert_eq!(key.is_ok(), case["valid"].as_bool().unwrap(), "{}", case["name"]);
            if let Ok(key) = key {
                assert_eq!(
                    key.address(),
                    case["ck_addr"].as_str().unwrap().parse::<Address>().unwrap()
                );
                assert_eq!(key.as_bytes().as_slice(), raw);
            }
        }
    }
    #[test]
    fn schema4_stock_votes_verify_and_reject_mutations() {
        let v = crate::test_utils::vectors::at("/votes");
        let key = ConsensusKey::from_slice(
            &alloy_primitives::hex::decode(v["key"]["public_key"].as_str().unwrap()).unwrap(),
        )
        .unwrap();
        for case in v["cases"].as_array().unwrap() {
            let bytes =
                alloy_primitives::hex::decode(case["sign_bytes"].as_str().unwrap()).unwrap();
            let signature =
                alloy_primitives::hex::decode(case["signature"].as_str().unwrap()).unwrap();
            assert!(key.verify_signature(&bytes, &signature), "{}", case["name"]);
            let mut wrong = bytes.clone();
            wrong[0] ^= 1;
            assert!(!key.verify_signature(&wrong, &signature));
            let mut parity = signature.clone();
            parity[64] = 27;
            assert!(!key.verify_signature(&bytes, &parity));
            assert!(!key.verify_signature(&bytes, &signature[..64]));
            let order = alloy_primitives::U256::from_str_radix(
                "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141",
                16,
            )
            .unwrap();
            let s = alloy_primitives::U256::from_be_slice(&signature[32..64]);
            let mut high = signature.clone();
            high[32..64].copy_from_slice(&(order - s).to_be_bytes::<32>());
            high[64] ^= 1;
            assert!(!key.verify_signature(&bytes, &high));
        }
    }
}
