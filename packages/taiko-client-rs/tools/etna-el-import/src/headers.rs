//! Validate the actual header context an import installs before touching stores.

use std::io::{BufRead, Read, Write};

use alloy_consensus::Header;
use alloy_primitives::B256;
use serde::{Deserialize, Serialize, de::DeserializeOwned};

use crate::ImportError;

/// U's largest value, 262,144, plus the inherited finalized checkpoint just below the range.
const MAX_HEADERS: u64 = 262_145;
/// One manifest line's capacity; a canonical header's JSON line is under 2 KiB.
const LINE_LIMIT: u64 = 16 * 1024;
/// The only supported manifest schema: JSON Lines, the head and then one header per line.
const SCHEMA: u32 = 2;
/// Exclusive upper bound for a landed protocol height.
const HEIGHT_LIMIT: u64 = 1 << 48;

/// Trusted expectations supplied by the Rust own-finalized-L1 verifier, never by a publisher.
#[derive(Clone, Debug)]
pub struct ElTrust {
    /// Full supported L2 chain identifier.
    pub chain_id: u64,
    /// Original EL genesis hash, distinct from a recovery generation's fixed origin.
    pub genesis_hash: B256,
    /// Selected landed terminal EL hash.
    pub terminal_hash: B256,
    /// State root in the independently authenticated terminal EL header.
    pub state_root: B256,
}

/// Versioned local helper input, generated from the verified app-import context.
///
/// The helper does not authenticate L1 or authorize signing. Its caller chooses the range's
/// coverage floor (the next block's `BLOCKHASH` context and the inherited checkpoint) and must
/// compare the receipt with the selected landed hashes and own trust target before publishing
/// stores. The file is JSON Lines, read one bounded line at a time ([`HeaderManifest::read`]):
/// the first line holds every field but the headers, each later line one header.
#[derive(Clone, Debug)]
pub struct HeaderManifest {
    /// Local helper input schema; unsupported schemas are refused.
    pub schema: u32,
    /// L2 chain identifier, also checked against the runtime chainspec.
    pub chain_id: u64,
    /// Checkpoint proven by the inherited committed anchor; the next block may advance it.
    pub finalized_height: u64,
    /// Exact authenticated hash at finalized_height; never replaced with s or zero.
    pub finalized_hash: B256,
    /// Contiguous context in ascending number order, ending at s; its floor is the caller's.
    pub headers: Vec<Header>,
}

/// The manifest's first line: every [`HeaderManifest`] field but the headers.
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct ManifestHead {
    /// [`HeaderManifest::schema`].
    schema: u32,
    /// [`HeaderManifest::chain_id`].
    chain_id: u64,
    /// [`HeaderManifest::finalized_height`].
    finalized_height: u64,
    /// [`HeaderManifest::finalized_hash`].
    finalized_hash: B256,
}

/// Decode the next line of `reader`, None at its end. A line longer than [`LINE_LIMIT`] or a
/// last line without its newline is refused without decoding it.
fn next_line<T: DeserializeOwned>(
    reader: &mut impl BufRead,
    line: &mut Vec<u8>,
) -> Result<Option<T>, ImportError> {
    line.clear();
    let n = reader.take(LINE_LIMIT + 1).read_until(b'\n', line)?;
    if n == 0 {
        return Ok(None);
    }
    if n as u64 > LINE_LIMIT || line.last() != Some(&b'\n') {
        return Err(ImportError::Invalid("overlong or incomplete header manifest line"));
    }
    serde_json::from_slice(line)
        .map(Some)
        .map_err(|_| ImportError::Invalid("invalid header manifest line"))
}

/// A strictly validated borrowed header plan; it cannot be restored from serialized metadata.
pub struct VerifiedHeaders<'a> {
    /// Immutable complete manifest which was checked against the trusted terminal tuple.
    manifest: &'a HeaderManifest,
    /// Authenticated original EL genesis identity to retain separately when outside the range.
    genesis_hash: B256,
}

