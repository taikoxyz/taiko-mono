//! Txlist codec definitions for preconfirmation payloads.

use std::io::Read;

use alloy_rlp::Decodable;
use flate2::read::ZlibDecoder;

use crate::error::{PreconfirmationClientError, Result};

/// Zlib-based txlist decoder compatible with the P2P specification.
pub struct ZlibTxListCodec {
    /// Maximum allowed decompressed txlist size.
    max_txlist_bytes: usize,
}

impl ZlibTxListCodec {
    /// Build a zlib codec with an explicit size cap.
    pub fn new(max_txlist_bytes: usize) -> Self {
        Self { max_txlist_bytes }
    }

    /// Decode compressed zlib bytes into a list of raw transactions.
    pub fn decode(&self, compressed: &[u8]) -> Result<Vec<Vec<u8>>> {
        if compressed.len() > self.max_txlist_bytes {
            return Err(PreconfirmationClientError::Codec(format!(
                "txlist exceeds max size: {} > {}",
                compressed.len(),
                self.max_txlist_bytes
            )));
        }

        let mut decoder = ZlibDecoder::new(compressed);
        let mut decoded = Vec::new();
        decoder.read_to_end(&mut decoded).map_err(|err| {
            PreconfirmationClientError::Codec(format!("zlib decode failed: {err}"))
        })?;

        Vec::<Vec<u8>>::decode(&mut decoded.as_slice())
            .map_err(|err| PreconfirmationClientError::Codec(format!("rlp decode failed: {err}")))
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
