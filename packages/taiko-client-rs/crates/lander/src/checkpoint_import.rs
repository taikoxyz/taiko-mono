//! Bounded landed-checkpoint authentication without historical execution.
//!
//! The iterator supplies ascending native block frames exactly once. No consensus source or
//! execution engine is accepted, so verification cannot fetch a prefix or execute old blocks.

use abci::{
    ChainParams, CommitteeState, GenesisDoc, L1Source, ParentInfo, Schedule, store::AppState,
    valstate::ValState,
};
use alloy_consensus::Header;
use alloy_primitives::{B256, Bytes, U256, keccak256};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// Own-L1 authentication, bounded reconstruction and native block verification.
mod authenticate;
/// Evidence expiry and complete suffix proof.
mod window;

pub use authenticate::{authenticate_import, select_export};
pub use window::evidence_expired;

/// Oldest canonical EL header an import at `height` installs: the lower of the 5.3 BLOCKHASH
/// context from s-255 and DATA-5.4-4's U ancestry fence from max(o, s-U+1). It keeps s-U: the
/// inherited post-s anchor can still name that boundary, even though the next block must
/// advance its own checkpoint to at least s-U+1. Subtraction saturates at zero.
pub fn header_floor(origin: u64, height: u64, unsettled_limit: u64) -> u64 {
    height.saturating_sub(255).min(origin.max(height.saturating_sub(unsettled_limit)))
}

/// Import failures keep publisher faults distinct from authenticated contradictions.
#[derive(Clone, Debug, thiserror::Error, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "class", content = "detail", rename_all = "snake_case")]
pub enum ImportError {
    /// Invalid publisher bytes; reject this candidate without granting authority.
    #[error("invalid checkpoint candidate: {0}")]
    Candidate(String),
    /// Missing data or finality; retry without advancing installation.
    #[error("checkpoint material unavailable: {0}")]
    Unavailable(String),
    /// Contradictory authenticated facts; durably halt and alert, never publisher retry.
    #[error("authenticated checkpoint contradiction: {0}")]
    Safety(String),
}

/// Version-one metadata; block payloads are supplied separately as a streaming iterator.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ImportPackage {
    /// Supported format version, exactly one.
    pub schema: u32,
    /// Immutable original stock genesis, including original InitialHeight and witness.
    pub genesis: GenesisDoc,
    /// Selected retained landing; may be older than the current admission target.
    pub checkpoint_height: u64,
    /// Fixed origin EL header, independently bound by genesis or the recovery witness.
    pub origin_header: Header,
    /// Historical origin context needed across recovery restart; absent for generation zero.
    pub recovery_bootstrap: Option<abci::recovery::RecoveryBootstrap>,
    /// Predecessor header at w, authenticated by the first block's LastBlockID; absent at o.
    pub boundary_header: Option<tendermint::block::Header>,
    /// Exact appendix-A preimage; empty only for fixed-origin initialization.
    pub validator_state: Bytes,
    /// Ascending linked EL prefix from min(w, [`header_floor`]) through w. Empty is allowed
    /// when that range is only the separately supplied origin header. The s-U header permits
    /// proving the inherited anchor before terminal metadata is seen. No execution state or
    /// trusted cache is accepted here.
    pub execution_headers: Vec<Header>,
}

/// One untrusted keys-and-powers entry; historical proposer priorities are intentionally absent.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ImportValidator {
    /// Canonical native compressed SEC1 public key.
    pub key: abci::key::ConsensusKey,
    /// Positive stock power, bounded together with the complete set.
    pub power: u64,
}

/// One original canonical native block and its own-height certificate.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct WindowBlock {
    /// Original unmodified stock protobuf, including evidence and LastCommit.
    pub block: Bytes,
    /// Original canonical own-height commit protobuf; nonterminal copies equal LastCommit.
    pub commit: Bytes,
    /// Complete keys/powers whose hash must equal this height's validators_hash.
    pub validators: Vec<ImportValidator>,
}

/// A slot-285 landing proven under the current own-finalized root.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct Landing {
    /// Global landed EL/Comet height.
    pub height: u64,
    /// Previous landed checkpoint in the selected settled history.
    pub parent_height: u64,
    /// Generation that landed this checkpoint.
    pub generation: u64,
    /// FI cursor after this checkpoint, distinct from the latest queue head.
    pub forced_cursor: u64,
    /// Landed execution block hash.
    pub el_hash: B256,
    /// Landed consensus header hash.
    pub comet_hash: B256,
    /// Landed canonical post-height validator-state commitment.
    pub val_state_hash: B256,
}

