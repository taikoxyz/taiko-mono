//! Shasta protocol implementation.

#[cfg(feature = "net")]
pub mod anchor;
pub mod blob_coder;
pub mod constants;
pub mod error;
pub mod manifest;
pub mod payload_helpers;

#[cfg(feature = "net")]
pub use anchor::{
    AnchorTransactionValidationError, AnchorTxConstructor, AnchorTxConstructorError, AnchorV4Input,
    validate_anchor_transaction,
};
pub use blob_coder::BlobCoder;
pub use constants::{
    anchor_gas_reserve, etna_active_for_chain_timestamp, etna_fork_timestamp_for_chain, is_etna_at,
    parent_manifest_gas_limit, set_devnet_etna_override, unzen_active_for_chain_timestamp,
    unzen_fork_timestamp_for_chain,
};
pub use error::{ProtocolError, Result};
pub use payload_helpers::{
    PayloadAttributesInput, build_payload_attributes, build_payload_attributes_with_id,
    calculate_shasta_mix_hash, decode_etna_anchor_block_number, encode_etna_extra_data,
    encode_extra_data, encode_transactions,
};
