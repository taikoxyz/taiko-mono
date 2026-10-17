//! Property tests of the landing payload codec and of the promise the ABCI landing capacity guard
//! makes to the lander.
//!
//! [`codec::decode`](crate::codec::decode) reads payloads anyone can post in blobs: it never
//! panics, whatever the bytes, and accepts only the canonical encoding of the blocks it returns. A
//! payload decodes to exactly the published blocks it was encoded from. Every block the guard
//! admits lands on its own, whatever its envelope holds and whatever its CometBFT header's
//! variable fields. Each property runs a fixed number of cases, sized so that it takes at most a
//! few seconds in a debug build.

/// Single-block landing within the landing capacity guard's measure.
mod landing_capacity;
/// The V4 payload codec.
mod payload_codec;
/// Generators shared by these properties and by the complete-prefix selection property in
/// `batch`.
pub(crate) mod strategies;

pub(crate) use landing_capacity::guard_measure;
