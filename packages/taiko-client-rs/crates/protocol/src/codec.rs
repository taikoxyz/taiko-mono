//! Codec utilities for protocol payloads.

use std::io::{Read, Write};

use alloy_rlp::Decodable;
use flate2::{Compression, read::ZlibDecoder, write::ZlibEncoder};
use thiserror::Error;

/// Errors raised while encoding or decoding txlist payloads.
#[derive(Debug, Error)]
pub enum TxListCodecError {
    /// The compressed txlist exceeds the configured size cap.
    #[error("compressed txlist exceeds max size: {actual} > {max}")]
    CompressedTooLarge {
        /// Actual compressed byte size.
        actual: usize,
        /// Maximum allowed compressed byte size.
        max: usize,
    },
    /// Failed to write zlib-compressed bytes.
    #[error("zlib encode failed: {0}")]
    ZlibEncode(String),
    /// Failed to finish the zlib encoder.
    #[error("zlib finish failed: {0}")]
    ZlibFinish(String),
    /// Failed to decode zlib-compressed bytes.
    #[error("zlib decode failed: {0}")]
    ZlibDecode(String),
    /// Failed to decode the RLP transaction list.
    #[error("rlp decode failed: {0}")]
    RlpDecode(String),
}

/// Result alias for txlist codec operations.
pub type Result<T> = std::result::Result<T, TxListCodecError>;

/// Zlib-based txlist decoder compatible with the P2P specification.
pub struct ZlibTxListCodec {
    /// Maximum allowed compressed txlist size.
    max_txlist_bytes: usize,
}

impl ZlibTxListCodec {
    /// Build a zlib codec with an explicit size cap.
    pub fn new(max_txlist_bytes: usize) -> Self {
        Self { max_txlist_bytes }
    }

    /// Encode a list of raw transactions into zlib-compressed bytes.
    pub fn encode(&self, transactions: &[Vec<u8>]) -> Result<Vec<u8>> {
        let mut rlp_encoded = Vec::new();
        alloy_rlp::encode_list::<_, Vec<u8>>(transactions, &mut rlp_encoded);

        let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
        encoder.write_all(&rlp_encoded).map_err(|e| TxListCodecError::ZlibEncode(e.to_string()))?;
        let compressed =
            encoder.finish().map_err(|e| TxListCodecError::ZlibFinish(e.to_string()))?;

        if compressed.len() > self.max_txlist_bytes {
            return Err(TxListCodecError::CompressedTooLarge {
                actual: compressed.len(),
                max: self.max_txlist_bytes,
            });
        }

        Ok(compressed)
    }

    /// Decode compressed zlib bytes into a list of raw transactions.
    pub fn decode(&self, compressed: &[u8]) -> Result<Vec<Vec<u8>>> {
        if compressed.len() > self.max_txlist_bytes {
            return Err(TxListCodecError::CompressedTooLarge {
                actual: compressed.len(),
                max: self.max_txlist_bytes,
            });
        }

        let mut decoder = ZlibDecoder::new(compressed);
        let mut decoded = Vec::new();
        decoder
            .read_to_end(&mut decoded)
            .map_err(|err| TxListCodecError::ZlibDecode(err.to_string()))?;

        Vec::<Vec<u8>>::decode(&mut decoded.as_slice())
            .map_err(|err| TxListCodecError::RlpDecode(err.to_string()))
    }
}

#[cfg(test)]
mod tests {
    use std::io::Write;

    use flate2::{Compression, write::ZlibEncoder};

    use super::ZlibTxListCodec;

    #[test]
    fn txlist_codec_roundtrip_placeholder() {
        let rlp_payload = vec![0xC0];
        let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
        encoder.write_all(&rlp_payload).expect("write rlp payload");
        let compressed = encoder.finish().expect("finish zlib encoding");

        let codec = ZlibTxListCodec::new(1024);
        let txs = codec.decode(&compressed).expect("decode txlist");
        assert!(txs.is_empty());
    }
}
