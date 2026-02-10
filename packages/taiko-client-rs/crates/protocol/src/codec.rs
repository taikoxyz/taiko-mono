//! Codec utilities for protocol payloads.

use std::io::{Read, Write};

use alloy_rlp::{Bytes as RlpBytes, Decodable};
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
    /// The decompressed txlist exceeds the configured size cap.
    #[error("decompressed txlist exceeds max size: {actual} > {max}")]
    DecompressedTooLarge {
        /// Actual decompressed byte size.
        actual: usize,
        /// Maximum allowed decompressed byte size.
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
    max_compressed_txlist_bytes: usize,
    /// Maximum allowed decompressed txlist size.
    max_decompressed_txlist_bytes: usize,
}

impl ZlibTxListCodec {
    /// Build a zlib codec with matching compressed/decompressed size caps.
    pub fn new(max_txlist_bytes: usize) -> Self {
        Self::new_with_limits(max_txlist_bytes, max_txlist_bytes)
    }

    /// Build a zlib codec with explicit compressed/decompressed size caps.
    pub fn new_with_limits(
        max_compressed_txlist_bytes: usize,
        max_decompressed_txlist_bytes: usize,
    ) -> Self {
        Self { max_compressed_txlist_bytes, max_decompressed_txlist_bytes }
    }

    /// Encode a list of raw transactions into zlib-compressed bytes.
    pub fn encode(&self, transactions: &[Vec<u8>]) -> Result<Vec<u8>> {
        let mut rlp_encoded = Vec::new();
        // Encode tx-lists as an RLP list of byte strings (`types.Transactions`).
        alloy_rlp::encode_list::<_, [u8]>(transactions, &mut rlp_encoded);

        let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
        encoder.write_all(&rlp_encoded).map_err(|e| TxListCodecError::ZlibEncode(e.to_string()))?;
        let compressed =
            encoder.finish().map_err(|e| TxListCodecError::ZlibFinish(e.to_string()))?;

        if compressed.len() > self.max_compressed_txlist_bytes {
            return Err(TxListCodecError::CompressedTooLarge {
                actual: compressed.len(),
                max: self.max_compressed_txlist_bytes,
            });
        }

        Ok(compressed)
    }

    /// Decode compressed zlib bytes into a list of raw transactions.
    pub fn decode(&self, compressed: &[u8]) -> Result<Vec<Vec<u8>>> {
        if compressed.len() > self.max_compressed_txlist_bytes {
            return Err(TxListCodecError::CompressedTooLarge {
                actual: compressed.len(),
                max: self.max_compressed_txlist_bytes,
            });
        }

        let decoder = ZlibDecoder::new(compressed);
        let mut decoded = Vec::new();
        let read_cap = self.max_decompressed_txlist_bytes.saturating_add(1) as u64;
        decoder
            .take(read_cap)
            .read_to_end(&mut decoded)
            .map_err(|err| TxListCodecError::ZlibDecode(err.to_string()))?;

        if decoded.len() > self.max_decompressed_txlist_bytes {
            return Err(TxListCodecError::DecompressedTooLarge {
                actual: decoded.len(),
                max: self.max_decompressed_txlist_bytes,
            });
        }

        let mut payload = decoded.as_slice();
        Vec::<RlpBytes>::decode(&mut payload)
            .map(|txs| txs.into_iter().map(|tx| tx.to_vec()).collect())
            .map_err(|err| TxListCodecError::RlpDecode(err.to_string()))
    }
}

#[cfg(test)]
mod tests {
    use std::io::{Read, Write};

    use alloy_rlp::Bytes as RlpBytes;
    use flate2::{Compression, read::ZlibDecoder, write::ZlibEncoder};

    use super::ZlibTxListCodec;

    fn compress_payload(payload: &[u8]) -> Vec<u8> {
        let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
        encoder.write_all(payload).expect("write zlib payload");
        encoder.finish().expect("finish zlib encoding")
    }

