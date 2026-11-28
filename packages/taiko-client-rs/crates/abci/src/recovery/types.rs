//! Versioned recovery evidence and its authenticated fixed origin.

use crate::{AccountWitness, EngineError, GenesisWitness, L1Error, RawL1Header};
use alloy_consensus::Header;
use alloy_primitives::B256;
use alloy_rlp::{RlpDecodable, RlpEncodable};
use serde::{Deserialize, Serialize};

/// The one [`RecoveryWitness`] encoding version; any other is refused.
pub const RECOVERY_WITNESS_VERSION: u64 = 2;

/// Complete recovery evidence; headers require independent own-L1 canonicality/finality.
///
/// It proves the origin record's `fallbackKeysHash` and no key list: the keys that sign c + 1
/// and c + 2 are the list with that hash, obtained by it from the own L1.
#[derive(Clone, Debug, PartialEq, Eq, RlpEncodable, RlpDecodable)]
pub struct RecoveryWitness {
    /// Encoding version; only [`RECOVERY_WITNESS_VERSION`] is supported.
    pub version: u64,
    /// Explicit requested nonzero deployment generation, bounded to 48 bits.
    pub generation: u64,
    /// Original generation-zero deployment evidence, never rewritten.
    pub genesis: GenesisWitness,
    /// Own-L1 finalized observation header.
    pub finalized_header: RawL1Header,
    /// Exact recovery-slot proof at the finalized observation.
    pub finalized_inbox: AccountWitness,
    /// Canonical finalized execution block R of recovery.
    pub recovery_header: RawL1Header,
    /// Exact recovery-slot proof at the end of R.
    pub recovery_inbox: AccountWitness,
    /// EL header at the fixed retained checkpoint c, authenticated by its landing hash.
    pub el_header: Header,
    /// Exactly one hash-linked parent when c > 0; empty at c = 0.
    pub parent_headers: Vec<Header>,
}

/// Verified fixed generation boundary, distinct from the latest checkpoint observation.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryOrigin {
    /// Requested deployment generation.
    pub generation: u64,
    /// Global L2 height c, the retained checkpoint, at any height a landing ended.
    pub height: u64,
    /// Recovery execution block R on L1.
    pub l1_number: u64,
    /// R timestamp in Unix seconds.
    pub l1_timestamp: u64,
    /// Retained landing EL hash at c.
    pub el_hash: B256,
    /// State root authenticated by the retained EL header hash.
    pub state_root: B256,
    /// Retained old-generation Comet boundary hash, zero only at c = 0.
    pub comet_hash: B256,
    /// FI queue cursor from the retained landing at c.
    pub forced_cursor: u64,
    /// The `fallbackKeysHash` of the generation's origin record (its fourth word), slot 278 as
    /// `recover` wrote the record: the keys of the list with this hash sign c + 1 and c + 2,
    /// each at power 1, whatever the Inbox's list is later. Never zero.
    pub fallback_keys_hash: B256,
}

/// Recovery failures retain the distinction between unavailable evidence and contradictions.
#[derive(Debug, thiserror::Error)]
pub enum RecoveryError {
    /// Missing history, nonfinal inputs or failed acquisition; grants no authority.
    #[error("recovery input unavailable: {0}")]
    Unavailable(String),
    /// The own EL holds another block at c, or none: it has not taken the settled block of the
    /// retained landing in place of its own (RECOV-8.1-7). Unavailable input, as
    /// [`RecoveryError::Unavailable`], never a contradiction of the authenticated landing.
    #[error(
        "recovery input unavailable: the execution engine does not serve the settled block {el_hash} at recovery origin {height}"
    )]
    OriginNotHeld {
        /// The recovery origin c.
        height: u64,
        /// The retained landing's EL hash at c, authenticated on own finalized L1.
        el_hash: B256,
    },
    /// Contradictory, malformed, unsupported or cryptographically invalid evidence.
    #[error("invalid recovery witness: {0}")]
    Invalid(String),
    /// Local derivation parameters do not open the authenticated deployment configuration.
    #[error("recovery configuration {local} differs from authenticated {proven}")]
    ConfigMismatch {
        /// Local configuration commitment.
        local: B256,
        /// Proof-authenticated configuration commitment.
        proven: B256,
    },
    /// Governance has already advanced beyond the explicitly requested generation.
    #[error("recovery generation {requested} superseded by {current}")]
    Superseded {
        /// Explicit requested generation.
        requested: u64,
        /// Current generation authenticated under own L1.
        current: u64,
    },
}

impl From<L1Error> for RecoveryError {
    /// Classifies malformed/contradictory RPC replies separately from unavailable L1 inputs.
    fn from(error: L1Error) -> Self {
        if error.is_integrity_failure() {
            Self::Invalid(error.to_string())
        } else {
            Self::Unavailable(error.to_string())
        }
    }
}

impl From<EngineError> for RecoveryError {
    /// Retains contradictory EL data as invalid; ordinary acquisition failures are unavailable.
    fn from(error: EngineError) -> Self {
        if error.is_integrity_failure() {
            Self::Invalid(error.to_string())
        } else {
            Self::Unavailable(error.to_string())
        }
    }
}
