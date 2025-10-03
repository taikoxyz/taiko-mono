use std::io::Write;

use alloy::primitives::{Address, Bytes, U256};
use alloy_consensus::TxEnvelope;
use alloy_rlp::{self, RlpDecodable, RlpEncodable};
use anyhow::Result;
use flate2::{Compression, write::ZlibEncoder};
use serde::{Deserialize, Serialize};

use crate::shasta::constants::SHASTA_PAYLOAD_VERSION;

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

/// Manifest for a proposal, matching `LibManifest.ProtocolProposalManifest`.
#[derive(Debug, Clone, Serialize, Deserialize, Default, RlpEncodable, RlpDecodable)]
#[serde(rename_all = "camelCase")]
pub struct ProposalManifest {
    /// Raw prover authentication payload.
    #[serde(default)]
    pub prover_auth_bytes: Bytes,
    /// Blocks bundled in this proposal.
    #[serde(default)]
    pub blocks: Vec<BlockManifest>,
}

impl ProposalManifest {
    /// Encode the protocol proposal manifest following the Shasta protocol payload format.
    /// Ref: https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/docs/Derivation.md
    pub fn encode(&self) -> Result<Vec<u8>> {
        let rlp_encoded = alloy_rlp::encode(self);

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
}
