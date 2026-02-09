//! Shasta protocol implementation.

#[cfg(feature = "net")]
pub mod anchor;
pub mod blob_coder;
pub mod constants;
pub mod error;
pub mod manifest;
pub mod payload_helpers;

#[cfg(feature = "net")]
pub use anchor::{AnchorTxConstructor, AnchorTxConstructorError, AnchorV4Input};
pub use blob_coder::BlobCoder;
pub use error::{ForkConfigResult, ProtocolError, Result, ShastaForkConfigError};
pub use payload_helpers::{
    PAYLOAD_ID_VERSION_V2, calculate_shasta_difficulty, encode_extra_data, encode_transactions,
    encode_tx_list, payload_id_to_bytes,
};
