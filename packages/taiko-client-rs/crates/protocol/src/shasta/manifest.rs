//! Manifest types for encoding block proposals and metadata.

use std::{
    convert::TryFrom,
    io::{Read, Write},
};

use alloy::primitives::{Address, U256};
use alloy_consensus::TxEnvelope;
use alloy_rlp::{self, Decodable, Encodable, RlpDecodable, RlpEncodable};
use flate2::{Compression, read::ZlibDecoder, write::ZlibEncoder};
use serde::{Deserialize, Serialize};

use crate::shasta::{
    constants::{PROPOSAL_MAX_BLOCKS, SHASTA_PAYLOAD_VERSION},
    error::{ProtocolError, Result},
};

/// Manifest of a single block proposal, matching `LibManifest.ProtocolBlockManifest`.
#[derive(Debug, Clone, Serialize, Deserialize, Default, RlpEncodable, RlpDecodable)]
#[serde(rename_all = "camelCase")]
pub struct BlockManifest {
    /// The timestamp of the block.
    pub timestamp: u64,
    /// The block coinbase.
    pub coinbase: Address,
    /// The anchor block number used for derivation.
    pub anchor_block_number: u64,
    /// The block gas limit.
    pub gas_limit: u64,
    /// Transactions that make up the block.
    #[serde(default)]
    pub transactions: Vec<TxEnvelope>,
}

/// Manifest for a derivation source, matching `LibManifest.DerivationSourceManifest`.
#[derive(Debug, Clone, Serialize, Deserialize, RlpEncodable, RlpDecodable)]
#[serde(rename_all = "camelCase")]
pub struct DerivationSourceManifest {
    /// Blocks included in this source.
    pub blocks: Vec<BlockManifest>,
}

impl Default for DerivationSourceManifest {
    /// Create the default derivation source manifest.
    fn default() -> Self {
        Self { blocks: vec![BlockManifest::default()] }
    }
}

impl DerivationSourceManifest {
    /// Encode and compress the derivation source manifest following the Shasta protocol payload
    /// format. Ref: https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/docs/Derivation.md
    pub fn encode_and_compress(&self) -> Result<Vec<u8>> {
        encode_manifest_payload(self)
    }

    /// Decompress and decode a derivation source manifest from the Shasta protocol payload bytes.
    /// Ref: https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/docs/Derivation.md
    pub fn decompress_and_decode(bytes: &[u8], offset: usize) -> Result<Self> {
        let decoded = decode_manifest_payload(bytes, offset)?;

        let mut decoded_slice = decoded.as_slice();
        let manifest = <DerivationSourceManifest as Decodable>::decode(&mut decoded_slice)
            .map_err(|err| {
                ProtocolError::Rlp(format!("failed to decode derivation manifest: {err}"))
            })?;

        if manifest.blocks.len() > PROPOSAL_MAX_BLOCKS {
            return Err(ProtocolError::InvalidPayload(format!(
                "manifest contains too many blocks: {} exceeds maximum {}",
                manifest.blocks.len(),
                PROPOSAL_MAX_BLOCKS
            )));
        }

        Ok(manifest)
    }
}

/// Encode a manifest into the Shasta protocol payload format.
fn encode_manifest_payload<T>(manifest: &T) -> Result<Vec<u8>>
where
    T: Encodable,
{
    let rlp_encoded = alloy_rlp::encode(manifest);

    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(&rlp_encoded)?;
    let compressed = encoder.finish()?;

    let mut output = Vec::with_capacity(64 + compressed.len());

    let mut version_bytes = [0u8; 32];
    version_bytes[31] = SHASTA_PAYLOAD_VERSION;
    output.extend_from_slice(&version_bytes);

    let len_bytes = U256::from(compressed.len()).to_be_bytes::<32>();
    output.extend_from_slice(&len_bytes);
    output.extend_from_slice(&compressed);

    Ok(output)
}

