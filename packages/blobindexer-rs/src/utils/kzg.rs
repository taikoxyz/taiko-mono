use alloy_primitives::{B256, FixedBytes};
use sha2::{Digest, Sha256};

/// Convert a KZG commitment into an EIP-4844 versioned hash.
pub fn kzg_to_versioned_hash(commitment: &FixedBytes<48>) -> B256 {
    const VERSION: u8 = 0x01;
    let mut hasher = Sha256::new();
    hasher.update(commitment.as_slice());
    let digest = hasher.finalize();
    let mut bytes = [0u8; 32];
    bytes.copy_from_slice(&digest[..32]);
    bytes[0] = VERSION;
    B256::from(bytes)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn versioned_hash_prefix_set() {
        let commitment = FixedBytes::<48>::from([0xAB; 48]);
        let hash = kzg_to_versioned_hash(&commitment);
        assert_eq!(hash.as_slice()[0], 0x01);
    }
}