/// Authenticated reconstruction. Serialization is a report, never a deserializable trust token.
#[derive(Debug, Serialize)]
pub struct VerifiedImport {
    /// Exact post-checkpoint application metadata.
    state: AppState,
    /// Original generation genesis, never normalized to s+1.
    genesis: GenesisDoc,
    /// Selected retained landing.
    landing: Landing,
    /// Latest own-finalized checkpoint, still required for session admission.
    admission_target: crate::LandingSnapshot,
    /// Full terminal native ID, absent on the fixed-genesis path.
    block_id: Option<tendermint::block::Id>,
    /// Exact native terminal time used by stock post-s evidence semantics.
    terminal_time: Option<tendermint::Time>,
    /// First retained consensus height, absent at the fixed origin.
    first_height: Option<u64>,
    /// Parent-linked canonical EL installation range from [`header_floor`], in ascending order.
    execution_headers: Vec<Header>,
    /// Recovery evidence that must be persisted before AppState.
    recovery_bootstrap: Option<abci::recovery::RecoveryBootstrap>,
    /// Digest of exact length-framed input blocks/commits/keys/powers, for local staging identity.
    window_hash: B256,
}
impl VerifiedImport {
    /// Verified state to stage; completion alone never grants trust or signing authority.
    pub fn state(&self) -> &AppState {
        &self.state
    }
    /// Original fixed genesis to install unchanged.
    pub fn genesis(&self) -> &GenesisDoc {
        &self.genesis
    }
    /// Trusted arguments for the stock helper, authenticated independently of its report.
    pub fn landing(&self) -> &Landing {
        &self.landing
    }
    /// Latest finalized target; startup must reacquire it and recheck generation.
    pub fn admission_target(&self) -> &crate::LandingSnapshot {
        &self.admission_target
    }
    /// Full terminal ID for matching the stock-helper report; None means fixed-genesis startup.
    pub fn block_id(&self) -> Option<tendermint::block::Id> {
        self.block_id
    }
    /// Exact terminal native timestamp for matching the stock helper report.
    pub fn terminal_time(&self) -> Option<tendermint::Time> {
        self.terminal_time
    }
    /// First consensus height the stock package must contain.
    pub fn first_height(&self) -> Option<u64> {
        self.first_height
    }
    /// Canonical headers the EL helper must install into its own database indexes.
    pub fn execution_headers(&self) -> &[Header] {
        &self.execution_headers
    }
    /// Required recovery sidecar, absent for generation zero.
    pub fn recovery_bootstrap(&self) -> Option<&abci::recovery::RecoveryBootstrap> {
        self.recovery_bootstrap.as_ref()
    }
    /// Identity of the exact streamed native frames; not Go's differently encoded package hash.
    pub fn window_hash(&self) -> B256 {
        self.window_hash
    }
}

/// Reject a selected height that cannot belong to this generation's retained settled history.
fn validate_selected_landing(
    record: &Landing,
    generation: u64,
    origin: u64,
    latest: u64,
) -> Result<(), ImportError> {
    // An absent future record cannot yet be distinguished from a landing awaiting finality.
    // A populated historical record above the rolled-back frontier is already disqualified.
    if record.height > latest &&
        record.height <= abci::schedule::UINT48_MAX &&
        record.height.is_multiple_of(abci::GRID_INTERVAL) &&
        record.parent_height == 0 &&
        record.generation == 0 &&
        record.forced_cursor == 0 &&
        record.el_hash.is_zero() &&
        record.comet_hash.is_zero() &&
        record.val_state_hash.is_zero()
    {
        return Err(unavailable("selected landing has not reached the own finalized frontier"));
    }
    if record.height < origin ||
        record.height > latest ||
        !record.height.is_multiple_of(abci::GRID_INTERVAL) ||
        record.el_hash.is_zero() ||
        (record.height > origin &&
            (record.generation != generation ||
                record.parent_height >= record.height ||
                !record.parent_height.is_multiple_of(abci::GRID_INTERVAL) ||
                record.parent_height < origin ||
                record.comet_hash.is_zero() ||
                record.val_state_hash.is_zero()))
    {
        return Err(ImportError::Candidate(
            "selected height has no retained current-generation landing".into(),
        ));
    }
    Ok(())
}

/// Only a matching landed commitment promotes malformed or inconsistent state to safety evidence.
fn authenticate_preimage(
    bytes: &[u8],
    expected: B256,
    height: u64,
) -> Result<ValState, ImportError> {
    if keccak256(bytes) != expected {
        return Err(candidate("validator-state preimage hash mismatch"));
    }
    let state = ValState::decode(bytes).map_err(safety)?;
    for set in [&state.current, &state.next] {
        ValState::genesis(
            height,
            &set.entries.iter().map(|e| (e.key, e.power as u64)).collect::<Vec<_>>(),
        )
        .map_err(safety)?;
    }
    if state.height != height {
        return Err(safety("landed validator-state height mismatch"));
    }
    Ok(state)
}

/// Publisher input error without authenticated contradictory facts.
fn candidate(error: impl std::fmt::Display) -> ImportError {
    ImportError::Candidate(error.to_string())
}
/// Missing input or source cannot authorize a partial import.
fn unavailable(error: impl std::fmt::Display) -> ImportError {
    ImportError::Unavailable(error.to_string())
}
/// Contradictory facts already bound by trusted L1 or landed consensus bytes.
fn safety(error: impl std::fmt::Display) -> ImportError {
    ImportError::Safety(error.to_string())
}
/// Preserve the own-L1 adapter's integrity distinction.
fn own_error(error: abci::L1Error) -> ImportError {
    if error.is_integrity_failure() { safety(error) } else { unavailable(error) }
}
/// Derive the application parent summary from linked authenticated headers.
fn parent_info(header: &Header, preceding_time: u64) -> Result<ParentInfo, ImportError> {
    Ok(ParentInfo {
        number: header.number,
        hash: header.hash_slow(),
        timestamp: header.timestamp,
        gas_limit: header.gas_limit,
        gas_used: header.gas_used,
        base_fee: header.base_fee_per_gas.ok_or_else(|| candidate("missing execution base fee"))?,
        difficulty: header.difficulty,
        grandparent_timestamp: preceding_time,
    })
}

#[cfg(test)]
mod tests;
