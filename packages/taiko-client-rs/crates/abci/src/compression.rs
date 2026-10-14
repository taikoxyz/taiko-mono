//! zlib helpers shared by landing payload V3 (`0x03 || zlib(rlp(...))`) and the landing capacity
//! guard, and the capacity of one landing.
//!
//! The lander depends on this crate, so both sides compress with the same codec: `flate2` over
//! the locked, statically linked stock C zlib at [`Compression::default`]. A single landing
//! may retry [`Compression::best`] if the default output exceeds its payload bound.

use std::io::Write;

use flate2::{Compression, Decompress, FlushDecompress, Status, write::ZlibEncoder};

/// The blobs one block may need to land on its own: the minimum `max_blobs` the lander accepts.
pub const MAX_LANDING_BLOBS: usize = 6;

/// The payload bytes one blob carries under the lander's blob coding (127 usable bytes per four
/// field elements, less a four-byte header); equals the lander's `blob::PAYLOAD_BYTES_PER_BLOB`
/// (`BYTES_PER_BLOB * 127 / 128 - 4`).
pub const LANDING_PAYLOAD_BYTES_PER_BLOB: usize = 130_044;

/// The room reserved for a published block's header next to its compressed envelope.
pub const HEADER_ALLOWANCE: usize = 1_024;

/// The compressed bytes one block may need to land on its own: the payload of
/// [`MAX_LANDING_BLOBS`] blobs, less 4 KiB for the payload framing.
pub const MAX_BLOCK_LANDING_BYTES: usize =
    MAX_LANDING_BLOBS * LANDING_PAYLOAD_BYTES_PER_BLOB - 4_096;

/// The output chunk [`zlib_inflate_exact`] inflates into per step.
const INFLATE_CHUNK: usize = 8 * 1024;

/// Why [`zlib_inflate_exact`] refuses its input.
#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum InflateError {
    /// The input is not one complete, well-formed zlib stream (bad header, corrupt data, wrong
    /// checksum, a preset dictionary, or truncated).
    #[error("malformed or truncated zlib stream")]
    Malformed,
    /// Bytes follow the end of the zlib stream.
    #[error("trailing bytes after the zlib stream")]
    TrailingBytes,
    /// The stream inflates to more than the allowed output.
    #[error("zlib stream inflates to more than {max} bytes")]
    TooLarge {
        /// The allowed output, in bytes.
        max: usize,
    },
}

/// `data` as one zlib stream at the default compression level.
pub fn zlib_compress(data: &[u8]) -> Vec<u8> {
    zlib_compress_with(data, Compression::default())
}

/// `data` as one zlib stream at the best compression level, for a bounded single-block retry.
pub fn zlib_compress_best(data: &[u8]) -> Vec<u8> {
    zlib_compress_with(data, Compression::best())
}

/// Compress into an infallible in-memory writer at `level`.
fn zlib_compress_with(data: &[u8], level: Compression) -> Vec<u8> {
    let mut encoder = ZlibEncoder::new(Vec::new(), level);
    encoder.write_all(data).expect("compressing into a Vec cannot fail");
    encoder.finish().expect("compressing into a Vec cannot fail")
}

/// Inflates `data`, which must be exactly one complete zlib stream (no trailing input) whose
/// output is at most `max_output` bytes.
///
/// The output never grows past `max_output`: inflation stops at the first chunk that would pass
/// it, so a small stream that inflates hugely costs at most the cap plus one chunk of work.
pub fn zlib_inflate_exact(data: &[u8], max_output: usize) -> Result<Vec<u8>, InflateError> {
    let mut decoder = Decompress::new(true);
    let mut out = Vec::new();
    let mut chunk = [0u8; INFLATE_CHUNK];
    loop {
        let (in_before, out_before) = (decoder.total_in(), decoder.total_out());
        // `total_in` counts bytes of `data` only, so it never exceeds `data.len()`.
        let status = decoder
            .decompress(&data[in_before as usize..], &mut chunk, FlushDecompress::None)
            .map_err(|_| InflateError::Malformed)?;
        let produced = (decoder.total_out() - out_before) as usize;
        if produced > max_output - out.len() {
            return Err(InflateError::TooLarge { max: max_output });
        }
        out.extend_from_slice(&chunk[..produced]);
        if status == Status::StreamEnd {
            return if decoder.total_in() as usize == data.len() {
                Ok(out)
            } else {
                Err(InflateError::TrailingBytes)
            };
        }
        if decoder.total_in() == in_before && produced == 0 {
            // The input ran out before the stream ended.
            return Err(InflateError::Malformed);
        }
    }
}

