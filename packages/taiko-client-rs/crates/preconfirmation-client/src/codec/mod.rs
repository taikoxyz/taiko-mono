//! Codec utilities for txlist compression and decoding.

/// Txlist codec definitions.
pub mod txlist_codec;

/// Txlist codec trait and zlib implementation.
pub use txlist_codec::{TxListCodec, ZlibTxListCodec};
