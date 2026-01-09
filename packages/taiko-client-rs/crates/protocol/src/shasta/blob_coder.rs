//! Blob sidecar coder compatible with Kona's blob encoding scheme.

use alloy_eips::eip4844::{
    BYTES_PER_BLOB, Blob, VERSIONED_HASH_VERSION_KZG,
    builder::{PartialSidecar, SidecarCoder},
    utils::WholeFe,
};
use std::vec::Vec;

/// The blob encoding version expected by the Kona decoder.
const BLOB_ENCODING_VERSION: u8 = 0;
/// Maximum payload size that fits in a single blob with Kona encoding.
const BLOB_MAX_DATA_SIZE: usize = (4 * 31 + 3) * 1024 - 4;
/// Total encoding rounds per blob.
const BLOB_ENCODING_ROUNDS: usize = 1024;
/// Total data bytes consumed per round (including the 3 bytes packed into headers).
const ROUND_BYTES: usize = 4 * 31 + 3;
/// Total data bytes consumed during the first encoding round.
const FIRST_ROUND_CAPACITY: usize = 27 + 3 + 3 * 31;

#[derive(Clone, Copy, Debug, Default)]
pub struct BlobCoder;

/// Ensure that the field element at the given index exists, returning a mutable reference to it.
fn ensure_field_element(field_elements: &mut Vec<[u8; 32]>, index: usize) -> &mut [u8; 32] {
    if index >= field_elements.len() {
        field_elements.push([0u8; 32]);
    }
    &mut field_elements[index]
}

/// Process a single chunk of data and encode it into field elements, then ingest them into the
/// builder.
fn process_chunk(chunk: &[u8], builder: &mut PartialSidecar, required_fe_count: usize) {
    let mut read_offset = 0usize;
    let mut field_elements = Vec::with_capacity(required_fe_count);
    let mut write_offset = 0usize;

    let write1 = |value: u8, write_offset: &mut usize, field_elements: &mut Vec<[u8; 32]>| {
        if value & 0b1100_0000 != 0 {
            panic!("BlobCoder: invalid 6-bit value");
        }
        assert_eq!(*write_offset % 32, 0);
        let fe_index = *write_offset / 32;
        let fe = ensure_field_element(field_elements, fe_index);
        fe[0] = value;
        *write_offset += 1;
    };

    let write31 = |buf: &[u8; 31], write_offset: &mut usize, field_elements: &mut Vec<[u8; 32]>| {
        assert_eq!(*write_offset % 32, 1);
        let fe_index = *write_offset / 32;
        let fe = ensure_field_element(field_elements, fe_index);
        fe[1..].copy_from_slice(buf);
        *write_offset += 31;
    };

    let read1 = |chunk: &[u8], read_offset: &mut usize| -> u8 {
        if *read_offset >= chunk.len() {
            0
        } else {
            let value = chunk[*read_offset];
            *read_offset += 1;
            value
        }
    };

    let read31 = |buf: &mut [u8; 31], chunk: &[u8], read_offset: &mut usize| {
        if *read_offset >= chunk.len() {
            buf.fill(0);
        } else {
            let remaining = chunk.len() - *read_offset;
            let to_copy = remaining.min(31);
            buf[..to_copy].copy_from_slice(&chunk[*read_offset..*read_offset + to_copy]);
            buf[to_copy..].fill(0);
            *read_offset += to_copy;
        }
    };

    let mut buf31 = [0u8; 31];

    for round in 0..BLOB_ENCODING_ROUNDS {
        if read_offset >= chunk.len() {
            break;
        }

        if round == 0 {
            // Round zero carries version + length metadata in the first field element, so we
            // only have 27 payload bytes available before falling back to the standard flow.
            buf31.fill(0);
            buf31[0] = BLOB_ENCODING_VERSION;
            let length = chunk.len() as u32;
            buf31[1] = ((length >> 16) & 0xff) as u8;
            buf31[2] = ((length >> 8) & 0xff) as u8;
            buf31[3] = (length & 0xff) as u8;
            let available = chunk.len() - read_offset;
            let to_copy = available.min(27);
            buf31[4..4 + to_copy].copy_from_slice(&chunk[read_offset..read_offset + to_copy]);
            buf31[4 + to_copy..].fill(0);
            read_offset += to_copy;
        } else {
            read31(&mut buf31, chunk, &mut read_offset);
        }

        let x = read1(chunk, &mut read_offset);
        let a = x & 0b0011_1111;
        write1(a, &mut write_offset, &mut field_elements);
        write31(&buf31, &mut write_offset, &mut field_elements);

        read31(&mut buf31, chunk, &mut read_offset);
        let y = read1(chunk, &mut read_offset);
        let b = (y & 0b0000_1111) | ((x & 0b1100_0000) >> 2);
        write1(b, &mut write_offset, &mut field_elements);
        write31(&buf31, &mut write_offset, &mut field_elements);

        read31(&mut buf31, chunk, &mut read_offset);
        let z = read1(chunk, &mut read_offset);
        let c = z & 0b0011_1111;
        write1(c, &mut write_offset, &mut field_elements);
        write31(&buf31, &mut write_offset, &mut field_elements);

        read31(&mut buf31, chunk, &mut read_offset);
        let d = ((z & 0b1100_0000) >> 2) | ((y & 0b1111_0000) >> 4);
        write1(d, &mut write_offset, &mut field_elements);
        write31(&buf31, &mut write_offset, &mut field_elements);
    }

    if read_offset < chunk.len() {
        panic!("BlobCoder: payload did not fit into a single blob");
    }

    for fe in field_elements.iter() {
        let whole = WholeFe::new(&fe[..])
            .expect("encoded field element must have the top two bits cleared");
        builder.ingest_valid_fe(whole);
    }
}