#[cfg(test)]
mod tests {
    use alloy_eips::eip4844::BYTES_PER_BLOB;

    use super::*;

    #[test]
    fn compression_uses_the_pinned_bundled_zlib_version() {
        // zlibVersion returns a process-lifetime NUL-terminated version string.
        let version = unsafe { std::ffi::CStr::from_ptr(libz_sys::zlibVersion()) };
        assert_eq!(version.to_str().unwrap(), "1.3.2");
    }

    #[test]
    fn landing_capacity_constants_match_the_blob_coding() {
        assert_eq!(LANDING_PAYLOAD_BYTES_PER_BLOB, BYTES_PER_BLOB * 127 / 128 - 4);
        assert_eq!(MAX_BLOCK_LANDING_BYTES, 776_168);
    }

    #[test]
    fn compression_round_trips() {
        let mut mixed = vec![0u8; 100_000];
        mixed.extend((0..50_000u32).map(|i| (i.wrapping_mul(2_654_435_761) >> 13) as u8));
        for data in [vec![], vec![0x5a], b"etna landing payload".repeat(1_000), mixed] {
            let compressed = zlib_compress(&data);
            assert_eq!(zlib_inflate_exact(&compressed, data.len()), Ok(data));
        }
        assert!(zlib_compress(&[0; 1 << 20]).len() < 2_048, "zeros compress well");
    }

    #[test]
    fn inflate_rejects_trailing_bytes() {
        let compressed = zlib_compress(b"one stream");
        let mut trailing = compressed.clone();
        trailing.push(0);
        assert_eq!(zlib_inflate_exact(&trailing, 1 << 10), Err(InflateError::TrailingBytes));

        let mut two = compressed.clone();
        two.extend_from_slice(&compressed);
        assert_eq!(zlib_inflate_exact(&two, 1 << 10), Err(InflateError::TrailingBytes));
    }

    #[test]
    fn inflate_rejects_output_above_cap() {
        // Spans several inflate chunks.
        let data = vec![7u8; 100_000];
        let compressed = zlib_compress(&data);
        assert_eq!(zlib_inflate_exact(&compressed, data.len()), Ok(data.clone()), "exactly at cap");
        assert_eq!(
            zlib_inflate_exact(&compressed, data.len() - 1),
            Err(InflateError::TooLarge { max: data.len() - 1 })
        );
        assert_eq!(
            zlib_inflate_exact(&zlib_compress(&[1]), 0),
            Err(InflateError::TooLarge { max: 0 })
        );
        assert_eq!(zlib_inflate_exact(&zlib_compress(&[]), 0), Ok(vec![]));
    }

    #[test]
    fn inflate_rejects_malformed_and_truncated_streams() {
        let compressed = zlib_compress(&b"etna".repeat(100));
        for (case, input) in [
            ("empty", &[][..]),
            ("garbage", &[0x01, 0xff, 0x00][..]),
            ("raw deflate without the zlib header", &compressed[2..]),
            ("truncated", &compressed[..compressed.len() - 1]),
            ("header only", &compressed[..2]),
        ] {
            assert_eq!(zlib_inflate_exact(input, 1 << 10), Err(InflateError::Malformed), "{case}");
        }
        let mut corrupt = compressed.clone();
        *corrupt.last_mut().unwrap() ^= 1; // the Adler-32 checksum
        assert_eq!(zlib_inflate_exact(&corrupt, 1 << 10), Err(InflateError::Malformed));
    }
}
