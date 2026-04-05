//! Shared helpers for preconfirmation tx-list size limits and decoding.

use alloy_primitives::Bytes;
use protocol::{
    codec::{TxListCodecError, ZlibTxListCodec},
    shasta::encode_tx_list,
};

use crate::error::{Result, WhitelistPreconfirmationDriverError};

/// Maximum compressed tx-list size accepted from a preconfirmation payload.
pub(crate) const MAX_COMPRESSED_TX_LIST_BYTES: usize = 131_072 * 6;

/// Maximum decompressed tx-list size accepted from a preconfirmation payload.
///
/// Align with the preconfirmation tx-list cap to avoid zlib bomb expansion on untrusted payloads.
pub(crate) const MAX_DECOMPRESSED_TX_LIST_BYTES: usize = 8 * 1024 * 1024;

/// Decode a compressed preconfirmation tx-list into the raw RLP bytes stored in metadata.
pub(crate) fn decode_preconfirmation_tx_list(compressed_tx_list: &[u8]) -> Result<Bytes> {
    let codec = ZlibTxListCodec::new_with_limits(
        MAX_COMPRESSED_TX_LIST_BYTES,
        MAX_DECOMPRESSED_TX_LIST_BYTES,
    );

    let transactions = codec.decode(compressed_tx_list).map_err(|err| match err {
        TxListCodecError::CompressedTooLarge { actual, max } => {
            WhitelistPreconfirmationDriverError::invalid_payload(format!(
                "compressed tx list exceeds maximum size: {actual} > {max}"
            ))
        }
        TxListCodecError::DecompressedTooLarge { actual, max } => {
            WhitelistPreconfirmationDriverError::invalid_payload(format!(
                "decompressed tx list exceeds maximum size: {actual} > {max}"
            ))
        }
        TxListCodecError::ZlibDecode(reason) => {
            WhitelistPreconfirmationDriverError::invalid_payload_with_context(
                "invalid zlib bytes for transactions",
                reason,
            )
        }
        TxListCodecError::RlpDecode(reason) => {
            WhitelistPreconfirmationDriverError::invalid_payload_with_context(
                "invalid RLP bytes for transactions",
                reason,
            )
        }
        TxListCodecError::ZlibEncode(reason) | TxListCodecError::ZlibFinish(reason) => {
            WhitelistPreconfirmationDriverError::invalid_payload_with_context(
                "invalid transactions list bytes",
                reason,
            )
        }
    })?;

    let raw_transactions = transactions.into_iter().map(Bytes::from).collect::<Vec<_>>();
    Ok(encode_tx_list(&raw_transactions))
}