impl BlobCoder {
    /// Decode all blobs using the Kona-compatible scheme, returning the raw payload bytes per
    /// blob if the encoding is valid.
    pub fn decode_blobs(blobs: &[Blob]) -> Option<Vec<Vec<u8>>> {
        Self.decode_all(blobs)
    }
}

impl SidecarCoder for BlobCoder {
    /// Calculate the number of field elements required to store the given
    /// data.
    fn required_fe(&self, data: &[u8]) -> usize {
        if data.is_empty() {
            return 0;
        }

        let mut remaining = data.len();
        let mut fes = 0usize;

        // First round encodes 27 bytes via the first field element plus three single-byte reads.
        fes += 4;
        remaining = remaining.saturating_sub(FIRST_ROUND_CAPACITY);

        while remaining > 0 {
            fes += 4;
            remaining = remaining.saturating_sub(ROUND_BYTES);
        }

        fes
    }

    /// Code a slice of data into the builder.
    fn code(&mut self, builder: &mut PartialSidecar, data: &[u8]) {
        if data.is_empty() {
            return;
        }

        for chunk in data.chunks(BLOB_MAX_DATA_SIZE) {
            process_chunk(chunk, builder, self.required_fe(chunk));
        }
    }

    /// Finish the sidecar, and commit to the data. This method should empty
    /// any buffer or scratch space in the coder, and is called by
    /// [`SidecarBuilder`]'s `take` and `build` methods.
    fn finish(self, _builder: &mut PartialSidecar) {}

    /// Decode all slices of data from the blobs.
    fn decode_all(&mut self, blobs: &[Blob]) -> Option<Vec<Vec<u8>>> {
        if blobs.is_empty() {
            return None;
        }

        let mut results = Vec::with_capacity(blobs.len());
        for blob in blobs {
            let decoded = decode_blob(blob)?;
            results.push(decoded);
        }
        Some(results)
    }
}

/// Decode a single field element's bytes from the blob data.
fn decode_field_element_bytes(
    data: &[u8],
    output: &mut [u8],
    output_pos: usize,
    input_pos: usize,
) -> Option<(u8, usize, usize)> {
    if input_pos + 32 > data.len() || output_pos + 31 > output.len() {
        return None;
    }

    let header = data[input_pos];
    if header & 0b1100_0000 != 0 {
        return None;
    }

    output[output_pos..output_pos + 31].copy_from_slice(&data[input_pos + 1..input_pos + 32]);
    Some((header, output_pos + 32, input_pos + 32))
}

/// Reassemble the three bytes from the encoded field elements into the output buffer.
fn reassemble_encoded_bytes(
    mut output_pos: usize,
    encoded_byte: &[u8; 4],
    output: &mut [u8],
) -> usize {
    output_pos -= 1;
    let x = (encoded_byte[0] & 0b0011_1111) | ((encoded_byte[1] & 0b0011_0000) << 2);
    let y = (encoded_byte[1] & 0b0000_1111) | ((encoded_byte[3] & 0b0000_1111) << 4);
    let z = (encoded_byte[2] & 0b0011_1111) | ((encoded_byte[3] & 0b0011_0000) << 2);
    output[output_pos - 32] = z;
    output[output_pos - (32 * 2)] = y;
    output[output_pos - (32 * 3)] = x;
    output_pos
}

