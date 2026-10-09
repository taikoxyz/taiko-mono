//! Deterministic Ed25519 keys and their CometBFT key files.

use alloy_primitives::{B256, hex};
use base64::{Engine as _, engine::general_purpose::STANDARD};
use ed25519_dalek::SigningKey;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

/// Seed label of the validator (consensus) keys.
const VALIDATOR_LABEL: &str = "abci-devnet-validator";

/// Seed label of the CometBFT node (P2P) keys.
const NODE_LABEL: &str = "abci-devnet-node";

/// A deterministic Ed25519 key.
#[derive(Clone, Debug)]
pub struct ValidatorKey {
    /// The signing key.
    signing: SigningKey,
}

impl ValidatorKey {
    /// The key whose seed is `sha256(label ‖ be64(index))`.
    pub fn derive(label: &str, index: u64) -> Self {
        let mut hasher = Sha256::new();
        hasher.update(label.as_bytes());
        hasher.update(index.to_be_bytes());
        Self { signing: SigningKey::from_bytes(&hasher.finalize().into()) }
    }

    /// The 32-byte public key.
    pub fn pubkey(&self) -> B256 {
        B256::from(self.signing.verifying_key().to_bytes())
    }

    /// The CometBFT validator address: upper-case hex of `sha256(pubkey)[..20]`.
    pub fn address(&self) -> String {
        abci::genesis::validator_address(self.pubkey())
    }

    /// The CometBFT node ID when used as a node key: lower-case hex of `sha256(pubkey)[..20]`.
    pub fn node_id(&self) -> String {
        hex::encode(&Sha256::digest(self.pubkey())[..20])
    }

    /// The base64 of `seed ‖ pubkey`, CometBFT's Ed25519 private key encoding.
    fn private_b64(&self) -> String {
        STANDARD.encode(self.signing.to_keypair_bytes())
    }

    /// `config/priv_validator_key.json`.
    pub fn priv_validator_key_json(&self) -> Value {
        json!({
            "address": self.address(),
            "pub_key": {
                "type": "tendermint/PubKeyEd25519",
                "value": STANDARD.encode(self.pubkey()),
            },
            "priv_key": { "type": "tendermint/PrivKeyEd25519", "value": self.private_b64() },
        })
    }

    /// `config/node_key.json`.
    pub fn node_key_json(&self) -> Value {
        json!({ "priv_key": { "type": "tendermint/PrivKeyEd25519", "value": self.private_b64() } })
    }
}

/// The first `n` validator (consensus) keys.
pub fn validator_keys(n: usize) -> Vec<ValidatorKey> {
    (0..n as u64).map(|i| ValidatorKey::derive(VALIDATOR_LABEL, i)).collect()
}

/// The first `n` CometBFT node (P2P) keys.
pub fn node_keys(n: usize) -> Vec<ValidatorKey> {
    (0..n as u64).map(|i| ValidatorKey::derive(NODE_LABEL, i)).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn keys_are_deterministic_and_distinct() {
        assert_eq!(validator_keys(2)[1].pubkey(), validator_keys(3)[1].pubkey());
        assert_ne!(validator_keys(2)[0].pubkey(), validator_keys(2)[1].pubkey());
        assert_ne!(validator_keys(1)[0].pubkey(), node_keys(1)[0].pubkey());
    }

    #[test]
    fn key_files_follow_the_cometbft_encoding() {
        let key = &validator_keys(1)[0];
        let file = key.priv_validator_key_json();
        let private = STANDARD.decode(file["priv_key"]["value"].as_str().unwrap()).unwrap();
        assert_eq!(private.len(), 64);
        assert_eq!(&private[32..], key.pubkey().as_slice());
        assert_eq!(file["address"], key.address());
        assert_eq!(key.address(), key.node_id().to_uppercase());
        assert_eq!(key.address().len(), 40);
    }
}