impl HeaderManifest {
    /// Stream a manifest from `reader` one bounded line at a time, never the whole file: an
    /// unsupported schema is refused at the head, and a header beyond [`MAX_HEADERS`] before it
    /// is decoded. The result is unverified until [`HeaderManifest::verify`].
    pub fn read(mut reader: impl BufRead) -> Result<Self, ImportError> {
        let mut line = Vec::new();
        let head: ManifestHead = next_line(&mut reader, &mut line)?
            .ok_or(ImportError::Invalid("empty header manifest"))?;
        if head.schema != SCHEMA {
            return Err(ImportError::Invalid("unsupported header manifest schema"));
        }
        let mut headers = Vec::new();
        while !reader.fill_buf()?.is_empty() {
            if headers.len() as u64 == MAX_HEADERS {
                return Err(ImportError::Invalid("header manifest holds more than 262,145 headers"));
            }
            headers.extend(next_line::<Header>(&mut reader, &mut line)?);
        }
        Ok(Self {
            schema: head.schema,
            chain_id: head.chain_id,
            finalized_height: head.finalized_height,
            finalized_hash: head.finalized_hash,
            headers,
        })
    }

    /// Write the manifest in the form [`HeaderManifest::read`] streams.
    pub fn write(&self, writer: impl Write) -> Result<(), ImportError> {
        let mut writer = std::io::BufWriter::new(writer);
        let head = ManifestHead {
            schema: self.schema,
            chain_id: self.chain_id,
            finalized_height: self.finalized_height,
            finalized_hash: self.finalized_hash,
        };
        serde_json::to_writer(&mut writer, &head)?;
        writer.write_all(b"\n")?;
        for header in &self.headers {
            serde_json::to_writer(&mut writer, header)?;
            writer.write_all(b"\n")?;
        }
        writer.flush()?;
        Ok(())
    }

    /// Check original links back from the trusted terminal and the finalized identity.
    ///
    /// Coverage is the Rust caller's `header_floor`; any longer linked range is accepted.
    pub fn verify(&self, trust: &ElTrust) -> Result<VerifiedHeaders<'_>, ImportError> {
        if self.schema != SCHEMA ||
            self.chain_id != trust.chain_id ||
            self.headers.is_empty() ||
            self.headers.len() as u64 > MAX_HEADERS
        {
            return Err(ImportError::Invalid("unsupported header manifest or limits"));
        }
        let terminal = self.headers.last().expect("nonempty range checked");
        if terminal.number >= HEIGHT_LIMIT ||
            terminal.hash_slow() != trust.terminal_hash ||
            terminal.state_root != trust.state_root
        {
            return Err(ImportError::Invalid("terminal header differs from authenticated context"));
        }
        for pair in self.headers.windows(2) {
            if pair[0].number.checked_add(1) != Some(pair[1].number) ||
                pair[1].parent_hash != pair[0].hash_slow()
            {
                return Err(ImportError::Invalid("canonical header hash/number links differ"));
            }
        }
        let first = self.headers[0].number;
        // A package at the unsettled limit can start one height above the inherited
        // checkpoint. The first header commits it. The next block must carry a newer fence.
        let actual_finalized = if self.finalized_height.checked_add(1) == Some(first) {
            self.headers[0].parent_hash
        } else {
            let index = self
                .finalized_height
                .checked_sub(first)
                .filter(|index| *index < self.headers.len() as u64)
                .ok_or(ImportError::Invalid(
                    "finalized checkpoint lies outside the imported header range",
                ))?;
            self.headers[index as usize].hash_slow()
        };
        if actual_finalized != self.finalized_hash ||
            (self.finalized_height == 0 && self.finalized_hash != trust.genesis_hash)
        {
            return Err(ImportError::Invalid("finalized checkpoint hash differs from its header"));
        }
        if first == 0 && self.headers[0].hash_slow() != trust.genesis_hash {
            return Err(ImportError::Invalid("imported original genesis hash differs"));
        }
        Ok(VerifiedHeaders { manifest: self, genesis_hash: trust.genesis_hash })
    }
}

impl VerifiedHeaders<'_> {
    /// Authenticated contiguous EL header range to install in the EL's canonical indexes.
    pub fn headers(&self) -> &[Header] {
        &self.manifest.headers
    }

    /// Actual selected terminal header s.
    pub fn terminal(&self) -> &Header {
        self.manifest.headers.last().expect("verified range is nonempty")
    }

    /// Actual inherited finalized checkpoint q and its authenticated hash.
    pub fn finalized(&self) -> (u64, B256) {
        (self.manifest.finalized_height, self.manifest.finalized_hash)
    }

    /// Original EL genesis identity, independent of the generation's fixed origin o.
    pub fn genesis_hash(&self) -> B256 {
        self.genesis_hash
    }
}
