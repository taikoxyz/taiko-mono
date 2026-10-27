//! Deterministic native consensus keys and separate Ed25519 transport identities.

use abci::key::ConsensusKey;
use alloy_primitives::{B256, hex};
use base64::{Engine as _, engine::general_purpose::STANDARD};
use ed25519_dalek::SigningKey;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

/// Seed label of the validator (consensus) keys.
const VALIDATOR_LABEL: &str = "abci-devnet-validator";

/// Seed label of the CometBFT node (P2P) keys.
const NODE_LABEL: &str = "abci-devnet-node";

/// A deterministic secp256k1eth consensus key.
#[derive(Clone, Debug)]
pub struct ValidatorKey {
    /// The signing key.
    signing: k256::ecdsa::SigningKey,
}

impl ValidatorKey {
    /// A disposable validator from an explicitly supplied test seed.
    pub fn from_seed(seed: [u8; 32]) -> Self {
        Self {
            signing: k256::ecdsa::SigningKey::from_bytes((&seed).into())
                .expect("valid test scalar"),
        }
    }

    /// The key whose seed is `sha256(label ‖ be64(index))`.
    pub fn derive(label: &str, index: u64) -> Self {
        let mut hasher = Sha256::new();
        hasher.update(label.as_bytes());
        hasher.update(index.to_be_bytes());
        Self::from_seed(hasher.finalize().into())
    }

    /// The validated 33-byte native consensus public key.
    pub fn pubkey(&self) -> ConsensusKey {
        ConsensusKey::from_slice(self.signing.verifying_key().to_encoded_point(true).as_bytes())
            .expect("valid test key")
    }

    /// The deterministic nonzero L2 payout address used by the test registry planter.
    pub fn reward_recipient(&self) -> alloy_primitives::Address {
        self.pubkey().address()
    }

    /// The CometBFT validator address: upper-case hex of its Ethereum address.
    pub fn address(&self) -> String {
        abci::genesis::validator_address(self.pubkey())
    }

    /// `config/priv_validator_key.json`.
    pub fn priv_validator_key_json(&self) -> Value {
        json!({
            "address": self.address(),
            "pub_key": {
                "type": "tendermint/PubKeySecp256k1eth",
                "value": STANDARD.encode(self.pubkey().as_bytes()),
            },
            "priv_key": { "type": "tendermint/PrivKeySecp256k1eth", "value": STANDARD.encode(self.signing.to_bytes()) },
        })
    }
}

/// A separate deterministic Ed25519 P2P transport identity.
#[derive(Clone, Debug)]
pub struct NodeKey {
    signing: SigningKey,
}
impl NodeKey {
    /// Derives a transport-only seed.
    pub fn derive(label: &str, index: u64) -> Self {
        let mut hasher = Sha256::new();
        hasher.update(label.as_bytes());
        hasher.update(index.to_be_bytes());
        Self { signing: SigningKey::from_bytes(&hasher.finalize().into()) }
    }
    /// The transport public key.
    pub fn pubkey(&self) -> B256 {
        self.signing.verifying_key().to_bytes().into()
    }
    /// Lowercase stock Ed25519 node ID.
    pub fn node_id(&self) -> String {
        hex::encode(&Sha256::digest(self.pubkey())[..20])
    }
    /// Stock node identity file, never used to vote.
    pub fn node_key_json(&self) -> Value {
        json!({"priv_key":{"type":"tendermint/PrivKeyEd25519", "value":STANDARD.encode(self.signing.to_keypair_bytes())}})
    }
}

/// The first `n` validator (consensus) keys.
pub fn validator_keys(n: usize) -> Vec<ValidatorKey> {
    (0..n as u64).map(|i| ValidatorKey::derive(VALIDATOR_LABEL, i)).collect()
}

/// The first `n` CometBFT node (P2P) keys.
pub fn node_keys(n: usize) -> Vec<NodeKey> {
    (0..n as u64).map(|i| NodeKey::derive(NODE_LABEL, i)).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn keys_are_deterministic_and_distinct() {
        assert_eq!(validator_keys(2)[1].pubkey(), validator_keys(3)[1].pubkey());
        assert_ne!(validator_keys(2)[0].pubkey(), validator_keys(2)[1].pubkey());
        assert_eq!(node_keys(1)[0].pubkey().len(), 32);
    }

    #[test]
    fn key_files_follow_the_cometbft_encoding() {
        let key = &validator_keys(1)[0];
        let file = key.priv_validator_key_json();
        let private = STANDARD.decode(file["priv_key"]["value"].as_str().unwrap()).unwrap();
        assert_eq!(private.len(), 32);
        assert_eq!(file["pub_key"]["type"], "tendermint/PubKeySecp256k1eth");
        assert_eq!(
            STANDARD.decode(file["pub_key"]["value"].as_str().unwrap()).unwrap(),
            key.pubkey().as_bytes()
        );
        assert_eq!(file["address"], key.address());
        assert_eq!(key.address().len(), 40);
    }
}