/// Decode a manifest from the Shasta protocol payload format.
fn decode_manifest_payload(bytes: &[u8], offset: usize) -> Result<Vec<u8>> {
    if bytes.len() < offset + 64 {
        return Err(ProtocolError::InvalidPayload(format!(
            "payload too short for header: expected at least {} bytes, got {}",
            offset + 64,
            bytes.len()
        )));
    }

    let version_raw = U256::from_be_slice(&bytes[offset..offset + 32]);
    let version = u32::try_from(version_raw).map_err(|_| {
        ProtocolError::InvalidPayload(format!("version field exceeds u32 range: {version_raw}"))
    })?;
    if version != SHASTA_PAYLOAD_VERSION as u32 {
        return Err(ProtocolError::InvalidPayload(format!(
            "unsupported payload version: expected {}, got {version}",
            SHASTA_PAYLOAD_VERSION
        )));
    }

    let size_raw = U256::from_be_slice(&bytes[offset + 32..offset + 64]);
    let size_u64 = u64::try_from(size_raw).map_err(|_| {
        ProtocolError::InvalidPayload(format!("size field exceeds u64 range: {size_raw}"))
    })?;
    let size = usize::try_from(size_u64).map_err(|_| {
        ProtocolError::InvalidPayload(format!("size field exceeds usize range: {size_u64}"))
    })?;

    if bytes.len() < offset + 64 + size {
        return Err(ProtocolError::InvalidPayload(format!(
            "payload too short for compressed data: expected {} bytes, got {}",
            offset + 64 + size,
            bytes.len()
        )));
    }

    let compressed = &bytes[offset + 64..offset + 64 + size];
    let mut decoder = ZlibDecoder::new(compressed);
    let mut decoded = Vec::new();
    decoder
        .read_to_end(&mut decoded)
        .map_err(|e| ProtocolError::Compression(format!("failed to decompress zlib data: {e}")))?;

    Ok(decoded)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_decode_manifest_payload_too_short() {
        let payload = vec![0u8; 32];

        let result = decode_manifest_payload(&payload, 0);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("payload too short for header"));
    }

    #[test]
    fn test_decode_manifest_payload_version_mismatch() {
        let mut payload = vec![0u8; 64];
        payload[31] = SHASTA_PAYLOAD_VERSION + 1;

        let result = decode_manifest_payload(&payload, 0);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("unsupported payload version"));
    }

    #[test]
    fn test_decode_manifest_payload_size_too_large() {
        let mut payload = vec![0u8; 64];
        payload[31] = SHASTA_PAYLOAD_VERSION;
        // size_raw > u64::MAX should yield error.
        payload[32] = 1;

        let result = decode_manifest_payload(&payload, 0);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("size field exceeds u64 range"));
    }

    #[test]
    fn test_decode_manifest_payload_invalid_compression() {
        let mut payload = vec![0u8; 66];
        payload[31] = SHASTA_PAYLOAD_VERSION;
        payload[63] = 2; // size = 2 (big endian in last byte)
        payload[64] = 0x78;
        payload[65] = 0x00; // truncated zlib stream

        let result = decode_manifest_payload(&payload, 0);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("failed to decompress zlib data"));
    }

    #[test]
    fn test_derivation_manifest_decode_invalid_rlp() {
        use flate2::{Compression, write::ZlibEncoder};

        let invalid_body = [0x80, 0x81, 0xFF];
        let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
        encoder.write_all(&invalid_body).unwrap();
        let compressed = encoder.finish().unwrap();

        let mut payload = Vec::with_capacity(64 + compressed.len());
        let mut version_bytes = [0u8; 32];
        version_bytes[31] = SHASTA_PAYLOAD_VERSION;
        payload.extend_from_slice(&version_bytes);

        let len_bytes = U256::from(compressed.len()).to_be_bytes::<32>();
        payload.extend_from_slice(&len_bytes);
        payload.extend_from_slice(&compressed);

        let result = DerivationSourceManifest::decompress_and_decode(&payload, 0);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("failed to decode derivation manifest"));
    }

    #[test]
    fn test_derivation_source_manifest_encode_decode() {
        let manifest = DerivationSourceManifest::default();
        let encoded = manifest.encode_and_compress().unwrap();

        assert!(encoded.len() >= 64);
        assert_eq!(encoded[31], SHASTA_PAYLOAD_VERSION);

        let decoded = DerivationSourceManifest::decompress_and_decode(&encoded, 0).unwrap();
        assert_eq!(decoded.blocks.len(), manifest.blocks.len());
    }
}
