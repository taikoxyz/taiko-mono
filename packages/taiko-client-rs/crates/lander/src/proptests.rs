//! Property tests of the landing payload codec.
//!
//! [`codec::decode`](crate::codec::decode) reads payloads anyone can post in blobs: it never
//! panics, whatever the bytes, and accepts only the canonical encoding of the blocks it returns. A
//! payload decodes to exactly the published blocks it was encoded from. Each property runs a fixed
//! number of cases, sized so that it takes at most a few seconds in a debug build.

/// The V4 payload codec.
mod payload_codec;
/// Generators shared by these properties and by the complete-prefix selection property in
/// `batch`.
pub(crate) mod strategies;
