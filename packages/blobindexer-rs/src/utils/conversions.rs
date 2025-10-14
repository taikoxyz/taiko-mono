use alloy_primitives::{B256, FixedBytes};
use hex::FromHex;

use crate::errors::{BlobIndexerError, Result};

/// Decode a hex string with optional 0x prefix into bytes.
pub fn decode_hex_bytes(value: &str) -> Result<Vec<u8>> {
    let value = value.strip_prefix("0x").unwrap_or(value);
    let bytes = Vec::from_hex(value)
        .map_err(|err| BlobIndexerError::InvalidData(format!("invalid hex: {err}")))?;
    Ok(bytes)
}

/// Decode a hex string into a fixed 32-byte hash.
pub fn decode_b256(value: &str) -> Result<B256> {
    let bytes = decode_hex_bytes(value)?;
    Ok(B256::from_slice(&bytes))
}

/// Decode a hex string into a fixed number of bytes.
pub fn decode_fixed_bytes<const N: usize>(value: &str) -> Result<FixedBytes<N>> {
    let bytes = decode_hex_bytes(value)?;
    if bytes.len() != N {
        return Err(BlobIndexerError::InvalidData(format!(
            "expected {N} bytes but got {}",
            bytes.len()
        )));
    }
    Ok(FixedBytes::<N>::from_slice(&bytes))
}

/// Encode bytes into a 0x-prefixed hex string.
pub fn encode_hex_bytes(bytes: &[u8]) -> String {
    format!("0x{}", hex::encode(bytes))
}

/// Encode B256 into 0x-prefixed hex string.
pub fn encode_b256(hash: &B256) -> String {
    encode_hex_bytes(hash.as_slice())
}