/// Decode a single blob that was produced by the Optimism `FromData` routine.
///
/// Returns `None` if the blob is malformed (mismatched version, invalid field element, etc).
fn decode_blob(blob: &Blob) -> Option<Vec<u8>> {
    let data: &[u8] = blob.as_ref();

    if data[VERSIONED_HASH_VERSION_KZG as usize] != BLOB_ENCODING_VERSION {
        return None;
    }

    let length = u32::from_be_bytes([0, data[2], data[3], data[4]]) as usize;
    if length > BLOB_MAX_DATA_SIZE {
        return None;
    }

    let mut output = vec![0u8; BLOB_MAX_DATA_SIZE];
    output[0..27].copy_from_slice(&data[5..32]);

    let mut output_pos = 28usize;
    let mut input_pos = 32usize;
    let mut encoded_byte = [0u8; 4];
    encoded_byte[0] = data[0];

    for b in encoded_byte.iter_mut().skip(1) {
        let (enc, new_output, new_input) =
            decode_field_element_bytes(data, &mut output, output_pos, input_pos)?;
        *b = enc;
        output_pos = new_output;
        input_pos = new_input;
    }

    output_pos = reassemble_encoded_bytes(output_pos, &encoded_byte, &mut output);

    for _ in 1..BLOB_ENCODING_ROUNDS {
        if output_pos >= length {
            break;
        }

        for b in encoded_byte.iter_mut() {
            let (enc, new_output, new_input) =
                decode_field_element_bytes(data, &mut output, output_pos, input_pos)?;
            *b = enc;
            output_pos = new_output;
            input_pos = new_input;
        }

        output_pos = reassemble_encoded_bytes(output_pos, &encoded_byte, &mut output);
    }

    if output.iter().skip(length).any(|byte| *byte != 0u8) {
        return None;
    }

    output.truncate(length);

    if data[input_pos..BYTES_PER_BLOB].iter().any(|byte| *byte != 0) {
        return None;
    }

    Some(output)
}

#[cfg(test)]
mod tests {
    use super::{BLOB_MAX_DATA_SIZE, BlobCoder, decode_blob};
    use alloy::consensus::SidecarBuilder;
    use alloy_eips::eip4844::builder::SidecarCoder;

    #[test]
    fn required_field_elements_matches_capacity() {
        let coder = BlobCoder;
        assert_eq!(coder.required_fe(&[]), 0);
        assert_eq!(coder.required_fe(&[0u8; 1]), 4);
        assert_eq!(coder.required_fe(&[0u8; 27]), 4);
        assert_eq!(coder.required_fe(&[0u8; 28]), 4);
        assert_eq!(coder.required_fe(&[0u8; 124]), 8);
    }

    #[test]
    fn encode_and_decode_round_trip() {
        let payload = (0..256u16).flat_map(|v| v.to_be_bytes()).collect::<Vec<u8>>();

        let builder = SidecarBuilder::<BlobCoder>::from_slice(&payload);
        let blobs = builder.take();
        assert_eq!(blobs.len(), 1);

        let mut coder = BlobCoder;
        let decoded = coder.decode_all(&blobs).unwrap().concat();
        assert_eq!(decoded, payload);
    }

    #[test]
    fn handles_empty_payload() {
        let coder = BlobCoder;
        assert_eq!(coder.required_fe(&[]), 0);

        let mut builder = SidecarBuilder::<BlobCoder>::new();
        builder.ingest(&[]);
        let blobs = builder.take();
        assert_eq!(blobs.len(), 1);
        assert!(blobs[0].iter().all(|byte| *byte == 0));

        let mut decoder = BlobCoder;
        let decoded = decoder.decode_all(&blobs).unwrap().concat();
        assert!(decoded.is_empty());
    }

    #[test]
    fn encodes_maximum_payload() {
        let payload = vec![0xAB; BLOB_MAX_DATA_SIZE];
        let builder = SidecarBuilder::<BlobCoder>::from_slice(&payload);
        let blobs = builder.take();
        assert_eq!(blobs.len(), 1);

        let mut coder = BlobCoder;
        let decoded = coder.decode_all(&blobs).unwrap().concat();
        assert_eq!(decoded.len(), payload.len());
        let direct_decoded = decode_blob(&blobs[0]).unwrap();
        assert_eq!(direct_decoded.len(), payload.len());
    }

    #[test]
    fn creates_sidecar_with_two_blobs() {
        // Create payload that exceeds single blob capacity
        // Use BLOB_MAX_DATA_SIZE + 1 to ensure it requires 2 blobs
        let payload_size = BLOB_MAX_DATA_SIZE + 1000;
        let payload: Vec<u8> = (0..payload_size).map(|i| (i % 256) as u8).collect();

        let builder = SidecarBuilder::<BlobCoder>::from_slice(&payload);
        let blobs = builder.take();

        assert_eq!(blobs.len(), 2, "Expected 2 blobs for payload size {}", payload_size);

        let mut coder = BlobCoder;
        let decoded = coder.decode_all(&blobs).unwrap().concat();

        // Verify the decoded data matches the original payload
        assert_eq!(decoded.len(), payload.len(), "Decoded length should match original");
        assert_eq!(decoded, payload, "Decoded data should match original payload");

        // Verify each blob can be decoded individually
        let blob1_decoded = decode_blob(&blobs[0]).unwrap();
        let blob2_decoded = decode_blob(&blobs[1]).unwrap();

        assert_eq!(blob1_decoded.len(), BLOB_MAX_DATA_SIZE);
        assert_eq!(blob2_decoded.len(), payload_size - BLOB_MAX_DATA_SIZE);

        // Verify the concatenated individual decodings match the original
        let mut individual_decoded = blob1_decoded;
        individual_decoded.extend_from_slice(&blob2_decoded);
        assert_eq!(individual_decoded, payload);
    }
}
