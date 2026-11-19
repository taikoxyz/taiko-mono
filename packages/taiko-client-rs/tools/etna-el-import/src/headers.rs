//! Validate the actual header context required by DATA-5.3/5.4 before touching stores.

use alloy_consensus::Header;
use alloy_primitives::B256;
use serde::{Deserialize, Serialize};

use crate::ImportError;

/// Maximum unsettled range plus the inherited finalized checkpoint just below it.
const MAX_HEADERS: u64 = 65_537;
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
/// coverage floor (DATA-5.3/5.4) and must compare the receipt with the selected landed hashes
/// and own trust target before publishing stores.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
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

/// A strictly validated borrowed header plan; it cannot be restored from serialized metadata.
pub struct VerifiedHeaders<'a> {
    /// Immutable complete manifest which was checked against the trusted terminal tuple.
    manifest: &'a HeaderManifest,
    /// Authenticated original EL genesis identity to retain separately when outside the range.
    genesis_hash: B256,
}

impl HeaderManifest {
    /// Check original links back from the trusted terminal and the finalized identity.
    ///
    /// Coverage is the Rust caller's `header_floor`; any longer linked range is accepted.
    pub fn verify(&self, trust: &ElTrust) -> Result<VerifiedHeaders<'_>, ImportError> {
        if self.schema != 1 ||
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
