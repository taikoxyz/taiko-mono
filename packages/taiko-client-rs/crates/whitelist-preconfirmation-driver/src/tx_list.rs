//! Shared transaction-list limits and decompression helpers.

use std::io::Read;

use flate2::read::ZlibDecoder;

use crate::{Result, error::WhitelistPreconfirmationDriverError};

/// Maximum compressed tx-list size accepted from a preconfirmation payload.
pub(crate) const MAX_COMPRESSED_TX_LIST_BYTES: usize = 131_072 * 6;
/// Maximum decompressed tx-list size accepted from a preconfirmation payload.
///
/// Align with the preconfirmation tx-list cap to avoid zlib bomb expansion on untrusted payloads.
pub(crate) const MAX_DECOMPRESSED_TX_LIST_BYTES: usize = 8 * 1024 * 1024;

/// Decompress a zlib-compressed transaction list while enforcing size limits.
pub(crate) fn decompress_tx_list(bytes: &[u8]) -> Result<Vec<u8>> {
    if bytes.len() > MAX_COMPRESSED_TX_LIST_BYTES {
        return Err(WhitelistPreconfirmationDriverError::invalid_payload(format!(
            "compressed tx list exceeds maximum size: {} > {}",
            bytes.len(),
            MAX_COMPRESSED_TX_LIST_BYTES
        )));
    }

    let decoder = ZlibDecoder::new(bytes);
    let mut out = Vec::new();
    let read_cap = MAX_DECOMPRESSED_TX_LIST_BYTES.saturating_add(1) as u64;
    decoder.take(read_cap).read_to_end(&mut out).map_err(|err| {
        WhitelistPreconfirmationDriverError::invalid_payload_with_context(
            "failed to decompress tx list from payload",
            err,
        )
    })?;

    if out.len() > MAX_DECOMPRESSED_TX_LIST_BYTES {
        return Err(WhitelistPreconfirmationDriverError::invalid_payload(format!(
            "decompressed tx list exceeds maximum size: {} > {}",
            out.len(),
            MAX_DECOMPRESSED_TX_LIST_BYTES
        )));
    }

    if out.is_empty() {
        return Err(WhitelistPreconfirmationDriverError::invalid_payload(
            "decompressed tx list is empty",
        ));
    }

    Ok(out)
}
