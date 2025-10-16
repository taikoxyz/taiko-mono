//! Manifest types for encoding block proposals and metadata.

use std::io::{Read, Write};

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
        return Err(ProtocolError::InvalidPayload("blob payload shorter than header".into()));
    }

    let version = u32::from_be_bytes(
        bytes[offset + 28..offset + 32]
            .try_into()
            .map_err(|_| ProtocolError::InvalidPayload("malformed manifest version".into()))?,
    );
    if version != SHASTA_PAYLOAD_VERSION as u32 {
        return Ok(None);
    }

    let size = u64::from_be_bytes(
        bytes[offset + 56..offset + 64]
            .try_into()
            .map_err(|_| ProtocolError::InvalidPayload("malformed manifest size".into()))?,
    ) as usize;

    if bytes.len() < offset + 64 + size {
        return Err(ProtocolError::InvalidPayload(
            "blob payload shorter than declared size".into(),
        ));
    }

    let compressed = &bytes[offset + 64..offset + 64 + size];
    let mut decoder = ZlibDecoder::new(compressed);
    let mut decoded = Vec::new();
    decoder.read_to_end(&mut decoded).map_err(|err| ProtocolError::Compression(err.to_string()))?;

    Ok(Some(decoded))
}

#[cfg(test)]
mod tests {
    use super::*;

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
