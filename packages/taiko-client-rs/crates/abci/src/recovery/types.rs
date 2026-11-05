//! Versioned recovery evidence and its authenticated fixed origin.

use crate::{
    AccountWitness, CommitteeState, CommitteeWitness, EngineError, GenesisWitness, L1Error,
    RawL1Header,
};
use alloy_consensus::Header;
use alloy_primitives::B256;
use alloy_rlp::{RlpDecodable, RlpEncodable};
use serde::{Deserialize, Serialize};

/// Complete version-one evidence; headers require independent own-L1 canonicality/finality.
#[derive(Clone, Debug, PartialEq, Eq, RlpEncodable, RlpDecodable)]
pub struct RecoveryWitness {
    /// Encoding version; only one is supported.
    pub version: u64,
    /// Explicit requested nonzero deployment generation, bounded to 48 bits.
    pub generation: u64,
    /// Original generation-zero deployment and committee evidence, never rewritten.
    pub genesis: GenesisWitness,
    /// Own-L1 finalized observation header.
    pub finalized_header: RawL1Header,
    /// Exact recovery-slot proof at the finalized observation.
    pub finalized_inbox: AccountWitness,
    /// Canonical finalized execution block R of recovery.
    pub recovery_header: RawL1Header,
    /// Exact recovery-slot proof at the end of R.
    pub recovery_inbox: AccountWitness,
    /// Complete registry snapshot at the end of R for epoch floor(c/L).
    pub committee: CommitteeWitness,
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
    /// Global L2 height c, on the unchanged checkpoint grid.
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
    /// Retained landing validator-state hash (word 4), zero only at c = 0. It is the original
    /// generation's state, not this one's, so it is never compared with the node's (SYNC-9-5).
    pub val_state_hash: B256,
    /// FI queue cursor from the retained landing at c.
    pub forced_cursor: u64,
    /// Initial committee derived independently from the complete R registry snapshot.
    pub committee: CommitteeState,
}

/// Recovery failures retain the distinction between unavailable evidence and contradictions.
#[derive(Debug, thiserror::Error)]
pub enum RecoveryError {
    /// Missing history, nonfinal inputs or failed acquisition; grants no authority.
    #[error("recovery input unavailable: {0}")]
    Unavailable(String),
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
