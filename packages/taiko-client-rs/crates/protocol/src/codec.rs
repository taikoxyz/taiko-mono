//! Codec utilities for protocol payloads.

use std::io::{Read, Write};

use alloy_rlp::{Encodable, Header};
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
    ///
    /// Each transaction must be in its canonical EIP-2718 network encoding. Legacy
    /// (type-0) transactions are already RLP lists and are emitted verbatim, while
    /// typed transactions are wrapped as RLP byte strings, matching go-ethereum's
    /// `types.Transactions` encoding so tx-lists round-trip across clients.
    pub fn encode(&self, transactions: &[Vec<u8>]) -> Result<Vec<u8>> {
        let rlp_encoded = encode_transaction_list(transactions);

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

        decode_transaction_list(&decoded)
    }
}

/// Returns `true` when `tx` is a legacy (type-0) transaction, i.e. a bare RLP list
/// rather than an EIP-2718 typed transaction (`type || payload`). Legacy encodings
/// begin with an RLP list header (`>= 0xc0`); typed encodings begin with the type
/// byte (`< 0x80`).
fn is_legacy_transaction(tx: &[u8]) -> bool {
    tx.first().is_some_and(|first| *first >= 0xc0)
}

/// Encode transactions as an RLP list, matching go-ethereum's `types.Transactions`:
/// legacy transactions (already RLP lists) are written verbatim, typed transactions
/// are wrapped as RLP byte strings.
fn encode_transaction_list(transactions: &[Vec<u8>]) -> Vec<u8> {
    let mut payload = Vec::new();
    for tx in transactions {
        if is_legacy_transaction(tx) {
            payload.extend_from_slice(tx);
        } else {
            tx.as_slice().encode(&mut payload);
        }
    }

    let mut out = Vec::new();
    Header { list: true, payload_length: payload.len() }.encode(&mut out);
    out.extend_from_slice(&payload);
    out
}

/// Decode an RLP list of transactions, accepting both typed (byte string) and legacy
/// (list) elements, and returning each transaction's canonical EIP-2718 network
/// encoding. Mirrors go-ethereum's `types.Transactions` decoding; the previous
/// `Vec::<Bytes>` decode rejected legacy transactions with an "unexpected list"
/// error, which stalled real-time preconfirmation import.
fn decode_transaction_list(decoded: &[u8]) -> Result<Vec<Vec<u8>>> {
    let mut buf = decoded;
    let header =
        Header::decode(&mut buf).map_err(|err| TxListCodecError::RlpDecode(err.to_string()))?;
    if !header.list {
        return Err(TxListCodecError::RlpDecode("expected an RLP list of transactions".to_string()));
    }
    if buf.len() < header.payload_length {
        return Err(TxListCodecError::RlpDecode("transaction list payload truncated".to_string()));
    }

    let mut payload = &buf[..header.payload_length];
    let mut transactions = Vec::new();
    while !payload.is_empty() {
        let mut cursor = payload;
        let element = Header::decode(&mut cursor)
            .map_err(|err| TxListCodecError::RlpDecode(err.to_string()))?;
        let header_len = payload.len() - cursor.len();
        let element_len = header_len + element.payload_length;
        if element_len > payload.len() {
            return Err(TxListCodecError::RlpDecode(
                "transaction element overruns list payload".to_string(),
            ));
        }

        let (raw, rest) = payload.split_at(element_len);
        if element.list {
            // Legacy transaction: its canonical encoding is the RLP list itself.
            transactions.push(raw.to_vec());
        } else {
            // Typed transaction: strip the byte-string header to recover `type || payload`.
            transactions.push(raw[header_len..].to_vec());
        }
        payload = rest;
    }

    Ok(transactions)
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
    fn txlist_codec_roundtrips_mixed_legacy_and_typed_transactions() {
        let typed = vec![
            0x02, 0xeb, 0x81, 0xa7, 0x80, 0x80, 0x84, 0x3b, 0x9a, 0xca, 0x00, 0x82, 0x52, 0x08,
            0x94, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
            0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x80, 0x84, 0x52, 0x3e, 0x68, 0x54, 0xc0, 0x80,
            0x80, 0x80,
        ];
        let legacy = sample_legacy_transaction();

        let codec = ZlibTxListCodec::new(4096);
        let compressed =
            codec.encode(&[legacy.clone(), typed.clone()]).expect("encode mixed tx-list");
        let decoded = codec.decode(&compressed).expect("decode mixed tx-list");

        // Order is preserved and both transaction forms survive the round trip.
        assert_eq!(decoded, vec![legacy, typed]);
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

        let compressed = codec.encode(std::slice::from_ref(&tx)).expect("encode tx-list");
        let decoded = decompress_payload(&compressed);

        let mut expected_rlp = Vec::new();
        alloy_rlp::encode_list::<_, RlpBytes>(&[RlpBytes::from(tx)], &mut expected_rlp);
        assert_eq!(decoded, expected_rlp);
    }

    /// A legacy (type-0) transaction is RLP-encoded as a 9-field list with no type
    /// prefix. Build one by hand so the codec test stays independent of tx-signing
    /// helpers; the exact field values are irrelevant to the list codec.
    fn sample_legacy_transaction() -> Vec<u8> {
        use alloy_rlp::Encodable;
        let fields: [&[u8]; 9] = [
            &[0x01],                                           // nonce
            &[0x04, 0xa8, 0x17, 0xc8, 0x00],                   // gas price
            &[0x52, 0x08],                                     // gas limit
            &[0x11u8; 20],                                     // to
            &[0x0d, 0xe0, 0xb6, 0xb3, 0xa7, 0x64, 0x00, 0x00], // value
            &[],                                               // data
            &[0x1c],                                           // v
            &[0x22u8; 32],                                     // r
            &[0x33u8; 32],                                     // s
        ];
        let mut payload = Vec::new();
        for field in fields {
            field.encode(&mut payload);
        }
        let mut out = Vec::new();
        alloy_rlp::Header { list: true, payload_length: payload.len() }.encode(&mut out);
        out.extend_from_slice(&payload);
        out
    }

    #[test]
    fn txlist_codec_decodes_legacy_transaction_list() {
        let legacy = sample_legacy_transaction();

        // Go-style tx list: a legacy transaction is emitted as its RLP list verbatim.
        let mut rlp_encoded = Vec::new();
        alloy_rlp::Header { list: true, payload_length: legacy.len() }.encode(&mut rlp_encoded);
        rlp_encoded.extend_from_slice(&legacy);
        let compressed = compress_payload(&rlp_encoded);

        let codec = ZlibTxListCodec::new(1024);
        let decoded = codec.decode(&compressed).expect("legacy tx-list should decode successfully");
        assert_eq!(decoded, vec![legacy]);
    }
}
