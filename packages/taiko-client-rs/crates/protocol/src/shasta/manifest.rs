//! Manifest types for encoding block proposals and metadata.

use std::{
    convert::TryFrom,
    io::{Read, Write},
};

use alloy::primitives::{Address, Bytes, U256};
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
        let Some(decoded) = decode_manifest_payload(bytes, offset)? else {
            return Ok(DerivationSourceManifest::default());
        };

        let mut decoded_slice = decoded.as_slice();
        let mut manifest = <DerivationSourceManifest as Decodable>::decode(&mut decoded_slice)
            .map_err(|err| ProtocolError::Rlp(err.to_string()))?;

        if manifest.blocks.len() > PROPOSAL_MAX_BLOCKS {
            return Ok(DerivationSourceManifest::default());
        }

        // For all forced-inclusion blocks, we override the gas limit and anchor block number to 0.
        for block in manifest.blocks.iter_mut() {
            block.gas_limit = 0;
            block.anchor_block_number = 0;
            block.timestamp = 0;
            block.coinbase = Address::ZERO;
        }

        Ok(manifest)
    }
}

/// Manifest for a proposal, matching `LibManifest.ProtocolProposalManifest`.
#[derive(Debug, Clone, Serialize, Deserialize, RlpEncodable, RlpDecodable)]
#[serde(rename_all = "camelCase")]
pub struct ProposalManifest {
    /// Raw prover authentication payload.
    #[serde(default)]
    pub prover_auth_bytes: Bytes,
    /// Derivation sources included in this proposal.
    #[serde(default)]
    pub sources: Vec<DerivationSourceManifest>,
}

impl Default for ProposalManifest {
    /// Create the default proposal manifest.
    fn default() -> Self {
        Self { prover_auth_bytes: Bytes::new(), sources: vec![DerivationSourceManifest::default()] }
    }
}

impl ProposalManifest {
    /// Encode and compress the protocol proposal manifest following the Shasta protocol payload
    /// format. Ref: https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/docs/Derivation.md
    pub fn encode_and_compress(&self) -> Result<Vec<u8>> {
        encode_manifest_payload(self)
    }

    /// Decompress and decode a protocol proposal manifest from the Shasta protocol payload bytes.
    /// Ref: https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/docs/Derivation.md
    pub fn decompress_and_decode(bytes: &[u8], offset: usize) -> Result<Self> {
        let Some(decoded) = decode_manifest_payload(bytes, offset)? else {
            return Ok(ProposalManifest::default());
        };

        let mut decoded_slice = decoded.as_slice();
        let manifest = <ProposalManifest as Decodable>::decode(&mut decoded_slice)
            .map_err(|err| ProtocolError::Rlp(err.to_string()))?;

        if manifest.sources.len() > PROPOSAL_MAX_BLOCKS {
            return Ok(ProposalManifest::default());
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
fn decode_manifest_payload(bytes: &[u8], offset: usize) -> Result<Option<Vec<u8>>> {
    if bytes.len() < offset + 64 {
        return Ok(None);
    }

    let version_raw = U256::from_be_slice(&bytes[offset..offset + 32]);
    let Ok(version) = u32::try_from(version_raw) else {
        return Ok(None);
    };
    if version != SHASTA_PAYLOAD_VERSION as u32 {
        return Ok(None);
    }

    let size_raw = U256::from_be_slice(&bytes[offset + 32..offset + 64]);
    let Ok(size_u64) = u64::try_from(size_raw) else {
        return Ok(None);
    };
    let Ok(size) = usize::try_from(size_u64) else {
        return Ok(None);
    };

    if bytes.len() < offset + 64 + size {
        return Ok(None);
    }

    let compressed = &bytes[offset + 64..offset + 64 + size];
    let mut decoder = ZlibDecoder::new(compressed);
    let mut decoded = Vec::new();
    if decoder.read_to_end(&mut decoded).is_err() {
        return Ok(None);
    }

    Ok(Some(decoded))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_decode_manifest_payload_version_mismatch() {
        let mut payload = vec![0u8; 64];
        payload[31] = SHASTA_PAYLOAD_VERSION + 1;

        let decoded = decode_manifest_payload(&payload, 0).unwrap();
        assert!(decoded.is_none());
    }

    #[test]
    fn test_decode_manifest_payload_size_too_large() {
        let mut payload = vec![0u8; 64];
        payload[31] = SHASTA_PAYLOAD_VERSION;
        // size_raw > u64::MAX should yield None.
        payload[32] = 1;

        let decoded = decode_manifest_payload(&payload, 0).unwrap();
        assert!(decoded.is_none());
    }

    #[test]
    fn test_decode_manifest_payload_invalid_compression() {
        let mut payload = vec![0u8; 66];
        payload[31] = SHASTA_PAYLOAD_VERSION;
        payload[63] = 2; // size = 2 (big endian in last byte)
        payload[64] = 0x78;
        payload[65] = 0x00; // truncated zlib stream

        let decoded = decode_manifest_payload(&payload, 0).unwrap();
        assert!(decoded.is_none());
    }

    #[test]
    fn test_proposal_manifest_decode_invalid_rlp() {
        use flate2::{Compression, write::ZlibEncoder};

        let invalid_body = [0xFF, 0x00, 0x01];
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

        assert!(ProposalManifest::decompress_and_decode(&payload, 0).is_err());
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

        assert!(DerivationSourceManifest::decompress_and_decode(&payload, 0).is_err());
    }

    #[test]
    fn test_proposal_manifest_encode_decode() {
        let manifest = ProposalManifest::default();
        let encoded = manifest.encode_and_compress().unwrap();

        assert!(encoded.len() >= 64);
        assert_eq!(encoded[31], SHASTA_PAYLOAD_VERSION,);

        for i in 0..31 {
            assert_eq!(encoded[i], 0);
        }

        let decoded = ProposalManifest::decompress_and_decode(&encoded, 0).unwrap();
        assert_eq!(decoded.prover_auth_bytes, manifest.prover_auth_bytes);
        assert_eq!(decoded.sources.len(), manifest.sources.len());
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
