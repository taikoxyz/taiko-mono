//! Canonical original protobuf decoding and exact projection agreement.
use super::native::{Block, Commit, RawBlock, RawCommit};
use alloc::string::{String, ToString};
use prost::Message;

/// Native wire or projection failure, without host retry/runtime policy.
#[derive(Debug, thiserror::Error)]
pub enum CodecError {
    /// Original block bytes cannot be parsed as protobuf.
    #[error("invalid original CometBFT block protobuf: {0}")]
    MalformedBlock(String),
    /// Unknown, duplicate, reordered or otherwise noncanonical protobuf fields.
    #[error("noncanonical original block protobuf")]
    NoncanonicalBlock,
    /// Parsed block cannot form the supported structural projection.
    #[error("invalid original CometBFT block: {0}")]
    InvalidBlock(String),
    /// Independently mutable projection disagrees with the original bytes.
    #[error("original block differs from domain projection")]
    ProjectionMismatch,
    /// Original certificate bytes cannot be parsed as protobuf.
    #[error("invalid restored CometBFT commit protobuf: {0}")]
    MalformedCommit(String),
    /// Certificate protobuf bytes differ from their canonical encoding.
    #[error("noncanonical restored commit protobuf")]
    NoncanonicalCommit,
    /// Certificate has malformed native metadata or signature slots.
    #[error("invalid restored CometBFT commit: {0}")]
    InvalidCommit(String),
}

/// Decodes exact original block bytes and their evidence-free structural projection.
/// Allocation is proportional to caller-supplied bytes; callers must bound witness size.
pub fn decode_canonical_block(bytes: &[u8]) -> Result<(RawBlock, Block), CodecError> {
    let raw = RawBlock::decode(bytes).map_err(|e| CodecError::MalformedBlock(e.to_string()))?;
    if raw.encode_to_vec() != bytes {
        return Err(CodecError::NoncanonicalBlock);
    }
    let block = Block::try_from(raw.clone()).map_err(CodecError::InvalidBlock)?;
    Ok((raw, block))
}

/// Decodes a canonical native certificate, preserving all 65-byte signatures.
/// Decode/re-encode rejects unknown fields instead of silently authenticating a projection.
pub fn decode_canonical_commit(bytes: &[u8]) -> Result<Commit, CodecError> {
    let raw = RawCommit::decode(bytes).map_err(|e| CodecError::MalformedCommit(e.to_string()))?;
    if raw.encode_to_vec() != bytes {
        return Err(CodecError::NoncanonicalCommit);
    }
    raw.try_into().map_err(CodecError::InvalidCommit)
}

/// Requires exact canonical raw bytes and exact agreement with the supplied projection.
pub fn checked_block_proto(bytes: &[u8], projection: &Block) -> Result<RawBlock, CodecError> {
    let (raw, block) = decode_canonical_block(bytes)?;
    if block != *projection {
        return Err(CodecError::ProjectionMismatch);
    }
    Ok(raw)
}
