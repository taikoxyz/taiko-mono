//! Codec utilities for txlist compression and decoding.

/// Txlist codec definitions.
pub mod txlist_codec;

/// Zlib txlist codec implementation.
pub use txlist_codec::ZlibTxListCodec;
