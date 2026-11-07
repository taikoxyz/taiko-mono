//! Validate the actual header context required by DATA-5.3/5.4 before touching stores.

use alloy_consensus::Header;
use alloy_primitives::{B256, keccak256};
use serde::{Deserialize, Serialize};

use crate::ImportError;

/// Largest authenticated unsettled range supported by the pinned deployment rules.
const MAX_HEADERS: u64 = 65_536;
/// Ethereum's next-block BLOCKHASH context, including its terminal header.
const BLOCKHASH_ANCESTORS: u64 = 255;
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
/// The helper does not authenticate L1 or authorize signing. Its caller must compare its
/// receipt with the selected landed hashes and own trust target before publishing stores.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct HeaderManifest {
    /// Local helper input schema; unsupported schemas are refused.
    pub schema: u32,
    /// Local installation identity issued by the offline lifecycle, not signing authority.
    pub installation_id: B256,
    /// L2 chain identifier, also checked against the runtime chainspec.
    pub chain_id: u64,
    /// Current generation's fixed EL origin o.
    pub origin: u64,
    /// Authenticated unsettled-depth parameter U, in blocks.
    pub unsettled_limit: u64,
    /// Checkpoint proven by the inherited committed anchor; the next block may advance it.
    pub finalized_height: u64,
    /// Exact authenticated hash at finalized_height; never replaced with s or zero.
    pub finalized_hash: B256,
    /// Complete required context in ascending number order, ending at s.
    pub headers: Vec<Header>,
}

/// A strictly validated borrowed header plan; it cannot be restored from serialized metadata.
pub struct VerifiedHeaders<'a> {
    /// Immutable complete manifest which was checked against the trusted terminal tuple.
    manifest: &'a HeaderManifest,
    /// Authenticated original EL genesis identity to retain separately when outside the range.
    genesis_hash: B256,
    /// Index of the actual finalized checkpoint within the authenticated contiguous range.
    finalized_index: usize,
}

impl HeaderManifest {
    /// Check exact coverage, original links and the terminal/finalized identities.
    pub fn verify(&self, trust: &ElTrust) -> Result<VerifiedHeaders<'_>, ImportError> {
        if self.schema != 1 ||
            self.installation_id.is_zero() ||
            self.chain_id != trust.chain_id ||
            self.unsettled_limit == 0 ||
            self.unsettled_limit > MAX_HEADERS ||
            self.headers.is_empty() ||
            self.headers.len() as u64 > MAX_HEADERS
        {
            return Err(ImportError::Invalid("unsupported header manifest or limits"));
        }
        let terminal = self.headers.last().expect("nonempty range checked");
        if terminal.number >= HEIGHT_LIMIT ||
            self.origin > terminal.number ||
            terminal.hash_slow() != trust.terminal_hash ||
            terminal.state_root != trust.state_root
        {
            return Err(ImportError::Invalid("terminal header differs from authenticated context"));
        }
        let checkpoint_floor =
            self.origin.max(terminal.number.saturating_sub(self.unsettled_limit - 1));
        // At s the inherited checkpoint may still be s-U. Keep it for reconciliation;
        // normal block validity requires an advanced checkpoint before producing s+1.
        let inherited_floor = self.origin.max(terminal.number.saturating_sub(self.unsettled_limit));
        if self.finalized_height < inherited_floor || self.finalized_height > terminal.number {
            return Err(ImportError::Invalid(
                "finalized checkpoint lies outside the imported fence range",
            ));
        }
        let first = checkpoint_floor
            .min(terminal.number.saturating_sub(BLOCKHASH_ANCESTORS))
            .min(self.finalized_height);
        if self.headers[0].number != first ||
            self.headers.len() as u64 != terminal.number - first + 1
        {
            return Err(ImportError::Invalid("incomplete or excessive canonical header range"));
        }
        for pair in self.headers.windows(2) {
            if pair[0].number.checked_add(1) != Some(pair[1].number) ||
                pair[1].parent_hash != pair[0].hash_slow()
            {
                return Err(ImportError::Invalid("canonical header hash/number links differ"));
            }
        }
        let finalized_index = (self.finalized_height - first) as usize;
        if self.headers[finalized_index].hash_slow() != self.finalized_hash {
            return Err(ImportError::Invalid("finalized checkpoint hash differs from its header"));
        }
        if first == 0 && self.headers[0].hash_slow() != trust.genesis_hash {
            return Err(ImportError::Invalid("imported original genesis hash differs"));
        }
        Ok(VerifiedHeaders { manifest: self, genesis_hash: trust.genesis_hash, finalized_index })
    }
}

impl VerifiedHeaders<'_> {
    /// Local offline installation identity bound into the private staging claim.
    pub fn installation_id(&self) -> B256 {
        self.manifest.installation_id
    }

    /// Authenticated contiguous EL header range to install in the EL's canonical indexes.
    pub fn headers(&self) -> &[Header] {
        &self.manifest.headers
    }

    /// Actual selected terminal header s.
    pub fn terminal(&self) -> &Header {
        self.manifest.headers.last().expect("verified range is nonempty")
    }

    /// Actual inherited finalized checkpoint q, which may be below s.
    pub fn finalized(&self) -> &Header {
        &self.manifest.headers[self.finalized_index]
    }

    /// Original EL genesis identity, independent of the generation's fixed origin o.
    pub fn genesis_hash(&self) -> B256 {
        self.genesis_hash
    }

    /// Deterministic local manifest binding for durable installation receipts.
    pub fn manifest_hash(&self) -> Result<B256, ImportError> {
        Ok(keccak256(serde_json::to_vec(self.manifest)?))
    }
}
