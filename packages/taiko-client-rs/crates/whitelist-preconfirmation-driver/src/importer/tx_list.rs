use std::io::Read;

use flate2::read::ZlibDecoder;

use crate::{
    error::{Result, WhitelistPreconfirmationDriverError},
    importer::{MAX_COMPRESSED_TX_LIST_BYTES, MAX_DECOMPRESSED_TX_LIST_BYTES},
};

/// Decompress a zlib-compressed tx-list with strict compressed/decompressed caps.
pub(crate) fn decompress_tx_list(bytes: &[u8]) -> Result<Vec<u8>> {
    if bytes.len() > MAX_COMPRESSED_TX_LIST_BYTES {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "compressed tx list exceeds maximum size: {} > {}",
            bytes.len(),
            MAX_COMPRESSED_TX_LIST_BYTES
        )));
    }

    let decoder = ZlibDecoder::new(bytes);
    let mut out = Vec::new();
    let read_cap = MAX_DECOMPRESSED_TX_LIST_BYTES.saturating_add(1) as u64;
    decoder.take(read_cap).read_to_end(&mut out).map_err(|err| {
        WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "failed to decompress tx list from payload: {err}"
        ))
    })?;

    if out.len() > MAX_DECOMPRESSED_TX_LIST_BYTES {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "decompressed tx list exceeds maximum size: {} > {}",
            out.len(),
            MAX_DECOMPRESSED_TX_LIST_BYTES
        )));
    }

    if out.is_empty() {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(
            "decompressed tx list is empty".to_string(),
        ));
    }

    Ok(out)
}