    fn decompress_payload(payload: &[u8]) -> Vec<u8> {
        let mut decoder = ZlibDecoder::new(payload);
        let mut decoded = Vec::new();
        decoder.read_to_end(&mut decoded).expect("read zlib payload");
        decoded
    }

    #[test]
    fn txlist_codec_roundtrip_placeholder() {
        let rlp_payload = vec![0xC0];
        let compressed = compress_payload(&rlp_payload);

        let codec = ZlibTxListCodec::new(1024);
        let txs = codec.decode(&compressed).expect("decode txlist");
        assert!(txs.is_empty());
    }

    #[test]
    fn txlist_codec_rejects_oversized_decompressed_payload() {
        let oversized_decoded = vec![0u8; 2 * 1024 * 1024 + 1];
        let compressed = compress_payload(&oversized_decoded);

        let codec = ZlibTxListCodec::new(2 * 1024 * 1024);
        let err = codec
            .decode(&compressed)
            .expect_err("oversized decompressed payload must fail before rlp decode");
        assert!(err.to_string().contains("decompressed txlist exceeds max size"));
    }

    #[test]
    fn txlist_codec_decodes_go_style_rlp_transaction_byte_strings() {
        let tx = vec![
            0x02, 0xeb, 0x81, 0xa7, 0x80, 0x80, 0x84, 0x3b, 0x9a, 0xca, 0x00, 0x82, 0x52, 0x08,
            0x94, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
            0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x80, 0x84, 0x52, 0x3e, 0x68, 0x54, 0xc0, 0x80,
            0x80, 0x80,
        ];
        let mut rlp_encoded = Vec::new();
        alloy_rlp::encode_list::<_, RlpBytes>(&[RlpBytes::from(tx.clone())], &mut rlp_encoded);
        let compressed = compress_payload(&rlp_encoded);

        let codec = ZlibTxListCodec::new(1024);
        let decoded =
            codec.decode(&compressed).expect("go-style tx-list should decode successfully");
        assert_eq!(decoded, vec![tx]);
    }

    #[test]
    fn txlist_codec_rejects_legacy_rust_list_of_u8_encoding() {
        let tx = vec![
            0x02, 0xeb, 0x81, 0xa7, 0x80, 0x80, 0x84, 0x3b, 0x9a, 0xca, 0x00, 0x82, 0x52, 0x08,
            0x94, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
            0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x80, 0x84, 0x52, 0x3e, 0x68, 0x54, 0xc0, 0x80,
            0x80, 0x80,
        ];
        let mut rlp_encoded = Vec::new();
        alloy_rlp::encode_list::<_, Vec<u8>>(&[tx.clone()], &mut rlp_encoded);
        let compressed = compress_payload(&rlp_encoded);

        let codec = ZlibTxListCodec::new(1024);
        let err =
            codec.decode(&compressed).expect_err("legacy rust tx-list encoding should be rejected");
        assert!(matches!(err, super::TxListCodecError::RlpDecode(_)));
    }

    #[test]
    fn txlist_codec_encodes_go_style_rlp_transaction_byte_strings() {
        let tx = vec![
            0x02, 0xeb, 0x81, 0xa7, 0x80, 0x80, 0x84, 0x3b, 0x9a, 0xca, 0x00, 0x82, 0x52, 0x08,
            0x94, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
            0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x80, 0x84, 0x52, 0x3e, 0x68, 0x54, 0xc0, 0x80,
            0x80, 0x80,
        ];
        let codec = ZlibTxListCodec::new(1024);

        let compressed = codec.encode(&[tx.clone()]).expect("encode tx-list");
        let decoded = decompress_payload(&compressed);

        let mut expected_rlp = Vec::new();
        alloy_rlp::encode_list::<_, RlpBytes>(&[RlpBytes::from(tx)], &mut expected_rlp);
        assert_eq!(decoded, expected_rlp);
    }
}
